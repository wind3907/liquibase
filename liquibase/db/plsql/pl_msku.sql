CREATE OR REPLACE PACKAGE swms.pl_msku AS

-- sccs_id=@(#) src/schema/plsql/pl_msku.sql, swms, swms.9, 10.2 7/15/09 1.24

---------------------------------------------------------------------------
   -- Package Name:
   -- pl_msku
   --
   -- Description:
   --    Common procedures and functions for handling MSKU tasks.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- --------------------------------------------------
   --    06/30/03          Initial Version
   --    11/13/03  acpppp  D # 11422 Added the check for MSKU putaway to home
   --                      slot.
   --    10/12/03  prpbcb   Oracle 7 rs239a DN none.  Does not exist here.
   --                      Oracle 8 rs239b dvlp8 DN  Does not exist here.
   --                      Oracle 8 rs239b dvlp9 DN  11444
   --                      Added calls to pl_lm_msku.pallet_substitution in
   --                      f_substitute_msku_pallet to update the labor batch
   --                      ref# when a pallet is substituted.
   --    12/15/03  acpppp  D# 11448 Change made in cursor in
   --                      "p_find_anchor_pick_items" function to sort the item
   --                      list by case qty and height/cube in desc order.
   --                      
   --    10/25/04 prpbcb   Oracle 7 rs239a DN None
   --                      Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11797
   --                      Added procedure delete_putaway_batch to delete
   --                      the forklift labor mgmt batch when the putawaylst
   --                      record is deleted.  Added call to
   --                      delete_putaway_batch in f_update_msku_info.
   --
   --    12/09/04 prpbcb   Oracle 7 rs239a DN None
   --                      Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11838
   --                      Ticket: TD 5083
   --                      Modified to use msku pallet type cross reference
   --                      table MSKU_PALLET_TYPE_MIXED to resolve the issue
   --                      of erd_lpn having different pallet types for a
   --                      MSKU pallet.
   --
   --                      Removed the pallet type parameter from procedure
   --                      f_find_reserve_slot_for_msku().  The logic to
   --                      determine the pallet type is now within procedure
   --                      f_find_reserve_slot_for_msku().
   --
   --                      Added out parameter o_msku_reserve_cube to procedure
   --                      p_find_anchor_pick_items() to store the cube of the
   --                      MSKU, including the skid cube, going to reserve.
   --                      It will be used to in finding the available reserve
   --                      slot for the MSKU for putaway. 
   --
   --                      Added function f_get_msku_skid_cube() to determine
   --                      the cube of the skid the MSKU is on.
   --
   --                      Phoebe is working on changes for MSKU sub-divide. 
   --                      I needed the file before she was finished so I
   --                      included her changes in this version.  The changes
   --                      make to this point will not affect processing.
   --                      Her notes are shown below.
   --    11/30/04 prppxx   Add f_update_msku_info_by_item to
   --                      process sub_divide MSKU pallets by item. Also add
   --                      treatment for BCK location in dest_loc. DN 11812
   --                      Add p_find_reserve_slot_for_msku to find empty 
   --              reserve suggested locations in transfer MSKU.
   --
   --    12/28/04 prpbcb   Changed the logic in function
   --                      p_find_reserve_slot_for_msku() to assign a value to
   --                      a variable when a record is found or not found
   --                      and not always use SQL%FOUND because the current
   --                      logic using SQL%FOUND is not always reliable.
   --    01/18/05 prppxx   D11866 Fixed the bug in sub-divided.
   --    02/05/05 prppxx   D11741 Corrected sql stmt for p_is_msku_too_large.
   --
   --    04/25/05 prpbcb   Oracle 8 rs239b swms8 DN 11909
   --                      Added "AND ROWNUM = 1" to the following select
   --                      stmt in procedure p_process_floating_items_msku()
   --                      to work around an issue of the erd_lpn having
   --                      different shipped_ti's for the same item on the MSKU.
   --                      The shipped_ti gets used when putaway is by
   --                      inches so se need to review the affects when
   --                      putaway by inches is active.
   --                         SELECT DISTINCT shipped_ti
   --                           INTO ln_shipped_ti
   --                           FROM erd_lpn
   --                          WHERE sn_no = i_sn_no
   --                            AND prod_id = i_items.prod_id
   --                            AND parent_pallet_id = i_parent_pl_id
   --                            AND ROWNUM = 1;
   --    08/09/05 prpakp   If the rule id for the home slot for an item is
   --                      rule=2 the program will not open the SN. Changed
   --                      the program to consider rule=2 as rule=0 so that
   --                      SN's will be open.
   --
   --    02/05/06 prpbcb   Oracle 8 rs239b swms9 DN 12048
   --                      WAI changes.
   --                      Send WAI items to the induction location.
   --                      Added procedure p_process_miniload_items_msku().
   --                      Modified procedure p_assign_msku_putaway_slots() to
   --                      call p_process_miniload_items_msku().
   --                      Populate inv.inv_uom.
   --   10/27/06 Infosys   Now MSKU LPs from RDC can have qty > 1. While 
   --              calculating quantity information the following 
   --              procedures assume that qty = 1 for MSKU LPs
   --                     p_process_miniload_items_msku
   --                 p_assign_msku_putaway_slots
   --                 p_process_floating_items_msku
   --              These three procedures are modified so that they
   --              will use the quantity information from erd_lpn
   --              table instead of assuming a default value of 1.
   --
   --    10/30/08 prpbcb   DN 12440
   --                      Project:
   --                 CRQ000000003586-SN with miniload item will not open
   --
   --                      A SN will not open that has two or more MSKU's
   --                      with each MSKU having item(s) going to the
   --                      miniloader.
   --
   --                      Added these statements before calling procedure
   --                      p_process_miniload_items_msku():
   --          lt_work_var_rec.n_erm_line_id := r_child_pallets.erm_line_id;
   --          lt_work_var_rec.v_pallet_id   := r_child_pallets.pallet_id;
   --          lt_work_var_rec.v_lot_id      := r_child_pallets.lot_id;
   --          lt_work_var_rec.v_exp_date    := TRUNC(r_child_pallets.exp_date);
   --
   --    05/13/09 prplhj   D#12496 Ignore lot num starts with P for MSKU pallet.
   --
   --    06/30/09 prpbcb   DN 12509
   --                      Project: CRQ10094-Sub-dividing MSKU lost data
   --                      
   --                      Bug fixes in MSKU sub-divide.
   --                      - Sub-divide fails when trying to sub-divide a
   --                        floating item and the parent also has home slot
   --                        items on it.
   --                      - Sub-divide appears to succeed when sub-dividing
   --                        a home slot item and the parent also has floating
   --                        items but what happens is the floating items
   --                        loose the putaway task and the inventory.
   --                      - Sub-divide fails when trying to sub-divide an
   --                        item and the item is also on another MSKU.
   --
   --                      Procedures/functions modified to fix bugs:
   --                         - p_sub_divide_msku_pallet()
   --                         - f_update_msku_info_by_item()
   --                         - f_update_msku_info_by_lp()
   --
   --
   --                      Changed procedure p_sub_divide_msku_pallet() to
   --                      call function pl_common.f_get_new_pallet_id()
   --                      instead of procedure pl_common.p_get_unique_lp()
   --                      to get the new parent pallet id.  p_get_unique_lp()
   --                      only looks at the inventory to see if the LP already
   --                      exists.  f_get_new_pallet_id() looks at inventory
   --                      and the putaway tasks to see if the LP already
   --                      exists.
   --    12-JUN-14 sray0453  Charm#600000054
   --                      Project: Receive cross dock pallets from European Imports
   --
   --    09/24/14 prpbcb   Symbotic changes.
   --
   --                      Send matrix items on a msku to the matrix induction
   --                      location or the staging location based on the MSKU
   --                      induction/staging syspar for the item's area.
   --                      For the item to be directed to the matrix the item
   --                      matrix assigned flag and matrix eligible flag both
   --                      need to be 'Y'.  It is possible
   --                      an item was matrix eligible then became matrix not
   --                      eligible if a case attribute changed at which point
   --                      the item would be directed to the main warehouse.
   --
   --                      For debugging purposes write log message with item
   --                      info after the calls to
   --                      pl_putaway_utilities.p_get_item_info().
   --                      Created procedure "log_item_info" to do this.
   --
   --                      Changed call to pl_putaway_utilities.f_check_home_item.
   --                      It is now passed the item info record and not individual 
   --                      item fields.
   --
   --                      Renamed procedure p_process_miniload_items_msku() to
   --                      send_to_induction_loc().
   --
   --                      Need to handle a floating item with no last ship slot.
   --
   --    07/22/15 prpbcb   Brian Bent
   --                      Symbotic changes.
   --                      Matrix MSKU PUT location was not using the
   --                      MSKU induction/staging syspar for the item's area.
   --                      Changed procedure "send_to_induction_loc()".
   --
   --    09/15/15 prpbcb   Brian Bent
   --                      Project: Symbotic project
   --
   --                      SN sometimes fails to open when a MSKU has matrix
   --                      items.  Change the order by in cursor "c_child_pallets"
   --                      to process the matrix items after miniloader items.
   --                      Apparently we are sensitive in the order the items
   --                      are processed.  The order by changed from
   --  ORDER BY DECODE(NVL(zone.rule_id, 0),
   --                  2, 0,
   --                  3, -1,   -- Process miniloader items first.
   --                  NVL(zone.rule_id, 0)) ASC,
   --           pm.prod_id, erd_lpn.exp_date ASC, erd_lpn.lot_id ASC;
   --                      to
   --           --
   --           -- Process miniloader items first.
   --           DECODE(NVL(zone.rule_id, 0),
   --                  3, -5, 
   --                  NVL(zone.rule_id, 0)) ASC,
   --           --
   --           -- Process matrix items second.  Matrix eligible and matrix assigned
   --           -- both have to be 'Y' in order for the child LP to be sent to
   --           -- the matrix.
   --           DECODE(pm.mx_eligible || pm.mx_item_assign_flag,
   --                  'YY', -4,
   --                  0),
   --           --
   --           -- And process the other items.
   --           DECODE(NVL(zone.rule_id, 0),
   --                  2, 0,
   --                  NVL(zone.rule_id, 0)) ASC,
   --           pm.prod_id, erd_lpn.exp_date ASC, erd_lpn.lot_id ASC;
   --
   --                      Changed procedure log_item_info() to log addtional
   --                      fields to help in researching issues.
   --                     
   --------------------------------------------------------------------------


   -- Global Type Declarations

    TYPE t_item_cpv IS RECORD
    (
    prod_id      erd_lpn.prod_id%TYPE,
    cpv          erd_lpn.cust_pref_vendor%TYPE
    );
     TYPE t_items IS TABLE OF t_item_cpv INDEX BY BINARY_INTEGER;

     TYPE t_parent_pallet_id_arr
     IS TABLE OF erd_lpn.parent_pallet_id%TYPE
     INDEX BY BINARY_INTEGER;

     TYPE t_floating_child_pallets
     IS TABLE OF erd_lpn.erm_line_id%TYPE
     INDEX BY BINARY_INTEGER;

     TYPE t_floating_putaway IS RECORD
     (
     prod_id erd_lpn.prod_id%TYPE,
     cpv     erd_lpn.cust_pref_vendor%TYPE,
     qty     NUMBER,
     child_pallet_ids t_floating_child_pallets
    );
  --DN 11812 prppxx
    TYPE t_phys_loc   IS TABLE OF loc.logi_loc%TYPE INDEX BY BINARY_INTEGER;
  ------------------------------------------------------------------------
  -- Procedure Declarations
  ------------------------------------------------------------------------

PROCEDURE p_find_anchor_pick_items
     (i_parent_pallet_id    IN      erd_lpn.parent_pallet_id%TYPE,
      i_sn_no               IN      erd_lpn.sn_no%TYPE,
      i_putaway_repl_ind    IN      VARCHAR2,
      o_items               OUT     t_items,
      o_msku_reserve_cube   OUT     NUMBER);

PROCEDURE p_process_floating_items_msku
         (i_item_info_rec IN   pl_putaway_utilities.t_item_related_info,
          i_sn_no         IN   erd_lpn.sn_no%TYPE,
          io_work_var_rec  IN OUT  pl_putaway_utilities.t_work_var,
          i_parent_pl_id  IN   erd_lpn.parent_pallet_id%TYPE,
          i_items         IN   t_floating_putaway,
          i_aging_days    IN   aging_items.aging_days%TYPE,
          i_clam_bed_tracked_flag IN sys_config.config_flag_val%TYPE);

PROCEDURE p_assign_msku_putaway_slots(
                  i_sn_number          IN  erd_lpn.sn_no%TYPE,
                  i_parent_pallet_id   IN  t_parent_pallet_id_arr,
                  o_error              OUT BOOLEAN,
                  o_crt_message        OUT VARCHAR2);

PROCEDURE p_assign_home_slot_msku
               (i_pallet_id        IN     erd_lpn.pallet_id%TYPE,
                i_parent_pallet_id IN     erd_lpn.parent_pallet_id%TYPE,
                i_erm_line_id    IN    erd_lpn.erm_line_id%TYPE,
                i_sn_number      IN     erd_lpn.sn_no%TYPE,
                i_prod_id        IN     erd_lpn.prod_id%TYPE,
                i_cpv            IN     erd_lpn.cust_pref_vendor%TYPE,
                io_work_var_rec  IN OUT pl_putaway_utilities.t_work_var,
                i_item_info_rec  IN     pl_putaway_utilities.t_item_related_info,
                i_aging_days     IN    aging_items.aging_days%TYPE,
                i_clam_bed_trk   IN    sys_config.config_flag_val%TYPE);

PROCEDURE p_sub_divide_msku_pallet
                (i_pallet_id        IN erd_lpn.pallet_id%TYPE,
                 io_parent_pallet_id IN OUT erd_lpn.parent_pallet_id%TYPE,
                 i_pallet_type      IN pallet_type.pallet_type%TYPE,
             i_sub_divide_type  IN VARCHAR2,    
                 o_status           OUT NUMBER);

PROCEDURE p_is_msku_too_large (    
          i_parent_pallet_id   IN  putawaylst.parent_pallet_id%TYPE,
          i_msku_lp_limit           IN  NUMBER,
          i_status_normal               IN  NUMBER,
          i_status_msku_lp_limit        IN  NUMBER,
          o_status                  OUT NUMBER, 
          o_lpcount                 OUT NUMBER);  

PROCEDURE p_find_reserve_slot_for_msku
           (i_parent_pallet_id     IN erd_lpn.parent_pallet_id%TYPE,
            i_sn_number            IN erd_lpn.sn_no%TYPE,
            putaway_repl_indicator IN VARCHAR2,
            io_num_of_req_loc      IN OUT NUMBER,
        o_avl_locations        OUT pl_msku.t_phys_loc);

 ---------------------------------------------------------------------------
  -- Function Declarations
 ----------------------------------------------------------------------------


FUNCTION f_is_msku_pallet
          (i_pallet_id         IN      inv.logi_loc%TYPE,
           i_indicator         IN      CHAR)
RETURN BOOLEAN;

FUNCTION f_val_multiple_pk
          (i_pallet_id         IN      trans.pallet_id%TYPE,
            i_user_id           IN      trans.user_id%TYPE,
            i_mode              IN      CHAR)
RETURN NUMBER;

FUNCTION f_find_reserve_slot_for_msku
           (i_parent_pallet_id     IN erd_lpn.parent_pallet_id%TYPE,
            i_sn_number            IN erd_lpn.sn_no%TYPE,
            putaway_repl_indicator IN VARCHAR2,
            o_dest_loc             OUT loc.logi_loc%TYPE)
RETURN BOOLEAN;


FUNCTION f_update_msku_info_by_lp(
            i_sn_number        IN erd_lpn.sn_no%type,
            i_parent_pallet_id IN erd_lpn.parent_pallet_id%TYPE,
            i_child_pallet_id  IN erd_lpn.pallet_id%TYPE,
            i_pallet_type      IN erd_lpn.pallet_type%TYPE,
            i_indicator        IN VARCHAR2)
RETURN BOOLEAN;

FUNCTION f_update_msku_info_by_item
         (i_sn_number                  IN erd_lpn.sn_no%type,
          i_parent_pallet_id           IN erd_lpn.parent_pallet_id%TYPE,
          i_pallet_type                IN erd_lpn.pallet_type%TYPE,
          i_prod_id                    IN erd_lpn.prod_id%TYPE,
          i_original_parent_pallet_id  IN erd_lpn.parent_pallet_id%TYPE,
          i_indicator                  IN VARCHAR2)
RETURN BOOLEAN;

FUNCTION f_substitute_msku_pallet(
            i_pallet_id        IN  erd_lpn.pallet_id%TYPE,
            i_dest_loc         IN  loc.logi_loc%TYPE)
RETURN BOOLEAN;

FUNCTION f_substitute_msku_pallet(
            i_pallet_id        IN erd_lpn.pallet_id%TYPE,
            i_type             IN VARCHAR2,
            i_task_id          IN replenlst.task_id%TYPE,
            o_pallet_id        OUT erd_lpn.pallet_id%TYPE)
RETURN BOOLEAN;

PROCEDURE p_is_msku_symb_multi_loc (    
          i_parent_pallet_id        IN  putawaylst.parent_pallet_id%TYPE,          
          i_status_normal           IN  NUMBER,
          i_status_msku_lp_limit    IN  NUMBER,
          o_status                  OUT NUMBER );  
          
END pl_msku;
/


CREATE OR REPLACE PACKAGE BODY SWMS.pl_msku  AS

--  sccs_id=@(#) src/schema/plsql/pl_msku.sql, swms, swms.9, 10.2 7/15/09 1.24

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name  CONSTANT VARCHAR2(30) := 'pl_msku';   -- Package name.  Used
                                                   -- in messages.

gl_application_func CONSTANT VARCHAR2(30) := 'MSKU RECEIVING AND PUTAWAY';

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.

---------------------------------------------------------------------------
-- Private Constants
---------------------------------------------------------------------------

-- The type of pallet a MSKU will be on.  The business rule is a MSKU will
-- always be on a LW.  It is used in calculating the cube of the MSKU when
-- it is going to a reserve slot.
ct_msku_physical_pallet_type  CONSTANT pallet_type.pallet_type%TYPE := 'LW';

-- The skid cube for a MSKU if there is an error in determining waht it is.
ct_msku_skid_cube  CONSTANT  NUMBER  := 5.5;



---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

/*-----------------------------------------------------------------------
   -- Procedure:
   --    p_is_msku_too_large
   --
   -- Description:
   -- To count the LPs of a MSKU and return count, status to ensure max is
   -- not greater than MSKU_PALLETS_LP
   --
   -- Parameters:
   --    i_parent_pallet_id    parent pallet ID or any LP of thei MSKU
   --    o_status               0=normal, 336 if too large
   --    o_lpcount              count of LPs from putawaylst table
   --
   -- Called From
   --    pro*C program such as pre_putaway, chkin_req
   -- Exceptions raised:
   --
   ---------------------------------------------------------------------*/
PROCEDURE p_is_msku_too_large (
                  i_parent_pallet_id   IN  putawaylst.parent_pallet_id%TYPE,
                  i_msku_lp_limit              IN  NUMBER,
                  i_status_normal                 IN  NUMBER,
                  i_status_msku_lp_limit          IN  NUMBER,
                  o_status                     OUT NUMBER,
                  o_lpcount                    OUT NUMBER)
IS

BEGIN
   SELECT COUNT(*)
      INTO     o_lpcount
          FROM     putawaylst
          WHERE    parent_pallet_id IN
          (SELECT parent_pallet_id FROM putawaylst
           WHERE i_parent_pallet_id IN (pallet_id, parent_pallet_id));
   IF (o_lpcount > i_msku_lp_limit ) THEN
       o_status := i_status_msku_lp_limit;
   ELSE
        o_status := i_status_normal;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      o_status  := sqlerrm;
      o_lpcount := 0;
   WHEN OTHERS THEN
      RAISE;
END;

---------------------------------------------------------------------------
-- Procedure:
--    delete_putaway_batch
--
-- Description:
--    This procedure deletes the forklift labor mgmt putaway batch
--    for a pallet.  It is called in situations where the putawaylst record
--    is deleted.
--
-- Parameters:
--    i_pallet_id   - Pallet id to delete the putaway batch for.
--
-- Called By:
--    - p_sssign_msku_putaway_slots.
--
-- Exceptions raised:
--    None.  An error will be logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/25/04 prpbcb   Created.
--                      There was a bug in the RDC MSKU sub-divide processing
--                      that resulted in the putawaylst record not having
--                      the forklift labor mgmt batch number in the
--                      putawaylst.pallet_batch_no column.
--
--                      The sub-divide processing will delete the putawaylst
--                      records then re-create them.  What was happening was
--                      the batch record was left alone and the putawaylst
--                      record recreated which resulted in the pallet_batch_no
--                      being null.  Now the batch record will be deleted
--                      and re-created.
--                      The batch record is deleted in this package.  It will
--                      be re-created in process_msku.pc
--
---------------------------------------------------------------------------
PROCEDURE delete_putaway_batch(i_pallet_id  IN putawaylst.pallet_id%TYPE)
IS
   l_message     VARCHAR(512);   -- Message buffer
   l_object_name VARCHAR2(61) := gl_pkg_name || '.delete_putaway_batch';
BEGIN
   DELETE
     FROM batch
    WHERE batch_no =
             (SELECT pallet_batch_no
                FROM putawaylst
               WHERE pallet_id = i_pallet_id);

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name || 'TABLE=batch  ACTION=DELETE' ||
                       '  KEY=[' || i_pallet_id || '](i_pallet_id)' ||
                      '  Error occurred when attempting to delete record' ||
                      ' using putawaylst.pallet_batch_no.' ||
                      '  This will not stop processing.';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
END delete_putaway_batch;


---------------------------------------------------------------------------
-- Procedure:
--    f_get_msku_skid_cube
--
-- Description:
--    This function returns the cube of the skid the MSKU is on.
--
-- Parameters:
--    None
--
-- Return Value:
--    The skid cube for the MSKU.
--
-- Called By:
--    - p_find_anchor_pick_items
--
-- Exceptions Raised:
--    None.  An error will be logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/08/04 prpbcb   Created.
--                      This is part of changes added when determining
--                      the reserve slot for a MSKU.  Before there was no
--                      check if the MSKU would actually fit in the slot
--                      based on the cube.  Now the cube is checked.
---------------------------------------------------------------------------
FUNCTION f_get_msku_skid_cube
RETURN NUMBER IS
   l_message     VARCHAR(512);   -- Message buffer
   l_object_name VARCHAR2(61) := gl_pkg_name || '.f_get_msku_skid_cube';

   l_return_value  NUMBER;
BEGIN

   BEGIN
      SELECT skid_cube
        INTO l_return_value
        FROM pallet_type
       WHERE pallet_type = ct_msku_physical_pallet_type;

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_return_value := ct_msku_skid_cube;

         l_message := l_object_name || 'TABLE=pallet_type  ACTION=SELECT' ||
             '  KEY=[' || ct_msku_physical_pallet_type || ']' ||
             '(ct_msku_physical_pallet_type)' ||
             '  Did not find the pallet type.  Will use ' ||
             TO_CHAR(ct_msku_skid_cube) || ' as the skid cube.';

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        NULL, NULL);

      WHEN OTHERS THEN
         l_return_value := ct_msku_skid_cube;

         l_message := l_object_name || 'TABLE=pallet_type  ACTION=SELECT' ||
             '  KEY=[' || ct_msku_physical_pallet_type || ']' ||
             '(ct_msku_physical_pallet_type)' ||
             '  Oracle Error occurred.  Will use ' ||
             TO_CHAR(ct_msku_skid_cube) || ' as the skid cube.';

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
   END;

   RETURN l_return_value;
END f_get_msku_skid_cube;


/*-----------------------------------------------------------------------
-- Procedure:
--    send_to_induction_loc
--
-- Description:
--    This procedure directs miniload items to the appropriate induction
--    location.
--
-- Parameters:
--    i_pallet_id          Child pallet id to be putaway.
--    i_parent_pallet_id   Parent pallet id of MSKU pallet
--    i_sn_number          Shipment number
--    i_prod_id            Product id of the child pallet
--    i_cpv                Customer preferred vendor
--    io_work_var_rec      Just for compliance with the existing reused code
--    i_item_info_rec      All details pertaining to the product are in
--                         this structure.
--
-- Exceptions Raised:
--
-- Called By:
--    -
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/09/06 prpbcb   Created
--    09/30/14 prpbcb   Renamed from "p_process_miniload_items_msku"
--                      to "send_to_induction_loc".
--    07/21/15 prpbcb   Brian Bent
--                      Matrix item always went to the induction location
--                      and did not use the MSKU matrix induction/staging
--                      syspar.  The syspar value is in the item info
--                      record in field "mx_case_msku_induction_loc".
--                      Changed this procedure to send the value in
--                      "mx_case_msku_induction_loc" if a matrix item.
---------------------------------------------------------------------*/
PROCEDURE send_to_induction_loc
           (i_pallet_id        IN     erd_lpn.pallet_id%TYPE,
            i_parent_pallet_id IN     erd_lpn.parent_pallet_id%TYPE,
            i_erm_line_id      IN     erd_lpn.erm_line_id%TYPE,
            i_sn_number        IN     erd_lpn.sn_no%TYPE,
            i_prod_id          IN     erd_lpn.prod_id%TYPE,
            i_cpv              IN     erd_lpn.cust_pref_vendor%TYPE,
            io_work_var_rec    IN OUT pl_putaway_utilities.t_work_var,
            i_item_info_rec    IN     pl_putaway_utilities.t_item_related_info,
            i_aging_days       IN     aging_items.aging_days%TYPE,
            i_clam_bed_trk     IN     sys_config.config_flag_val%TYPE)
IS
   lv_pname            VARCHAR2(50)  := 'send_to_induction_loc';

   l_induction_loc     loc.logi_loc%TYPE;
BEGIN
   -- Reset the global variable
   pl_log.g_program_name     := 'PL_MSKU';

   -- This will be used in the Exception message
   pl_putaway_utilities.gv_program_name := lv_pname;

   pl_log.ins_msg('INFO', lv_pname,
                  'Item=' || i_prod_id
                  || ' CPV=' || i_cpv
                  || ' Induction loc=' || i_item_info_rec.v_case_induction_loc
                  || ' SN=' || i_sn_number
                  || '  Directing item to induction location.',
                  NULL, NULL);

   -- populate io_work_var_rec before inserting

   /* 10/27/06 BEG DEL Infosys -  MSKU Pallets can have qty > 1.*/
   /*io_work_var_rec.n_each_pallet_qty := 1;*/
   /* 10/27/06 END DEL Infosys */

   io_work_var_rec.v_no_splits := i_item_info_rec.n_spc;

   -- reset the global variable
   pl_log.g_program_name     := 'PL_MSKU';

   IF (    i_item_info_rec.v_mx_item_assign_flag = 'Y'    -- 07/21/2015  Brian Bent Added
       AND i_item_info_rec.mx_eligible = 'Y')
   THEN
      l_induction_loc := i_item_info_rec.mx_case_msku_induction_loc;
   ELSE
      l_induction_loc := i_item_info_rec.v_case_induction_loc;
   END IF;


   pl_putaway_utilities.p_insert_table
                       (i_prod_id,
                        i_cpv,
                        l_induction_loc,
                        pl_putaway_utilities.ADD_RESERVE,
                        i_sn_number,
                        i_aging_days,
                        i_clam_bed_trk,
                        i_item_info_rec,
                        io_work_var_rec);

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg('WARN', lv_pname,
                       'Item=' || i_prod_id
                       || ' CPV=' || i_cpv
                       || ' Induction loc='
                       || i_item_info_rec.v_case_induction_loc
                       || ' SN=' || i_sn_number
                       || ' Error processing miniload item.',
                       SQLCODE, SQLERRM);

      pl_putaway_utilities.gv_crt_message :=
                   RPAD(pl_putaway_utilities.gv_crt_message,80)
                   || ' Item=' || i_prod_id
                   || ' CPV=' || i_cpv
                   || ' Induction loc='
                   || i_item_info_rec.v_case_induction_loc
                   || 'SN ='||i_sn_number
                   || ' MESSAGE='
                   || 'Error processing miniloader item.'
                   || ' sqlcode='
                   || SQLCODE;

      RAISE;
END send_to_induction_loc;

---------------------------------------------------------------------------
-- Function:
--    item_has_case_home_slot
--
-- Description:
--    This function returns TRUE if an item has a case home slot otherwise
--    FALSE.
--
-- Parameters:
--    i_prod_id
--    i_cpv
--
-- Return Value:
--    TRUE  - If the item has a case home slot.
--    FALSE - If the item does not have a case home slot.
--
-- Called By:
--    - f_update_msku_info_by_lp
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/07/09 prpbcb   Created.
--                      This is part of the MSKU sub-divide bug fixes.
---------------------------------------------------------------------------
FUNCTION item_has_case_home_slot
              (i_prod_id   IN pm.prod_id%TYPE,
               i_cpv       IN pm.cust_pref_vendor%TYPE)
RETURN BOOLEAN
IS
   l_message     VARCHAR(512);   -- Message buffer
   l_object_name VARCHAR2(61);

   l_dummy         VARCHAR2(1);  -- Work area
   l_return_value  BOOLEAN;
BEGIN
   l_return_value := TRUE;

   BEGIN
      --
      -- Look for rank 1 case home slot.
      --
      SELECT DISTINCT 'x'  -- Use distinct in case there are case home slots
        INTO l_dummy       -- with the same rank.
        FROM loc
       WHERE loc.prod_id          = i_prod_id
         AND loc.cust_pref_vendor = i_cpv
         AND loc.rank             = 1
         AND loc.uom              IN (0, 2);

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_return_value := FALSE;
   END;

   RETURN(l_return_value);

EXCEPTION
   WHEN OTHERS THEN
      l_object_name := gl_pkg_name || '.item_has_case_home_slot';
      l_message := 'TABLE=loc  ACTION=SELECT'
             || '  KEY=[' || i_prod_id || ']'
             || '[' || i_cpv || ']'
             || '(i_prod_id,i_cpv)'
             || '  REASON=Oracle Error occurred.';

      pl_log.ins_msg('FATAL', l_object_name, l_message,
                     SQLCODE, SQLERRM, gl_application_func, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END item_has_case_home_slot;


---------------------------------------------------------------------------
-- Procedure:
--    log_item_info
--
-- Description:
--    This procedure logs information about the item being processed
--    For debugging purposes.
--
-- Parameters:
--    i_r_item_info  - Item information record.
--
-- Called By:
--    - Various procedures
--
-- Exceptions raised:
--    None.  An error will be logged.  A failure to log the item info
--    is not considered to be a fatal error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/24/14 prpbcb   Created.
--    07/22/15 prpbcb   Add a few fields.
--
---------------------------------------------------------------------------
PROCEDURE log_item_info(i_r_item_info  IN pl_putaway_utilities.t_item_related_info)
IS
   l_message     VARCHAR(512);   -- Message buffer
BEGIN
   pl_log.ins_msg(pl_lmc.ct_info_msg, 'log_item_info',
           'Item['                    || i_r_item_info.prod_id                || ']'
       ||  '  CPV['                   || i_r_item_info.cust_pref_vendor       || ']'
       ||  '  PM area['               || i_r_item_info.v_area                 || ']'
       ||  '  PM last_ship_slot['     || i_r_item_info.v_last_ship_slot       || ']'
       ||  '  PM zone id['            || i_r_item_info.v_zone_id              || ']'
       ||  '  PM zone rule id['       || to_char(i_r_item_info.n_rule_id)     || ']'
       ||  '  Auto ship flag['        || i_r_item_info.v_auto_ship_flag       || ']'
       ||  '  Miniload storage ind['  || i_r_item_info.v_miniload_storage_ind || ']'
       ||  '  Case induction loc['    || i_r_item_info.v_case_induction_loc   || ']'
       ||  '  MX Case MSKU Receiving PUT loc[' || i_r_item_info.mx_case_msku_induction_loc || ']'
       ||  '  Split induction loc['   || i_r_item_info.v_split_induction_loc  || ']'
       ||  '  MX item assign flag['   || i_r_item_info.v_mx_item_assign_flag  || ']'
       ||  '  MX eligible['           || i_r_item_info.mx_eligible            || ']',
       NULL, NULL,
       gl_application_func, gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      l_message := 'Error when logging info about item'
           || '['      || i_r_item_info.prod_id          || ']'
           || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
           || '  This will not stop processing.';
      pl_log.ins_msg(pl_lmc.ct_warn_msg, 'log_item_info', l_message,
                     SQLCODE, SQLERRM,
                     gl_application_func, gl_pkg_name);
END log_item_info;


---------------------------------------------------------------------------
-- end of private modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

/*-----------------------------------------------------------------------
-- Function:
--    p_assign_msku_putaway_slots
--
-- Description:
-- This procedure involves processing of each MSKU pallet in
-- a shipment and identifying putaway slots for them in advance
-- it can also be used when we sub divide a MSKU pallet into many and
-- want to identify putaway slots for them
--
-- Parameters:
--    i_sn_number   - Shipment order number.
--    o_error       - Boolean Flag (no use found for it so far)
--                  - TRUE:In case of error
--                  - FALSE:No Error
--    o_crt_message - Message for displaying on
--                  - CRT screens.(not yet used)
--
-- Called From
--
-- Exceptions raised:
--
-- Modification History:
--    Date     Designer   Comments
--    -------- --------   --------------------------------------------------
--    02/08/06 prpbcb     WAI changes.
--                        Modifications to handle rule id 3.
--    09/18/14 vred5319   Modified to handle matrix items
--    09/26/14 prbcb000   Populate lt_item_info_rec.aging_days
-------------------------------------------------------------------------*/
PROCEDURE p_assign_msku_putaway_slots(
                  i_sn_number          IN  erd_lpn.sn_no%TYPE,
                  i_parent_pallet_id   IN  t_parent_pallet_id_arr,
                  o_error              OUT BOOLEAN,
                  o_crt_message        OUT VARCHAR2)
IS
lv_pname                 VARCHAR2(30) := 'p_assign_msku_putaway_slots';

lt_item_info_rec         pl_putaway_utilities.t_item_related_info;
lt_item_info_rec_prev    pl_putaway_utilities.t_item_related_info;
lt_work_var_rec          pl_putaway_utilities.t_work_var;
lt_work_var_rec_prev     pl_putaway_utilities.t_work_var;
lt_floating_putaway      t_floating_putaway;
lt_floating_putaway_clean t_floating_putaway;
lv_prod_id                erd_lpn.prod_id%TYPE := '   ';
lv_cpv                     erd_lpn.cust_pref_vendor%TYPE := '   ';
ln_rule_id                zone.rule_id%TYPE := NULL;
ln_aging_days             aging_items.aging_days%TYPE := 0;
ln_aging_days_prev        aging_items.aging_days%TYPE := 0;
ltbl_parent_pallet_id     t_parent_pallet_id_arr;

lb_putaway BOOLEAN := FALSE;
lb_no_pallets BOOLEAN := TRUE;
lb_reserve_putaway_status BOOLEAN := FALSE;

ln_counter              NUMBER := 1;
ln_pallets_putaway      NUMBER := 0;
ln_pallets_total        NUMBER := 0;
lv_clam_bed_trk         sys_config.config_flag_val%TYPE;
lv_clam_bed_trk_prev    sys_config.config_flag_val%TYPE;
lv_pallet_type          erd_lpn.pallet_type%TYPE;
lv_dest_loc             loc.logi_loc%type;
lv_home_putaway         sys_config.config_flag_val%TYPE;

CURSOR c_parent_pallets
IS
SELECT DISTINCT parent_pallet_id
  FROM erd_lpn
  WHERE sn_no = i_sn_number
  AND parent_pallet_id IS NOT NULL;

/*acpppp<11/13/03>
  Modified the child cursor.
  In case zone is not set up for any product, current system
  "*" out the location for all the pallets of that product.
  For MSKU in such scenario , location for all the child LPs
  of all the products on that MSKU  needs to be "*" out.

  Cursor modified to query Lps of such products also.

  prpakp 8/9/05
  If the zone for the home slot of an item is rule=2, then this will order thta item to be the last
  instead of the floating and that fails the finding floating location  process causing SN not to open.
  Decoded rule=2 to behave like rule=0

  prpbcb 2/8/06
  WAI changes.  Treat rule id 3 like rule id 0 in the order by.

*/

CURSOR c_child_pallets(i_parent_pallet IN erd_lpn.parent_pallet_id%TYPE,
                       i_sn_number IN erd_lpn.sn_no%TYPE)
IS
SELECT erd_lpn.pallet_id,
       erd_lpn.prod_id,
       erd_lpn.cust_pref_vendor,
       erd_lpn.qty,
       erd_lpn.erm_line_id,
       TRUNC(erd_lpn.exp_date) exp_date,
       DECODE(SUBSTR(erd_lpn.lot_id, 1, 1), 'P', NULL, erd_lpn.lot_id) lot_id
  FROM erd_lpn, pm, zone
 WHERE parent_pallet_id                      = i_parent_pallet
   AND erd_lpn.sn_no                         = i_sn_number
   AND NVL(erd_lpn.pallet_assigned_flag,'N') ='N'
   AND pm.prod_id                            = erd_lpn.prod_id
   AND pm.zone_id                            = zone.zone_id (+)
 ORDER BY 
          --
          -- Process miniloader items first.
          DECODE(NVL(zone.rule_id, 0),
                 3, -5, 
                 0) ASC,
          --
          -- Process matrix items second.  Matrix eligible and matrix assigned
          -- both have to be 'Y' in order for the child LP to be sent to
          -- the matrix.
          DECODE(pm.mx_eligible || pm.mx_item_assign_flag,
                 'YY', -4,
                 0),
          --
          -- And process the other items.
          DECODE(NVL(zone.rule_id, 0),
                 2, 0,
                 NVL(zone.rule_id, 0)) ASC,
          pm.prod_id, erd_lpn.exp_date ASC, erd_lpn.lot_id ASC;

CURSOR c_msku_reserve(i_parent_pallet IN erd_lpn.parent_pallet_id%TYPE,
                      i_sn_number IN erd_lpn.sn_no%TYPE)
IS
SELECT erd_lpn.pallet_id,
       erd_lpn.prod_id,
       erd_lpn.cust_pref_vendor,
       erd_lpn.qty,
       erd_lpn.erm_line_id
  FROM erd_lpn
 WHERE parent_pallet_id = i_parent_pallet
   AND erd_lpn.sn_no = i_sn_number
   AND NVL(erd_lpn.pallet_assigned_flag,'N') ='N'
   AND NOT EXISTS (SELECT 'X'
                     FROM putawaylst p
                    WHERE p.pallet_id = erd_lpn.pallet_id)
 ORDER BY erd_lpn.prod_id ASC;

BEGIN
   pl_log.ins_msg('INFO',lv_pname,
                  'TABLE=none  KEY='
                     || i_sn_number
                     || '  MESSAGE=Starting MSKU Putaway for SN['
                     || i_sn_number||']',
                  NULL, NULL,
                  gl_application_func, gl_pkg_name);
   pl_log.g_program_name     := 'PL_MSKU';

   lv_pname :='p_assign_msku_putaway_slots';

   --for CRT error reporting
   pl_putaway_utilities.gv_program_name := lv_pname;
   --initializing lt_work_var_rec.lt_work_var_rec.

   /* 10/27/06 BEG DEL Infosys - MSKU Pallets can have qty > 1. */
   /* lt_work_var_rec.n_each_pallet_qty := 1; */
   /* 10/27/06 END DEL Infosys */

   --getting syspar to be passed on to process_floating_items_msku
   lv_clam_bed_trk := pl_common.f_get_syspar('CLAM_BED_TRACKED');
   --reset the global variable
    pl_log.g_program_name     := 'PL_MSKU';

   pl_log.ins_msg('INFO',lv_pname,'TABLE= none KEY = '
                                           ||i_sn_number
                                           ||' MESSAGE= Starting MSKU'
                                           ||' Putaway for SN['
                                           ||i_sn_number||']',
                                           NULL,NULL);

   IF i_parent_pallet_id.COUNT > 0 THEN
      FOR ln_counter IN i_parent_pallet_id.FIRST..i_parent_pallet_id.LAST LOOP
         ltbl_parent_pallet_id(ln_counter) := i_parent_pallet_id(ln_counter);
      END LOOP;

 /* FOR r_parent_pallets in c_parent_pallets LOOP
         lb_no_pallets := FALSE;
         ltbl_parent_pallet_id(ltbl_parent_pallet_id.last + 1)
                                         := r_parent_pallets.parent_pallet_id;
      END LOOP;*/

   ELSE
      ln_counter := 1;
      FOR r_parent_pallets in c_parent_pallets LOOP
         lb_no_pallets := FALSE;
         ltbl_parent_pallet_id(ln_counter):= r_parent_pallets.parent_pallet_id;
         ln_counter := ln_counter + 1;
      END LOOP;
   END IF;

   IF lb_no_pallets = TRUE AND i_parent_pallet_id.COUNT = 0 THEN

         pl_log.ins_msg('INFO',lv_pname,
                                  'TABLE= erd_lpn KEY = '
                                  || i_sn_number
                                  || ' MESSAGE= No MSKU pallets found for the '
                                  || 'input SN Id',NULL,NULL);

      o_error := FALSE;
      o_crt_message := RPAD('ERROR:Putaway cannot be processed ',80)
                                ||'REASON: ERROR IN : '
                                || pl_putaway_utilities.gv_program_name
                                || ' ,MESSAGE : '
                                ||'TABLE= erd_lpn KEY = '
                                ||i_sn_number
                                ||' MESSAGE= No MSKU pallets found for the '
                                ||'input SN ID';
      RETURN;
   END IF;

   pl_log.ins_msg('INFO', lv_pname,
                     'SN[' || i_sn_number || ']'
                        || ' has ' || TO_CHAR(ltbl_parent_pallet_id.COUNT)
                        || ' parent pallet id(s) to process.',
                     NULL, NULL,
                     gl_application_func, gl_pkg_name);

   FOR ln_counter  IN  ltbl_parent_pallet_id.FIRST .. ltbl_parent_pallet_id.LAST
   LOOP
      pl_log.ins_msg('INFO', lv_pname,
                     'SN[' || i_sn_number || ']'
                        || '  Processing parent pallet id['
                        || ltbl_parent_pallet_id(ln_counter) || ']',
                     NULL, NULL,
                     gl_application_func, gl_pkg_name);

      SAVEPOINT S;

      FOR r_child_pallets IN c_child_pallets(ltbl_parent_pallet_id(ln_counter), i_sn_number)
      LOOP
         IF (   r_child_pallets.prod_id          <> lv_prod_id
             OR r_child_pallets.cust_pref_vendor <> lv_cpv)
         THEN
            lt_floating_putaway.qty := 0;
            lv_prod_id := r_child_pallets.prod_id;
            lv_cpv := r_child_pallets.cust_pref_vendor;

            pl_putaway_utilities.p_get_item_info(lv_prod_id,
                                                 lv_cpv,
                                                 lt_item_info_rec);
            --
            -- Log item info.
            --
            log_item_info(lt_item_info_rec);

            --reset the global variable
            pl_log.g_program_name     := 'PL_MSKU';


            ln_aging_days := pl_putaway_utilities.f_retrieve_aging_items
                                                 (lv_prod_id,
                                                  lv_cpv);

            lt_item_info_rec.aging_days  := ln_aging_days;

            --reset the global variable
            pl_log.g_program_name     := 'PL_MSKU';

            lb_putaway := pl_putaway_utilities.f_check_home_item(lt_item_info_rec);
/*******
            lb_putaway := pl_putaway_utilities.f_check_home_item
                                             (lv_prod_id,
                                              lv_cpv,
                                              ln_aging_days,
                                              lt_item_info_rec.v_zone_id,
                                              lt_item_info_rec.v_last_ship_slot);
*****/

            --reset the global variable
            pl_log.g_program_name     := 'PL_MSKU';
            lt_work_var_rec.v_no_splits := lt_item_info_rec.n_spc;

            /*For debugging*/
        IF lb_putaway = TRUE THEN
          pl_log.ins_msg('INFO',lv_pname,
                         'Returned value from check home item for product['
                            || lv_prod_id || '] is true',
                         NULL, NULL,
                         gl_application_func, gl_pkg_name);
            ELSE
          pl_log.ins_msg('INFO',lv_pname,
                         'Returned value from check home item for product['
                            || lv_prod_id || '] is false',
                         NULL, NULL,
                         gl_application_func, gl_pkg_name);
            END IF;

            /*End debug*/

         END IF;

            /*10/27/06 BEG INS Infosys - Inserted to support MSKU LPs with QTY > 1 */
            lt_work_var_rec.n_each_pallet_qty := r_child_pallets.qty/lt_item_info_rec.n_spc;
            /* 10/27/06 END INS Infosys */

         IF lb_putaway = TRUE THEN

            BEGIN
               SELECT decode(rule_id, 2, 0, 5, 0, rule_id)
                 INTO ln_rule_id
                 FROM zone
                WHERE zone.zone_id = lt_item_info_rec.v_zone_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
               pl_log.ins_msg('WARN', lv_pname,
                              'TABLE=zone  KEY=['
                                 || lt_item_info_rec.v_zone_id || ']'
                                 || '  ACTION=SELECT MESSAGE=invalid zone id ',
                              NULL, NULL,
                              gl_application_func, gl_pkg_name);

               pl_putaway_utilities.gv_crt_message :=
                              RPAD(pl_putaway_utilities.gv_crt_message,80)
                              || 'TABLE=zone  KEY='
                              || lt_item_info_rec.v_zone_id
                              || ' ACTION = SELECT MESSAGE ='
                              || 'invalid zone id '
                              || ' - sqlcode= ' || sqlcode;

               RAISE;
               WHEN OTHERS THEN
               pl_log.ins_msg('WARN', lv_pname,
                              'TABLE=zone KEY=['
                                 || lt_item_info_rec.v_zone_id || ']'
                                 || ' ACTION=SELECT  MESSAGE=Unable to select from zone'
                                 || ' table ',
                              NULL, NULL,
                              gl_application_func, gl_pkg_name);

               pl_putaway_utilities.gv_crt_message :=
                                  RPAD(pl_putaway_utilities.gv_crt_message,80)
                                  ||'TABLE =zone KEY='
                                  ||lt_item_info_rec.v_zone_id
                                  ||' ACTION = SELECT MESSAGE ='
                                  ||'unable to select from zone'
                                  ||' table '
                                  ||' - sqlcode= ' ||sqlcode;
               RAISE;

            END;

            lv_home_putaway := 'N';
            lv_home_putaway := pl_common.f_get_syspar('HOME_PUTAWAY');
            pl_log.g_program_name := 'PL_MSKU';

            --
            -- Log warning message if the item is assigned to the matrix but
            -- not matrix eligible.
            --
            IF (    lt_item_info_rec.v_mx_item_assign_flag = 'Y'
                AND NVL(lt_item_info_rec.mx_eligible, 'x') <> 'Y')
            THEN
               pl_log.ins_msg(pl_lmc.ct_error_msg, 'log_item_info',
                     'Item['                    || lt_item_info_rec.prod_id                || ']'
                  || '  CPV['                   || lt_item_info_rec.cust_pref_vendor       || ']'
                  || '  MX item assign flag['   || lt_item_info_rec.v_mx_item_assign_flag  || ']'
                  || '  MX eligible['           || lt_item_info_rec.mx_eligible            || ']'
                  || '  This item is assigned to the matrix but is not matrix eligible.'
                  || '  This will need to be investigated.'
                  || '  The cases for this item on the MSKU will be directed to the main warehouse.',
                  NULL, NULL,
                  gl_application_func, gl_pkg_name);
            END IF;

            --
            -- For an item to be sent to the matrix induction location it has
            -- to be assigned to the matrix and be matrix eligible.
            --
            IF (    lt_item_info_rec.v_mx_item_assign_flag = 'Y'    ------ Vani Reddy added
                AND lt_item_info_rec.mx_eligible = 'Y')
            THEN 
               --
               -- The cases for the item go to the matrix.
               --
               lt_work_var_rec.n_erm_line_id := r_child_pallets.erm_line_id;
               lt_work_var_rec.v_pallet_id   := r_child_pallets.pallet_id;
               lt_work_var_rec.v_lot_id      := r_child_pallets.lot_id;
               lt_work_var_rec.v_exp_date    := TRUNC(r_child_pallets.exp_date);

               send_to_induction_loc
                              (r_child_pallets.pallet_id,
                               ltbl_parent_pallet_id(ln_counter),
                               r_child_pallets.erm_line_id,
                               i_sn_number,
                               r_child_pallets.prod_id,
                               r_child_pallets.cust_pref_vendor,
                               lt_work_var_rec,
                               lt_item_info_rec,
                               ln_aging_days,
                               lv_clam_bed_trk);                                   ------ Vani Reddy add end
            ELSIF ln_rule_id = 0  AND lv_home_putaway = 'Y' THEN

               lt_work_var_rec.v_lot_id   := r_child_pallets.lot_id;
               lt_work_var_rec.v_exp_date := TRUNC(r_child_pallets.exp_date);
               p_assign_home_slot_msku
                              (r_child_pallets.pallet_id,
                               ltbl_parent_pallet_id(ln_counter),
                               r_child_pallets.erm_line_id,
                               i_sn_number,
                               r_child_pallets.prod_id,
                               r_child_pallets.cust_pref_vendor,
                               lt_work_var_rec,
                               lt_item_info_rec,
                               ln_aging_days,
                               lv_clam_bed_trk);
            ELSIF ln_rule_id = 3 THEN
               --
               -- The cases for the item go to the miniloader.
               --
              /******
              -- 11/17/08  Brian Bent  Debug stuff
             pl_log.ins_msg ('WARN', lv_pname,
               'XXXXX r_child_pallets.pallet_id: ' || r_child_pallets.pallet_id
                ||  '  ltbl_parent_pallet_id(ln_counter): '
                || ltbl_parent_pallet_id(ln_counter)
                || '  r_child_pallets.prod_id: ' || r_child_pallets.prod_id
                || '  lt_work_var_rec.v_pallet_id: '
                || lt_work_var_rec.v_pallet_id
                || '  lt_work_var_rec.n_erm_line_id: '
                || to_char(lt_work_var_rec.n_erm_line_id),
                NULL, NULL);
               *****/

               lt_work_var_rec.n_erm_line_id := r_child_pallets.erm_line_id;
               lt_work_var_rec.v_pallet_id   := r_child_pallets.pallet_id;
               lt_work_var_rec.v_lot_id      := r_child_pallets.lot_id;
               lt_work_var_rec.v_exp_date    := TRUNC(r_child_pallets.exp_date);

              /******
              -- 11/17/08  Brian Bent  Debug stuff
             pl_log.ins_msg ('WARN', lv_pname,
               'ZZZZZ r_child_pallets.pallet_id: ' || r_child_pallets.pallet_id
                ||  '  ltbl_parent_pallet_id(ln_counter): '
                || ltbl_parent_pallet_id(ln_counter)
                || '  r_child_pallets.prod_id: ' || r_child_pallets.prod_id
                || '  lt_work_var_rec.v_pallet_id: '
                || lt_work_var_rec.v_pallet_id
                || '  lt_work_var_rec.n_erm_line_id: '
                || to_char(lt_work_var_rec.n_erm_line_id),
                NULL, NULL);
               *****/

               send_to_induction_loc
                              (r_child_pallets.pallet_id,
                               ltbl_parent_pallet_id(ln_counter),
                               r_child_pallets.erm_line_id,
                               i_sn_number,
                               r_child_pallets.prod_id,
                               r_child_pallets.cust_pref_vendor,
                               lt_work_var_rec,
                               lt_item_info_rec,
                               ln_aging_days,
                               lv_clam_bed_trk);

            ELSIF ln_rule_id = 1 THEN
               /*no mixing of floating items with different expiry dates
                or different lot ids in the same reserve slots*/
               IF lv_prod_id = lt_floating_putaway.prod_id
                  AND lv_cpv = lt_floating_putaway.cpv
                  AND ((lt_work_var_rec_prev.v_lot_id   = r_child_pallets.lot_id
                       AND lt_item_info_rec.v_lot_trk = 'Y') OR TRUE)
                  AND ((lt_work_var_rec_prev.v_exp_date = TRUNC(r_child_pallets.exp_date)
                       AND lt_item_info_rec.v_fifo_trk = 'A') OR TRUE)
               THEN

                  lt_floating_putaway.qty := lt_floating_putaway.qty + 1;
                  lt_floating_putaway.child_pallet_ids(lt_floating_putaway.qty)
                                                     := r_child_pallets.erm_line_id;

               ELSE
               --if it is a new item, then,putaway the last set of child pallets
               --first,then start populating the structure for the new product
                  IF lt_floating_putaway.child_pallet_ids.count > 0 THEN

                     p_process_floating_items_msku(lt_item_info_rec_prev,
                                                 i_sn_number,
                                                 lt_work_var_rec_prev,
                                                 ltbl_parent_pallet_id(ln_counter),
                                                 lt_floating_putaway,--this structure
                                                 --has all the info, prod_id,cpv,
                                                 --number of pallets and there
                                                 -- erm_line_id in erd_lpn table
                                                 ln_aging_days_prev,
                                                 lv_clam_bed_trk_prev);

                     pl_log.ins_msg('INFO',lv_pname,'Returned from '
                                              ||'process_floating_items_msku'
                                              ||' for parent_pallet_id ='
                                              ||ltbl_parent_pallet_id(ln_counter)
                                              ||'and product = '
                                              ||lt_floating_putaway.prod_id
                                              || ' all child pallets of this'
                                              ||' product on this MSKU pallet '
                                              ||'have either been putaway or '
                                              ||'*ed out ',NULL,NULL);
                  END IF;



               --clean the structure here
               lt_floating_putaway := lt_floating_putaway_clean;
               --initializing
               lt_floating_putaway.qty := 1;
               lt_floating_putaway.prod_id := lv_prod_id;
               lt_floating_putaway.cpv := lv_cpv;
               lt_floating_putaway.child_pallet_ids(lt_floating_putaway.qty):= r_child_pallets.erm_line_id;
               lt_work_var_rec.v_lot_id   := r_child_pallets.lot_id;
               lt_work_var_rec.v_exp_date := TRUNC(r_child_pallets.exp_date);
               --------------------
               --backup to be used by p_process_floating_items_msku
               lt_item_info_rec_prev := lt_item_info_rec;
               lt_work_var_rec_prev :=  lt_work_var_rec;
               ln_aging_days_prev :=    ln_aging_days;
               lv_clam_bed_trk_prev :=  lv_clam_bed_trk;
               -----------------------
               END IF;
            ELSE
               pl_log.ins_msg('INFO',lv_pname,'TABLE =none KEY='
                              || lt_item_info_rec.v_zone_id
                              || ','||ln_rule_id
                              || ' invalid zone id or invalid rule id',
                              NULL,NULL);
            END IF;
         ELSE
            EXIT;
         END IF;
      END LOOP;

   IF lb_putaway= FALSE THEN

            ROLLBACK TO S;
            pl_log.ins_msg('INFO',lv_pname,'TABLE= none KEY = '
                                        ||lv_prod_id
                                        || ','|| lv_cpv ||','
                                        ||ltbl_parent_pallet_id(ln_counter)
                                        ||'MESSAGE= check_home_item'
                                        ||' returned FALSE for '
                                        ||' product'||lv_prod_id
                                        ||' hence all putaway done so far for '
                                        ||'this MSKU pallet was rolled back and'
                                        ||'all the child pallets of this MSKU'
                                        ||'pallet '
                                        ||ltbl_parent_pallet_id(ln_counter)
                                        ||' will be *ed out',NULL,NULL);

            FOR r_child_pallets
            IN c_child_pallets(ltbl_parent_pallet_id(ln_counter),i_sn_number) LOOP

               pl_putaway_utilities.p_get_item_info(r_child_pallets.prod_id,
                                                    r_child_pallets.cust_pref_vendor,
                                                    lt_item_info_rec);

               --
               -- Log item info.
               --
               log_item_info(lt_item_info_rec);

               --reset the global variable
               pl_log.g_program_name     := 'PL_MSKU';

           lt_work_var_rec.v_no_splits := lt_item_info_rec.n_spc;

           /*for debug*/
           pl_log.ins_msg('INFO',lv_pname,'TABLE= none KEY =SPC '
                                       ||lt_work_var_rec.v_no_splits || ' and from pm ' || lt_item_info_rec.n_spc
                                       ||'MESSAGE= prod id is'
                                       ||r_child_pallets.prod_id || ' and cpv is ' || r_child_pallets.cust_pref_vendor
                                       ,NULL,NULL);

               ln_aging_days := pl_putaway_utilities.f_retrieve_aging_items
                                                    (r_child_pallets.prod_id,
                                                     r_child_pallets.cust_pref_vendor);
               --reset the global variable
               pl_log.g_program_name     := 'PL_MSKU';

                  lt_work_var_rec.n_erm_line_id := r_child_pallets.erm_line_id;
                  lt_work_var_rec.v_pallet_id := r_child_pallets.pallet_id;

               /* 10/27/06 BEG INS Infosys - Inserted to supprt MSKU LPs with qty > 1 */
                  lt_work_var_rec.n_each_pallet_qty := r_child_pallets.qty/lt_item_info_rec.n_spc;
          /* 10/27/06 END INS Infosys */

                  lt_work_var_rec.b_first_home_assign  := FALSE;
                  pl_putaway_utilities.p_insert_table
                                  ( r_child_pallets.prod_id,
                                          r_child_pallets.cust_pref_vendor,
                                          '*',
                                          pl_putaway_utilities.ADD_NO_INV,
                                          i_sn_number,
                                          ln_aging_days,
                                          lv_clam_bed_trk,
                                          lt_item_info_rec,
                                          lt_work_var_rec);

                  pl_log.g_program_name     := 'PL_MSKU';
            END LOOP;

            pl_log.ins_msg('INFO',lv_pname,'TABLE= none KEY = '
                                     ||ltbl_parent_pallet_id(ln_counter)
                                     ||'MESSAGE= all child pallets of '
                                     ||'MSKU pallet'
                                     ||ltbl_parent_pallet_id(ln_counter)
                                     ||'were *ed out',NULL,NULL);

   ELSE

      IF lt_floating_putaway.qty <> 0 THEN
      --last floating item won't be putaway by the previous loop

      p_process_floating_items_msku(lt_item_info_rec_prev,
                                    i_sn_number,
                                    lt_work_var_rec_prev,
                                    ltbl_parent_pallet_id(ln_counter),
                                    lt_floating_putaway,
                                    ln_aging_days_prev,
                                    lv_clam_bed_trk_prev);

      pl_log.ins_msg('INFO',lv_pname,'Returned from '
                                           ||'p_process_floating_items_msku'
                                           ||' for parent_pallet_id ='
                                           ||ltbl_parent_pallet_id(ln_counter)
                                           ||'and product = '
                                           ||lt_floating_putaway.prod_id
                                           || ' all child pallets of this'
                                           ||' product on this MSKU pallet '
                                           ||'have either been putaway or '
                                           ||'*ed out ',NULL,SQLCODE);
      lt_floating_putaway := lt_floating_putaway_clean;
      END IF;

      SELECT COUNT(*)
      INTO ln_pallets_putaway
      FROM putawaylst
      WHERE parent_pallet_id = ltbl_parent_pallet_id(ln_counter)
      AND rec_id = i_sn_number;

      SELECT COUNT(*)
      INTO ln_pallets_total
      FROM erd_lpn
      WHERE parent_pallet_id = ltbl_parent_pallet_id(ln_counter)
      AND sn_no = i_sn_number ;

      IF ln_pallets_putaway < ln_pallets_total THEN

          --acppzp testing
               pl_log.ins_msg('WARN',lv_pname,'ACPPZPZ f_find_reserve_slot_for_msku',
                                            NULL,NULL);
         --acppzp testing

         lb_reserve_putaway_status := f_find_reserve_slot_for_msku
                                       (ltbl_parent_pallet_id(ln_counter),
                                        i_sn_number,
                                        'IP',
                                        lv_dest_loc);

         FOR r_msku_reserve
         IN c_msku_reserve(ltbl_parent_pallet_id(ln_counter),i_sn_number)
         LOOP
                   --acppzp testing
                        pl_log.ins_msg('WARN',lv_pname,'ACPPZPZ in loop',
                                                     NULL,NULL);
         --acppzp testing
             lt_work_var_rec.b_first_home_assign  := FALSE;
             lt_work_var_rec.n_erm_line_id :=r_msku_reserve.erm_line_id;
             lt_work_var_rec.v_pallet_id   :=r_msku_reserve.pallet_id;

             pl_putaway_utilities.p_get_item_info
                                           (r_msku_reserve.prod_id,
                                             r_msku_reserve.cust_pref_vendor,
                                             lt_item_info_rec);

             --
             -- Log item info.
             --
             log_item_info(lt_item_info_rec);

             --reset the global variable
             pl_log.g_program_name     := 'PL_MSKU';

             lt_work_var_rec.v_no_splits := lt_item_info_rec.n_spc;

             /* 10/27/06 BEG INS Infosys - Inserted to support MSKU LPs with QTY > 1 */
             lt_work_var_rec.n_each_pallet_qty := r_msku_reserve.qty/lt_item_info_rec.n_spc;
             /* 10/27/06 END INS Infosys */

         /*for debug*/
         pl_log.ins_msg('INFO',lv_pname,'TABLE= none KEY =SPC '
                                       ||lt_work_var_rec.v_no_splits || ' and from pm ' || lt_item_info_rec.n_spc
                                       ||'MESSAGE= prod id is'
                                       ||r_msku_reserve.prod_id || ' and cpv is ' || r_msku_reserve.cust_pref_vendor
                                       ,NULL,NULL);

             ln_aging_days := pl_putaway_utilities.f_retrieve_aging_items
                                           (r_msku_reserve.prod_id,
                                             r_msku_reserve.cust_pref_vendor);
             --reset the global variable
             pl_log.g_program_name     := 'PL_MSKU';
               IF lb_reserve_putaway_status = FALSE THEN

                  pl_putaway_utilities.p_insert_table
                                   ( r_msku_reserve.prod_id,
                                     r_msku_reserve.cust_pref_vendor,
                                     '*',
                                     pl_putaway_utilities.ADD_NO_INV,
                                     i_sn_number,
                                     ln_aging_days,
                                     lv_clam_bed_trk,
                                     lt_item_info_rec,
                                     lt_work_var_rec);

                    --reset the global variable
                   pl_log.g_program_name     := 'PL_MSKU';
                  pl_log.ins_msg('WARN',lv_pname,'TABLE= none KEY = '
                                       ||ltbl_parent_pallet_id(ln_counter)
                                       ||'MESSAGE= no reserve open slot found by'
                                       ||' f_find_reserve_slot_for_msku for'
                                       ||'putaway hence  all the child pallets '
                                       ||'remaining on this MSKU'
                                       ||'pallet '||ltbl_parent_pallet_id(ln_counter)
                                       ||' HAVE BEEN *ed out',NULL,NULL);

               ELSIF   lb_reserve_putaway_status = TRUE THEN

               pl_putaway_utilities.p_insert_table
                              ( r_msku_reserve.prod_id,
                                r_msku_reserve.cust_pref_vendor,
                                lv_dest_loc,
                                pl_putaway_utilities.ADD_RESERVE,
                                i_sn_number,
                                ln_aging_days,
                                lv_clam_bed_trk,
                                lt_item_info_rec,
                                lt_work_var_rec);

              --reset the global variable
               pl_log.g_program_name     := 'PL_MSKU';

               END IF;
          END LOOP;
       END IF;
   END IF;

   END LOOP;

   SELECT COUNT(*)
      INTO ln_pallets_putaway
      FROM putawaylst
      WHERE sn_no = i_sn_number
      AND NVL(dest_loc,'*') <> '*';

      SELECT COUNT(*)
      INTO ln_pallets_total
      FROM erd_lpn
      WHERE sn_no = i_sn_number;

   IF ln_pallets_putaway = ln_pallets_total THEN
   pl_log.ins_msg('INFO',lv_pname,'TABLE= none KEY = '
                                  || i_sn_number
                                  ||'MESSAGE= all pallets of '
                                  ||'SN_NO'
                                  ||i_sn_number
                                  ||'were putaway successfully',
                                  NULL,NULL);
   ELSE
   pl_log.ins_msg('INFO',lv_pname,'TABLE= none KEY = '
                                  || i_sn_number
                                  ||'MESSAGE= all pallets of '
                                  ||'SN_NO'
                                  ||i_sn_number
                                  ||'were not putaway successfully',
                                  NULL,NULL);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
   o_error := TRUE;

      pl_putaway_utilities.gv_crt_message :=
                          RPAD('ERROR:Putaway cannot be processed ', 80)
                          || ' REASON: ERROR IN : '
                          || pl_putaway_utilities.gv_program_name
                          || ' ,MESSAGE : '
                          || pl_putaway_utilities.gv_crt_message
                          || sqlcode || sqlerrm;

   o_crt_message := pl_putaway_utilities.gv_crt_message;
  ROLLBACK;
END p_assign_msku_putaway_slots;
------------------------------------------------------------------------------
/*-----------------------------------------------------------------------
   -- Function:
   --    p_assign_home_slot_msku
   --
   -- Description:
   --   This procedure tries to putaway child pallets of slotted items
   --   on a MSKU pallets to there respective home locations.It doesn't
   --   return a status .whether a child pallet is putaway or not by this
   --   function. It can be known only after all the child pallets of
   --   the respective MSKU pallet have been processed and entries created
   --   in putawaylst table
   --
   -- Parameters:
   --             i_pallet_id        a child pallet id to be putaway
   --             i_parent_pallet_id pallet id of MSKU pallet
   --             i_sn_number        Shipment number
   --             i_prod_id           product_id of the child pallet
   --             i_cpv               customer preferred vendor
   --             io_work_var_rec     just for compliance with the existing reused code
   --             i_item_info_rec     all details pertaining to the product
   --                                 are in this structure
   --
   -- Called From p_assign_msku_putaway_slots
   --
   -- Exceptions raised none
   --
   ---------------------------------------------------------------------*/
PROCEDURE p_assign_home_slot_msku
               (i_pallet_id        IN     erd_lpn.pallet_id%TYPE,
                i_parent_pallet_id IN     erd_lpn.parent_pallet_id%TYPE,
                i_erm_line_id      IN     erd_lpn.erm_line_id%TYPE,
                i_sn_number        IN     erd_lpn.sn_no%TYPE,
                i_prod_id          IN     erd_lpn.prod_id%TYPE,
                i_cpv              IN     erd_lpn.cust_pref_vendor%TYPE,
                io_work_var_rec    IN OUT pl_putaway_utilities.t_work_var,
                i_item_info_rec    IN     pl_putaway_utilities.t_item_related_info,
                i_aging_days       IN     aging_items.aging_days%TYPE,
                i_clam_bed_trk     IN     sys_config.config_flag_val%TYPE)
IS
lv_putaway_dimension sys_config.config_flag_val%TYPE :='   ';
ln_space_for_cases NUMBER :=0;
ln_inv_exists NUMBER := 0;
lt_logi_loc loc.logi_loc%TYPE := '   ';
lv_pname VARCHAR2(50);
ln_count NUMBER := 0;
lv_reserve_exists varchar2(1);
BEGIN
   pl_log.g_program_name     := 'PL_MSKU';
   lv_pname                  :='p_assign_home_slot_msku';
   --for CRT error reporting
   pl_putaway_utilities.gv_program_name := lv_pname;
   BEGIN
      SELECT (qoh + qty_planned),
             l.logi_loc
      INTO ln_inv_exists,
           lt_logi_loc
      FROM inv i,loc l
      WHERE l.logi_loc = i.plogi_loc
      AND i.prod_id = i_prod_id
      AND i.cust_pref_vendor = i_cpv
      AND l.prod_id = i_prod_id
      AND l.cust_pref_vendor = i_cpv
      AND l.status = 'AVL'
      AND l.perm = 'Y'
      AND l.uom in(0,2)
      AND l.rank = 1;
   EXCEPTION
   WHEN NO_DATA_FOUND THEN
         pl_log.ins_msg('INFO',lv_pname,'SN =' ||i_sn_number
                           || ' ORACLE unable to find home slot ' ||
                           ' inventory record for product.'
                           || i_prod_id || 'and cpv '
                           || i_cpv,NULL,SQLCODE);
         BEGIN
            BEGIN
               SELECT logi_loc
               INTO lt_logi_loc
               FROM loc
               WHERE prod_id = i_prod_id
               AND cust_pref_vendor = i_cpv
               AND perm = 'Y'
               AND status = 'AVL'
               AND rank = 1;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
               pl_log.ins_msg('WARN',lv_pname,'SN =' ||i_sn_number
                                          || ' TABLE = loc ORACLE unable'
                                          ||  'to find home slot '
                                          ||' for product.'|| i_prod_id
                                          || 'and cpv ' || i_cpv,
                                          NULL,SQLCODE);
               pl_putaway_utilities.gv_crt_message :=
                              RPAD(pl_putaway_utilities.gv_crt_message,80)
                              || 'SN =' ||i_sn_number
                              || ' TABLE = loc ORACLE unable'
                              || ' to find home slot '
                              || ' for product ' || i_prod_id
                              || ' and cpv ' || i_cpv
                              || ' - sqlcode= ' ||SQLCODE;

               RAISE;
            WHEN OTHERS THEN
               pl_log.ins_msg('WARN',lv_pname,'SN =' ||i_sn_number
                                          || ' TABLE = loc KEY='||
                                          i_prod_id || ',' || i_cpv
                                          || 'ACTION = '
                                          || 'SELECT MESSAGE = ORACLE '
                                          || 'unable to select from loc'
                                          || 'table ',
                                          SQLCODE, SQLERRM);
               pl_putaway_utilities.gv_crt_message :=
                              RPAD(pl_putaway_utilities.gv_crt_message,80)
                              || 'SN=' || i_sn_number
                              || ' TABLE = loc KEY='
                              || i_prod_id || ',' || i_cpv
                              || 'ACTION='
                              || 'SELECT MESSAGE=ORACLE '
                              || 'unable to select from loc'
                              || ' table '
                              || ' - sqlcode= ' ||SQLCODE;
              RAISE;
            END;
               INSERT INTO inv ( prod_id,
                                 inv_date,
                                 logi_loc,
                                 plogi_loc,  -- Add prod to inv
                                 qoh,
                                 qty_alloc,
                                 qty_planned,
                                 min_qty, -- if it doesnt exist
                                 status,
                                 abc,
                                 abc_gen_date,
                                 lst_cycle_date,
                                 cust_pref_vendor,
                                 exp_date,
                                 inv_uom)
                        VALUES ( i_prod_id,
                                 SYSDATE,
                                 lt_logi_loc,
                                 lt_logi_loc,
                                 0, 0, 0, 0,
                                 'AVL', 'A',
                                 SYSDATE,
                                 SYSDATE,
                                 i_cpv,
                                 TRUNC(SYSDATE),
                                 0);
               ln_inv_exists := 0;
               io_work_var_rec.b_first_home_assign  := TRUE;


               pl_log.ins_msg('WARN',lv_pname,'SN =' ||i_sn_number
                             || ' ORACLE Inserted inv record for home slot for item.'
                             || i_prod_id || 'and cpv '
                             || i_cpv,NULL,SQLCODE);
         EXCEPTION
         WHEN  OTHERS THEN
            pl_log.ins_msg('WARN',lv_pname,'SN =' ||i_sn_number
            || ' Insertion into INVENTORY failed',NULL,SQLCODE);
            pl_putaway_utilities.gv_crt_message :=
                           RPAD(pl_putaway_utilities.gv_crt_message,80)
                           ||'SN =' ||i_sn_number
                           || ' Insertion into INVENTORY failed'
                           ||' - sqlcode= ' ||SQLCODE;
              RAISE;
         END;/* Inventory insertion*/
   WHEN OTHERS THEN
      pl_log.ins_msg('WARN',lv_pname,'SN ='  ||i_sn_number
                                             || ' TABLE = loc,inv KEY='||
                                             i_prod_id || ',' || i_cpv
                                             ||'ACTION = '
                                             ||'SELECT MESSAGE = ORACLE '
                                             ||'select failed',
                                             NULL,SQLCODE);
      pl_putaway_utilities.gv_crt_message :=
                        RPAD(pl_putaway_utilities.gv_crt_message,80)
                        ||'SN ='  ||i_sn_number
                        || ' TABLE = loc,inv KEY='
                        || i_prod_id || ',' || i_cpv
                        ||'ACTION = '
                        ||'SELECT MESSAGE = ORACLE '
                        ||'select failed'
                        ||' - sqlcode= ' ||SQLCODE;
      RAISE;
   END;

   BEGIN
      /*SELECT count(*)
      INTO ln_count
      FROM putawaylst p
      WHERE p.parent_pallet_id = i_parent_pallet_id
      AND p.prod_id = i_prod_id
      AND p.cust_pref_vendor = i_cpv
      AND (((i_item_info_rec.v_fifo_trk = 'S'
             OR i_item_info_rec.v_fifo_trk = 'A')
            AND TRUNC(p.exp_date) = TRUNC(io_work_var_rec.v_exp_date))
            OR (i_item_info_rec.v_lot_trk = 'Y'
                AND p.lot_id = io_work_var_rec.v_lot_id)
            OR (i_item_info_rec.n_stackable = 0))

      AND p.dest_loc = lt_logi_loc;*/

     /* When this function will be called for the very first time for each
        product in MSKU putawaylst entry won't be there so ln_count will be
        0 so all the validations will be performed.Once putawaylst is build
        for one child lp, for all other child LPs
    of the same product with matching details (like lot_id, fifo_trk,
        exp_date) on the same MSKU, all the validations need not be performed
        again.  It will be putaway based on Max qty flag or cube/height
        availability.
     */

      SELECT count(*)
            INTO ln_count
            FROM putawaylst p
            WHERE p.parent_pallet_id = i_parent_pallet_id
            AND p.prod_id = i_prod_id
            AND p.cust_pref_vendor = i_cpv
            AND ( (i_item_info_rec.v_fifo_trk = 'A'
                   AND i_item_info_rec.v_lot_trk <> 'Y'
                   AND TRUNC(p.exp_date) = TRUNC(io_work_var_rec.v_exp_date)
                  )
               OR (i_item_info_rec.v_lot_trk = 'Y'
                   AND i_item_info_rec.v_fifo_trk <> 'A'
                   AND p.lot_id = io_work_var_rec.v_lot_id
                  )
               OR (i_item_info_rec.v_lot_trk = 'Y'
                   AND i_item_info_rec.v_fifo_trk = 'A'
                   AND TRUNC(p.exp_date) = TRUNC(io_work_var_rec.v_exp_date)
                   AND p.lot_id = io_work_var_rec.v_lot_id
                  ))
            AND p.dest_loc = lt_logi_loc;
   EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN;
   WHEN OTHERS THEN
      pl_log.ins_msg('WARN',lv_pname,'SN ='  ||i_sn_number
                                             || ' TABLE = putawaylst KEY=['
                                             || i_parent_pallet_id
                                             || '],['
                                             || i_prod_id
                                             || i_cpv
                                             || '],['
                                             || lt_logi_loc
                                             || ']'
                                             ||'ACTION ='
                                             ||'SELECT MESSAGE = ORACLE '
                                             ||'select failed',
                                             NULL,SQLCODE);

      pl_putaway_utilities.gv_crt_message :=
                                 RPAD(pl_putaway_utilities.gv_crt_message,80)
                                          ||'SN =' ||i_sn_number
                                          || ' TABLE = putawaylst KEY=['
                                          || i_parent_pallet_id
                                          || '],['
                                          || i_prod_id
                                          || i_cpv
                                          || '],['
                                          || lt_logi_loc
                                          || ']'
                                          ||'ACTION ='
                                          ||'SELECT MESSAGE = ORACLE '
                                          ||'select failed'
                                          ||' - sqlcode= ' ||SQLCODE;
      RAISE;
   END;

   IF i_item_info_rec.v_fifo_trk = 'S'  OR i_item_info_rec.v_fifo_trk = 'A'  THEN
      lv_reserve_exists := 'N';
      BEGIN
         SELECT 'Y' into lv_reserve_exists
         FROM inv
         WHERE logi_loc <> plogi_loc
         AND prod_id = i_prod_id
         AND ROWNUM = 1;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
      lv_reserve_exists := 'N';
      WHEN OTHERS THEN
         pl_log.ins_msg('WARN',lv_pname,'SN ='  ||i_sn_number
                                                      || ' TABLE = inv KEY=['
                                                      || i_prod_id
                                                      || '],['
                                                      || i_cpv
                                                      || ']'
                                                      ||'ACTION ='
                                                      ||'SELECT MESSAGE = ORACLE '
                                                      ||'select failed',
                                                      NULL,SQLCODE);

         pl_putaway_utilities.gv_crt_message :=
                                    RPAD(pl_putaway_utilities.gv_crt_message,80)
                                             ||'SN =' ||i_sn_number
                                             || ' TABLE = inv KEY=['
                                             || i_prod_id
                                             || '],['
                                             || i_cpv
                                             || ']'
                                             ||'ACTION ='
                                             ||'SELECT MESSAGE = ORACLE '
                                             ||'select failed'
                                             ||' - sqlcode= ' ||SQLCODE;
         RAISE;
      END;
   END IF;

   IF ln_count > 0 THEN
   /*one child with matching details has
     been putaway so no need to validate similar childs*/
      NULL;
   /*The elsif condition is applicable for the first child pallet of its kind.
     Remaining matching child pallets on the same MSKU will have ln_count > 0*/
   ELSIF ((i_item_info_rec.v_fifo_trk = 'S'
             AND (lv_reserve_exists = 'Y' OR ln_inv_exists > 0 ))
         OR (i_item_info_rec.v_fifo_trk = 'A'
             AND (lv_reserve_exists = 'Y' OR ln_inv_exists > 0 ))
         OR (i_item_info_rec.v_lot_trk = 'Y' AND ln_inv_exists > 0)
         /*OR (i_item_info_rec.n_stackable = 0  AND  ln_inv_exists > 0 )*/)
   THEN


      pl_log.ins_msg('INFO',lv_pname,'SN ='||i_sn_number
                                           || ' TABLE = none KEY='||
                                            i_prod_id || ',' || i_cpv
                                           ||'MESSAGE = item is FIFO'
                                           ||' tracked, Lot tracked or'
                                           ||'has stackability = 0 and'
                                           ||'inventory already exists'
                                           ||'in home slot, hence can'
                                           ||'not putaway to home slot'
                                           ,NULL,NULL);
      RETURN;
   END IF;

   --get the putaway dimension syspar
   lv_putaway_dimension := pl_common.f_get_syspar('PUTAWAY_DIMENSION');

   --reset the global variable
   pl_log.g_program_name     := 'PL_MSKU';

   pl_log.ins_msg('INFO',lv_pname,'Max qty Flag is ' || i_item_info_rec.v_threshold_flag,NULL,NULL);
/*acpppp<-Threshold flag should be checked even for MSKU pallet*/
IF i_item_info_rec.v_threshold_flag = 'Y' AND
   i_item_info_rec.n_max_qty IS NOT NULL THEN

    IF i_item_info_rec.n_max_qty
      - (ln_inv_exists/i_item_info_rec.n_spc) >= io_work_var_rec.n_each_pallet_qty THEN

           IF ln_inv_exists = 0 THEN
           io_work_var_rec.b_first_home_assign  := TRUE;
           ELSE
           io_work_var_rec.b_first_home_assign  := FALSE;
           END IF;
           io_work_var_rec.n_erm_line_id := i_erm_line_id;
           io_work_var_rec.v_pallet_id := i_pallet_id;

          pl_putaway_utilities.p_insert_table
                           (       i_prod_id,
                                   i_cpv,
                                   lt_logi_loc,
                                   pl_putaway_utilities.ADD_HOME,
                                   i_sn_number,
                                   i_aging_days,
                                   i_clam_bed_trk,
                                   i_item_info_rec,
                                   io_work_var_rec);
              --reset the global variable
          pl_log.g_program_name     := 'PL_MSKU';

      pl_log.ins_msg('INFO',lv_pname,'SN ='  ||i_sn_number
                                             || ' TABLE = putawaylst,inv'
                                             ||'KEY='|| i_pallet_id||','
                                             ||i_prod_id || ','
                                             || i_cpv||'ACTION = '
                                             ||'INSERT/UPDATE MESSAGE ='
                                             ||'pallet '|| i_pallet_id
                                             || ' successfully putaway to'
                                             || lt_logi_loc ||'slot',
                                             NULL,NULL);
   END IF;
ELSE
   IF lv_putaway_dimension ='I' THEN
     BEGIN
        SELECT (((NVL(l.slot_height,0)/NVL(pm.case_height,1))
                *NVL(pm.ti,0)*NVL(l.width_positions,0)*NVL(s.deep_positions,0))
               -((i.qoh + i.qty_planned)/pm.spc))
        INTO ln_space_for_cases
        FROM loc l, inv i, pm, slot_type s
        WHERE l.logi_loc = i.plogi_loc
        AND l.slot_type = s.slot_type
        AND i.prod_id = pm.prod_id
        AND l.perm = 'Y'
        AND l.status = 'AVL'
        AND l.uom in(0,2)
        AND l.rank = 1
        AND i.prod_id = i_prod_id
        AND i.cust_pref_vendor = i_cpv;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('DEBUG',lv_pname,'SN ='  ||i_sn_number
                                                     || ' TABLE = loc,pm,'
                                                     ||'inv,slot_type'
                                                     ||'KEY='||i_prod_id
                                                     || ','|| i_cpv
                                                     ||'ACTION = '
                                                     ||'SELECT MESSAGE ='
                                                     ||'invalid prod id '
                                                     ||'or unslotted item',
                                                     NULL,SQLCODE);
         pl_putaway_utilities.gv_crt_message :=
                               RPAD(pl_putaway_utilities.gv_crt_message,80)
                                         ||'SN ='
                                         ||i_sn_number
                                         || ' TABLE = loc,pm,'
                                         ||'inv,slot_type'
                                         ||'KEY='||i_prod_id
                                         || ','|| i_cpv
                                         ||'ACTION = '
                                         ||'SELECT MESSAGE ='
                                         ||'invalid prod id '
                                         ||'or unslotted item'
                                         ||' - sqlcode= '
                                         ||sqlcode;
        RAISE;
     WHEN OTHERS THEN

        pl_log.ins_msg('DEBUG',lv_pname,'SN ='   ||i_sn_number
                                                 || ' TABLE = loc,pm,'
                                                 ||'inv,slot_type'
                                                 ||'KEY='||i_prod_id
                                                 || ','|| i_cpv
                                                 ||'ACTION = '
                                                 ||'SELECT MESSAGE ='
                                                 ||'Unexpected Error while'
                                                 ||'checking for space '
                                                 ||'availability for child'
                                                 ||'pallet',
                                                 NULL,SQLCODE);
        pl_putaway_utilities.gv_crt_message :=
                                       RPAD(pl_putaway_utilities.gv_crt_message,80)
                                        ||'SN ='||i_sn_number
                                        || ' TABLE = loc,pm,'
                                        ||'inv,slot_type'
                                        ||'KEY='||i_prod_id
                                        || ','|| i_cpv
                                        ||'ACTION = '
                                        ||'SELECT MESSAGE ='
                                        ||'Unexpected Error while'
                                        ||'checking for space '
                                        ||'availability for child'
                                        ||'pallet'
                                        ||' - sqlcode= '
                                        ||sqlcode;
        RAISE;
     END;

      /* 11/21/06 BEG MOD Infosys - MSKU pallets can have qty > 1.So we need to check with quantity */
      IF ln_space_for_cases >=  io_work_var_rec.n_each_pallet_qty THEN
      /* 11/21/06 END MOD Infosys - MSKU pallets can have qty > 1.So we need to check with quantity */

         IF ln_inv_exists = 0 THEN
            io_work_var_rec.b_first_home_assign  := TRUE;
         ELSE
            io_work_var_rec.b_first_home_assign  := FALSE;
         END IF;
         io_work_var_rec.n_erm_line_id := i_erm_line_id;
         io_work_var_rec.v_pallet_id := i_pallet_id;

         pl_putaway_utilities.p_insert_table
                             ( i_prod_id,
                                i_cpv,
                                lt_logi_loc,
                                pl_putaway_utilities.ADD_HOME,
                                i_sn_number,
                                i_aging_days,
                                i_clam_bed_trk,
                                i_item_info_rec,
                                io_work_var_rec);
                        --reset the global variable
         pl_log.g_program_name     := 'PL_MSKU';

         pl_log.ins_msg('INFO',lv_pname,'SN ='  ||i_sn_number
                                          || ' TABLE = putawaylst,inv'
                                          ||'KEY='||i_pallet_id||','
                                          ||i_prod_id || ','
                                          || i_cpv||'ACTION = '
                                          ||'INSERT/UPDATE MESSAGE ='
                                          ||'pallet '|| i_pallet_id
                                          || ' successfully putaway to'
                                          || lt_logi_loc ||'slot',
                                       NULL,NULL);
      END IF;
   ELSIF lv_putaway_dimension = 'C' THEN
      BEGIN
           SELECT (NVL(l.cube,0)
                  -(((i.qoh + i.qty_planned)/pm.spc)*pm.case_cube))
           INTO ln_space_for_cases
           FROM loc l, inv i, pm, slot_type s
           WHERE l.logi_loc = i.plogi_loc
           AND l.slot_type = s.slot_type
           AND i.prod_id = pm.prod_id
           AND l.perm = 'Y'
           AND l.status = 'AVL'
           AND l.uom in(0,2)
           AND l.rank = 1
           AND i.prod_id = i_prod_id
           AND i.cust_pref_vendor = i_cpv;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
         pl_log.ins_msg('DEBUG',lv_pname,'SN ='   ||i_sn_number
                                                  || ' TABLE = loc,pm,'
                                                  ||'inv,slot_type'
                                                  ||'KEY='||i_prod_id
                                                  || ','|| i_cpv
                                                  ||'ACTION = '
                                                  ||'SELECT MESSAGE ='
                                                  ||'invalid prod id '
                                                  ||'or unslotted item',
                                                  NULL,SQLCODE);
         pl_putaway_utilities.gv_crt_message :=
                                 RPAD(pl_putaway_utilities.gv_crt_message,80)
                                   ||'SN ='   ||i_sn_number
                                   || ' TABLE = loc,pm,'
                                   ||'inv,slot_type'
                                   ||'KEY='||i_prod_id
                                   || ','|| i_cpv
                                   ||'ACTION = '
                                   ||'SELECT MESSAGE ='
                                   ||'invalid prod id '
                                   ||'or unslotted item'
                                   ||' - sqlcode= '
                                   ||sqlcode;
         RAISE;
      WHEN OTHERS THEN
         pl_log.ins_msg('DEBUG',lv_pname,'SN ='||i_sn_number
                                              || ' TABLE = loc,pm,'
                                              ||'inv,slot_type'
                                              ||'KEY='||i_prod_id
                                              || ','|| i_cpv
                                              ||'ACTION = '
                                              ||'SELECT MESSAGE ='
                                              ||'Unexpected Error while'
                                              ||'checking for space '
                                              ||'availability for child'
                                              ||'pallet',
                                              NULL,SQLCODE);
         pl_putaway_utilities.gv_crt_message :=
                              RPAD(pl_putaway_utilities.gv_crt_message,80)
                                                 ||'SN ='||i_sn_number
                                                 || ' TABLE = loc,pm,'
                                                 ||'inv,slot_type'
                                                 ||'KEY='||i_prod_id
                                                 || ','|| i_cpv
                                                 ||'ACTION = '
                                                 ||'SELECT MESSAGE ='
                                                 ||'Unexpected Error while'
                                                 ||'checking for space '
                                                 ||'availability for child'
                                                 ||'pallet'
                                                 ||' - sqlcode= '
                                                 ||SQLCODE;
         RAISE;
      END;

      /* 11/21/06 BEG MOD Infosys - MSKU pallets can have qty > 1.So we need to multiply with quantity */
      IF ln_space_for_cases >= (i_item_info_rec.n_case_cube * io_work_var_rec.n_each_pallet_qty) THEN
      /* 11/21/06 END MOD Infosys - MSKU pallets can have qty > 1.So we need to multiply with quantity */

         IF ln_inv_exists = 0 THEN
            io_work_var_rec.b_first_home_assign  := TRUE;
         ELSE
            io_work_var_rec.b_first_home_assign  := FALSE;
         END IF;
         io_work_var_rec.n_erm_line_id := i_erm_line_id;
         io_work_var_rec.v_pallet_id := i_pallet_id;

         pl_putaway_utilities.p_insert_table
                             ( i_prod_id,
                                i_cpv,
                                lt_logi_loc,
                                pl_putaway_utilities.ADD_HOME,
                                i_sn_number,
                                i_aging_days,
                                i_clam_bed_trk,
                                i_item_info_rec,
                                io_work_var_rec);
                        --reset the global variable
         pl_log.g_program_name     := 'PL_MSKU';

         pl_log.ins_msg('INFO',lv_pname,'SN ='  ||i_sn_number
                                          || ' TABLE = putawaylst,inv'
                                          ||'KEY='||i_pallet_id||','
                                          ||i_prod_id || ','
                                          || i_cpv||'ACTION = '
                                          ||'INSERT/UPDATE MESSAGE ='
                                          ||'pallet '|| i_pallet_id
                                          || ' successfully putaway to'
                                          || lt_logi_loc ||'slot',
                                       NULL,NULL);
      END IF;
   ELSE
   pl_log.ins_msg('INFO',lv_pname,'SN ='   ||i_sn_number
                                                    || ' TABLE = sys_config'
                                                    ||'KEY='||lv_putaway_dimension
                                                    ||'MESSAGE =The value '
                                                    ||'of config_flag_val '
                                                    ||'is improper for '
                                                    ||'CONFIG_FLAG_NAME = '
                                                    ||'''PUTAWAY_DIMENSION''',

                                                 NULL,NULL);
   END IF;
END IF;
EXCEPTION
WHEN OTHERS THEN
   RAISE;
END p_assign_home_slot_msku;
---------------------------------------------------------------------------


/*-----------------------------------------------------------------------
-- Function:
--    f_find_reserve_slot_for_msku
--
-- Description:
--    This function is just a wrap of p_find_reserve_slot_for_msku.
--    It is called by MAKU putaway process. The reason for such change
--    is we won't touch any existing call interface of function
--    f_find_reserve_slot_for_msku.
-- Parameters:
--    i_parent_pallet_id      - Pallet id of the MSKU pallet.
--    i_sn_number             - Shipment number.
--    putaway_repl_indicator  - Indicates whether called by putaway or
--                              replenishment functionality.
--    o_dest_loc              - Location identified (out parameter).
-------------------------------------------------------------------------*/

FUNCTION f_find_reserve_slot_for_msku
           (i_parent_pallet_id     IN erd_lpn.parent_pallet_id%TYPE,
            i_sn_number            IN erd_lpn.sn_no%TYPE,
            putaway_repl_indicator IN VARCHAR2,
            o_dest_loc             OUT loc.logi_loc%TYPE)
RETURN BOOLEAN
IS
   lv_message            VARCHAR2(512);  -- Message buffer
   lt_rsv_loc         pl_msku.t_phys_loc;
   lb_status             BOOLEAN := FALSE;
   lv_fname              VARCHAR2(50);
   ln_num_of_loc     NUMBER := 1;
BEGIN
   pl_log.g_program_name     := 'PL_MSKU';
   lv_fname                  :='f_find_reserve_slot_for_msku(transfer)';
   --for CRT error reporting
   pl_putaway_utilities.gv_program_name := lv_fname;

   p_find_reserve_slot_for_msku(i_parent_pallet_id,
                           i_sn_number,
                       putaway_repl_indicator,
                    ln_num_of_loc,
                    lt_rsv_loc);
   o_dest_loc := lt_rsv_loc(ln_num_of_loc);
   IF o_dest_loc <> '*' THEN
      lb_status := TRUE;
   END IF;
   RETURN lb_status;
END f_find_reserve_slot_for_msku;

/*-----------------------------------------------------------------------
-- PROCEDURE:
--    p_find_reserve_slot_for_msku
--
-- Description:
--    This method tries to find reserve open slots for a MSKU
--    pallet and if successful then returns a success status
--    and location id of the location identified as an out
--    parameter.Else,it returns a false status.  This
--    function can be used both during putaway and
--    replenishment.
--
--    The cube is used when checking if the MSKU will fit in the reserve slot
--    regardless of the setting of the putaway dimension syspar because it
--    is unknown how the child LPs are stacked on the pallet making it
--    difficult to use inches.
--
--    An available slot is checked going in archor item order.
--    Meaning the anchor item is checked first and if no available slot
--    found then the next item which would classify as the anchor item
--    is checked and so on until an availbe slot is found or all the
--    items have been checked.  The item will affect what zone is checked
--    and what pallet types are checked.
--
-- Parameters:
--    i_parent_pallet_id      - Pallet id of the MSKU pallet.
--    i_sn_number             - Shipment number.
--    putaway_repl_indicator  - Indicates whether called by putaway or
--                              replenishment functionality.
--    i_num_of_loc            - number of locations requested(in/out).
--    o_avl_locations         - available locations suggested(out).
-- Called From p_assign_msku_putaway_slots
--
-- Exceptions raised none
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/07/04 prpbcb   Modified to use the MSKU pallet type cross
--                      reference.  A MSKU can have different pallet
--                      types in ERD_LPN.  The pallet type of the physical
--                      pallet is LW.  The cross reference is used to
--                      map the MSKU pallet type to either LW or FW.
--                      The business rule is the MSKU will always be on
--                      a LW pallet so the putaway slot needs to be
--                      either LW or FW.
--
--                      Removed parameter i_pallet_type because the pallet
--                      type is now determined by this procedure.
--
--                      Modified to use new column
--                      swms_areas.dflt_msku_put_zone which is used to
--                      specify the final zone to look for an available
--                      slot.  This column was created to provide the users
--                      a way to specify a zone with LW and/or FW pallet
--                      for the situation there is a MSKU with items in
--                      zones that do not have LW or FW pallet types.
--
--                      Added variable ln_msku_reserve_cube and put in
--                      call to procedure p_find_anchor_pick_items() to get
--                      populated.  This is the cube of the child pallets on
--                      the MSKU plus the skid cube going to reserve.
--
--                      Add condition in the selects looking for reserve slot
--                      that the reserve slot cube has to be >= MSKU cube.
--
--                      Added variable lv_pallet_type and populated from
--                      the pallet type for the item as sent on the SN.
--
--                      Added call to procedure
--                      pl_putaway_utilities.p_get_erm_info() to get item info
--                      as it is in the SN.  Specifically we want the pallet
--                      type.
--
--                      Note that no slot will be found if none of the items
--                      on the MSKU is a LW and there is no cross reference
--                      mapping to LW or FW.
--   12/15/04 prppxx    Modify to use cursor to return loc list for transfer.
--            Return one location for putaway.
---------------------------------------------------------------------*/
PROCEDURE p_find_reserve_slot_for_msku
           (i_parent_pallet_id     IN erd_lpn.parent_pallet_id%TYPE,
            i_sn_number            IN erd_lpn.sn_no%TYPE,
            putaway_repl_indicator IN VARCHAR2,
        io_num_of_req_loc       IN OUT NUMBER,
            o_avl_locations        OUT pl_msku.t_phys_loc)
IS
   lv_message            VARCHAR2(512);  -- Message buffer

   tbl_items             t_items;
   lv_home_slot          loc.logi_loc%TYPE;
   lv_zone_id            zone.zone_id%TYPE;
   ln_put_aisle          loc.put_aisle%TYPE;
   ln_put_slot           loc.put_slot%TYPE;
   ln_put_level          loc.put_level%TYPE;
   lv_fname              VARCHAR2(50);
   lv_pallet_type        pallet_type.pallet_type%TYPE;  -- Pallet type of the
                                            -- child LP on the SN.
   lb_location_found     BOOLEAN;  -- Indicates if a location found in the
                                   -- next zones.
   lb_record_found       BOOLEAN;  -- Used to designate whan a record was found
                                   -- or not found.
   lb_status             BOOLEAN := FALSE;
   ln_next_zones         PLS_INTEGER := 0;
   ln_msku_reserve_cube  NUMBER;  -- Cube of the child LP's plus the skid
                                  -- cube going to the reserve slot.
   ln_num_recs         NUMBER := 1;
   o_dest_loc            loc.logi_loc%TYPE;
   lt_item_info_rec      pl_putaway_utilities.t_item_related_info;

   -- This cursor selects the next zones and also selects the default MSKU
   -- PUT zone.
   --
   -- 12/08/04 During processing a check will be made to see if the zone is
   -- null.  If null then this will be the default MSKU PUT zone where the user
   -- has not entered a zone for the area.  A "INFO" message will be written
   -- and the zone skipped since it is null.
   --
   -- 12/08/04 The "what_kind_of_zone" is used to determine when to stop
   -- looking at the next zones to handle the situation when a zone has 5
   -- next zones and the maximum number of next zone to check is 3.  The
   -- default MSKU put zone will be the 6th zone to check so the 4th and 5th
   -- next zones need to be skipped.
   CURSOR c_next_zones (cp_zone       zone.zone_id%TYPE,
                        cp_area_code  swms_areas.area_code%TYPE) IS
      SELECT next_zone_id       zone_id,
             'NEXTZONE'         what_kind_of_zone,
             sort               sort
        FROM next_zones
       WHERE zone_id = cp_zone
       UNION
      SELECT dflt_msku_put_zone zone_id,
             'DFLTZONE'         what_kind_of_zone,
             999999999          sort  -- We want the default MSKU
        FROM swms_areas               -- PUT zone to be checked last.
       WHERE area_code = cp_area_code
       ORDER BY sort ASC;

   -- prppxx D#11812
   -- This cursor is used to find non-deep reserve location for MSKU pallet
   -- during transfer.
   CURSOR c_non_deep_rsv_slot (cp_zone_id zone.zone_id%TYPE,
                               cp_pallet_type loc.pallet_type%TYPE,
                               cp_put_aisle loc.put_aisle%TYPE,
                               cp_put_slot loc.put_slot%TYPE,
                               cp_put_level loc.put_level%TYPE,
                               cp_msku_srv_cube loc.cube%TYPE) IS
       SELECT l.logi_loc
         FROM loc l,lzone lz, zone z, slot_type s
        WHERE l.perm = 'N'
          AND l.status = 'AVL'
          AND (   l.pallet_type = cp_pallet_type
               OR l.pallet_type IN
                      (SELECT mixed_pallet_type
                         FROM msku_pallet_type_mixed
                        WHERE msku_pallet_type = cp_pallet_type)
              )
          AND l.logi_loc           = lz.logi_loc
          AND lz.zone_id           = z.zone_id
          AND z.zone_id            = cp_zone_id
          AND z.zone_type          = 'PUT'
          AND s.slot_type          = l.slot_type
          AND NVL(s.deep_ind, 'N') <> 'Y'
          AND ROUND(l.cube, 2)     >= ROUND(cp_msku_srv_cube, 2)
          AND NOT EXISTS (SELECT 'X'
                            FROM inv
                           WHERE plogi_loc = l.logi_loc)
          ORDER BY ABS(l.put_aisle - cp_put_aisle),
                   ABS(l.put_slot - cp_put_slot),
                   ABS(l.put_level - cp_put_level);

   r_next_zones c_next_zones%ROWTYPE;   -- Next zones record.

BEGIN
   pl_log.g_program_name     := 'PL_MSKU';
   lv_fname                  :='p_find_reserve_slot_for_msku';
   --for CRT error reporting
   pl_putaway_utilities.gv_program_name := lv_fname;

   p_find_anchor_pick_items(i_parent_pallet_id,
                            i_sn_number,
                            putaway_repl_indicator,
                            tbl_items,
                            ln_msku_reserve_cube);

   pl_log.ins_msg('INFO', lv_fname, 'SN=' || i_sn_number ||
                     ' parent LP=' || i_parent_pallet_id ||
                     ' Cube of pallet going to reserve=' ||
                     TO_CHAR(ln_msku_reserve_cube), NULL, NULL);

   IF tbl_items.COUNT = 0 THEN
      pl_log.ins_msg('INFO',lv_fname,'inside p_find_reserve_slot_for_msku SN ='  ||i_sn_number
                                             || ' TABLE = none'
                                             ||'KEY='||i_sn_number||','
                                             ||i_parent_pallet_id || ','
                                             ||'MESSAGE ='
                                             ||'No anchor pick products found'
                                             ||' by'
                                             ||' p_find_anchor_pick_items for'
                                             || ' SN '||i_sn_number
                                             ||' MSKU pallet id '
                                             ||i_parent_pallet_id,
                                             NULL,NULL);

     lb_status := FALSE;
   ELSIF putaway_repl_indicator = 'IP' THEN

      -- Loop through the items on the SN that are have child LP's not
      -- going to a pick slot or floating slot.  A reserve slot needs to
      -- be found for them.  Once a reserve slot is found the loop exits.
      -- The ordering is by the most favorable anchor item to the least
      -- favorable anchor item.  It is possible no reserve slot is found
      -- based on an item because item info such as put zone and pallet
      -- type are used in searching for a slot.
      <<outer>>
      FOR i_counter in tbl_items.first .. tbl_items.last LOOP

         pl_putaway_utilities.p_get_item_info(tbl_items(i_counter).prod_id,
                                              tbl_items(i_counter).cpv,
                                              lt_item_info_rec);

         --
         -- Log item info.
         --
         log_item_info(lt_item_info_rec);

         -- Get item info as it is in the SN.  Specifically we want the
         -- pallet type.
         pl_putaway_utilities.p_get_erm_info(i_sn_number,
                                             tbl_items(i_counter).prod_id,
                                             tbl_items(i_counter).cpv,
                                             lt_item_info_rec);
         -- Assign the pallet type as in came on the SN to a local
         -- variable.  This local variable is used in the remaining statements.
         lv_pallet_type := lt_item_info_rec.v_pallet_type;

         -- Reset the global variable
         pl_log.g_program_name     := 'PL_MSKU';

         BEGIN
            -- Find the rank 1 case home slot and it's zone for the item.
            SELECT l.logi_loc logi_loc,
                   l.put_aisle  put_aisle,
                   l.put_slot put_slot,
                   l.put_level put_level,
                   z.zone_id
              INTO lv_home_slot,
                   ln_put_aisle,
                   ln_put_slot,
                   ln_put_level,
                   lv_zone_id
              FROM loc l,lzone lz, zone z
             WHERE l.prod_id          = tbl_items(i_counter).prod_id
               AND l.cust_pref_vendor = tbl_items(i_counter).cpv
               AND l.logi_loc         = lz.logi_loc
               AND lz.zone_id         = z.zone_id
               AND z.zone_type        = 'PUT'
               AND l.perm             = 'Y'
               AND l.status           = 'AVL'
               AND l.uom              IN (0,2)
               AND l.rank             = 1;

        lb_record_found := TRUE;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
        lb_record_found := FALSE;

            pl_log.ins_msg('INFO',lv_fname,'SN='
                                           ||i_sn_number
                                           || ' TABLE=loc'
                                           ||'KEY='
                                           ||tbl_items(i_counter).prod_id
                                           ||','|| tbl_items(i_counter).cpv
                                           || ','  || lv_pallet_type
                                           ||'ACTION = SELECT '
                                           ||'MESSAGE ='
                                           ||'No home slot found for'
                                           ||' item'
                                           || tbl_items(i_counter).prod_id
                                           ||'pallet type'
                                           || i_parent_pallet_id,
                                           NULL,SQLCODE);

         pl_putaway_utilities.gv_crt_message :=
                              RPAD(pl_putaway_utilities.gv_crt_message,80)
                                                ||'SN ='  ||i_sn_number
                                                || ' TABLE = loc'
                                                ||'KEY='
                                                ||tbl_items(i_counter).prod_id
                                                ||','
                                                || tbl_items(i_counter).cpv
                                                || ','  || lv_pallet_type
                                                ||'ACTION = SELECT '
                                                ||'MESSAGE ='
                                                ||'No home slot found for'
                                                ||' item'
                                                || tbl_items(i_counter).prod_id
                                                ||'pallet type'
                                                || i_parent_pallet_id
                                                ||' - sqlcode= '
                                                ||sqlcode;
            RAISE;
         WHEN OTHERS THEN
            pl_log.ins_msg('INFO',lv_fname,'SN='
                                             ||i_sn_number
                                             || ' TABLE=loc'
                                             ||'KEY='
                                             ||tbl_items(i_counter).prod_id
                                             ||','||tbl_items(i_counter).cpv
                                             || ','  || lv_pallet_type
                                             ||'ACTION=SELECT'
                                             ||' MESSAGE='
                                             ||'Error while selecting'
                                             ||' from loc table',
                                             SQLCODE, SQLERRM);

            pl_putaway_utilities.gv_crt_message :=
                                 RPAD(pl_putaway_utilities.gv_crt_message,80)
                                           || 'SN='  ||i_sn_number
                                           || ' TABLE=loc'
                                           || ' KEY='
                                           || tbl_items(i_counter).prod_id
                                           || ','||tbl_items(i_counter).cpv
                                           || ','  || lv_pallet_type
                                           || ' ACTION=SELECT'
                                           || ' MESSAGE='
                                           || 'Error while selecting'
                                           || ' from loc table'
                                           || ' - sqlcode= '
                                           || sqlcode;
            RAISE;
         END;

         IF (lb_record_found) THEN
            -- Found the home slot for the item.
            -- Look for an open non-deep reserve slot for the MSKU in
            -- the primary PUT zone large enough for the MSKU.
            -- The cubes are rounded to 2 decimal places.

            pl_log.ins_msg('INFO', lv_fname, 'SN=' || i_sn_number ||
                     ' parent LP=' || i_parent_pallet_id ||
                     ' Looking for open slot in zone ' || lv_zone_id || '.',
                     NULL, NULL);
        ln_num_recs := 1;
            BEGIN
               SELECT logi_loc
               INTO o_dest_loc
               FROM
              (SELECT l.logi_loc logi_loc
               FROM loc l,lzone lz, zone z,slot_type s
               WHERE l.perm = 'N'
               AND l.status = 'AVL'
               AND (   l.pallet_type = lv_pallet_type
                    OR l.pallet_type IN
                           (SELECT mixed_pallet_type
                              FROM msku_pallet_type_mixed
                             WHERE msku_pallet_type = lv_pallet_type)
                   )
               AND l.logi_loc           = lz.logi_loc
               AND lz.zone_id           = z.zone_id
               AND z.zone_id            = lv_zone_id
               AND z.zone_type          = 'PUT'
               AND s.slot_type          = l.slot_type
               AND NVL(s.deep_ind,'N')  <> 'Y'
               AND ROUND(l.cube, 2)     >= ROUND(ln_msku_reserve_cube, 2)
               AND NOT EXISTS (SELECT 'X'
                                 FROM inv
                                WHERE plogi_loc = l.logi_loc)
               ORDER BY ABS(l.put_aisle - ln_put_aisle),
                        ABS(l.put_slot - ln_put_slot),
                        ABS(l.put_level - ln_put_level))
               WHERE ROWNUM = 1;

          lb_record_found := TRUE;

            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  lb_record_found := FALSE;

            WHEN OTHERS THEN

            pl_log.ins_msg('INFO', lv_fname, 'SN='|| i_sn_number
                                  || ' TABLE=loc'
                                  || ' KEY='|| lv_pallet_type
                                  || ',' || lv_zone_id
                                  || ' ACTION=SELECT'
                                  || ' MESSAGE='
                                  || 'Error while selecting'
                                  || ' from loc table', SQLCODE, SQLERRM);

            pl_putaway_utilities.gv_crt_message :=
                              RPAD(pl_putaway_utilities.gv_crt_message,80)
                                              || 'SN='|| i_sn_number
                                              || ' TABLE=loc'
                                              || ' KEY=' || lv_pallet_type
                                              || ',' || lv_zone_id
                                              || ' ACTION=SELECT'
                                              || ' MESSAGE='
                                              || 'error while selecting'
                                              || ' from loc table'
                                              || ' - sqlcode= '
                                              || sqlcode;
            RAISE;
            END;

            IF (lb_record_found) THEN
           o_avl_locations(ln_num_recs) := o_dest_loc;
               lb_status := TRUE;
               EXIT;
            ELSE
               -- Did not find a suitable reserve slot in the items
               -- primary PUT zone.  Now look in the next zones and the
               -- default MSKU PUT zone for the area.

               ln_next_zones := 0;
               lb_location_found := FALSE;

               OPEN c_next_zones(lv_zone_id, lt_item_info_rec.v_area);

               LOOP
                  FETCH c_next_zones INTO r_next_zones;
                  EXIT WHEN c_next_zones%NOTFOUND;

                  ln_next_zones := ln_next_zones + 1;

                  IF (    ln_next_zones > lt_item_info_rec.n_num_next_zones
                      AND r_next_zones.what_kind_of_zone = 'NEXTZONE')  THEN
                     -- The maximum number of next zones has been reached.
                     -- Skip over the remaining next zones.
                     NULL;
                  ELSIF (    r_next_zones.what_kind_of_zone = 'DFLTZONE'
                         AND r_next_zones.zone_id IS NULL)  THEN
                     -- The default MSKU put zone for the area is null.
                     -- This is not an error.  Log a message and continue.
                     lv_message := 'SN=' || i_sn_number
                                     || ' TABLE=swms_area'
                                     || ' Area='
                                     || lt_item_info_rec.v_area
                                     || ' Item='
                                     || tbl_items(i_counter).prod_id
                                     || ' CPV='
                                     || tbl_items(i_counter).cpv
              || ' MESSAGE=The default MSKU PUT zone for this area is null.';

                     pl_log.ins_msg('INFO', lv_fname, lv_message, NULL, NULL);

                  ELSE
                     BEGIN
                        -- Look for a slot for the MSKU large enough.
                        -- The cubes are rounded to 2 decimal places.

                        IF (r_next_zones.what_kind_of_zone = 'NEXTZONE') THEN
                           pl_log.ins_msg('INFO', lv_fname,
                             'SN=' || i_sn_number ||
                             ' parent LP=' || i_parent_pallet_id ||
                             ' Looking for open slot in next zone ' ||
                             r_next_zones.zone_id || '.',
                             NULL, NULL);
                        ELSE
                           pl_log.ins_msg('INFO', lv_fname,
                             'SN=' || i_sn_number ||
                             ' parent LP=' || i_parent_pallet_id ||
                             ' Looking for open slot in dflt msku put zone ' ||
                             r_next_zones.zone_id || '.',
                             NULL, NULL);
                        END IF;

                        SELECT logi_loc
                        INTO o_dest_loc
                        FROM
                        (SELECT l.logi_loc  logi_loc

                        FROM loc l,lzone lz, zone z, slot_type s
                        where l.perm = 'N'
                        AND l.status = 'AVL'
                        AND (   l.pallet_type = lv_pallet_type
                             OR l.pallet_type IN
                                   (SELECT mixed_pallet_type
                                      FROM msku_pallet_type_mixed
                                     WHERE msku_pallet_type = lv_pallet_type)
                            )
                        AND l.logi_loc           = lz.logi_loc
            AND lz.zone_id           = z.zone_id
                        AND lz.zone_id           = r_next_zones.zone_id
                        AND z.zone_type          = 'PUT'
                        AND s.slot_type          = l.slot_type
                        AND NVL(s.deep_ind, 'N') <> 'Y'
                     AND ROUND(l.cube, 2)     >= ROUND(ln_msku_reserve_cube, 2)
                        AND NOT EXISTS(SELECT 'X'
                                       FROM inv
                                       WHERE plogi_loc = l.logi_loc)
                        ORDER BY ABS(l.put_aisle - ln_put_aisle),
                                 ABS(l.put_slot - ln_put_slot),
                                 ABS(l.put_level - ln_put_level))
                        WHERE ROWNUM = 1;

            o_avl_locations(ln_num_recs) := o_dest_loc;
                        lb_location_found := TRUE;

                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           lb_record_found := FALSE;
                        WHEN OTHERS THEN

                        pl_log.ins_msg('WARN',lv_fname,'SN='||i_sn_number
                                                     || ' TABLE=loc'
                                                     || ' KEY='
                                                     || lv_pallet_type
                                                     || ','
                                                     || r_next_zones.zone_id
                                                     || 'ACTION=SELECT'
                                                     || ' MESSAGE='
                                                     || 'Error while selecting'
                                                     || ' from loc table',
                                                     SQLCODE, SQLERRM);

                     pl_putaway_utilities.gv_crt_message :=
                                    RPAD(pl_putaway_utilities.gv_crt_message,80)
                                                   ||'SN=' || i_sn_number
                                                   || ' TABLE=loc'
                                                   || ' KEY='
                                                   || lv_pallet_type
                                                   || ','
                                                   || r_next_zones.zone_id
                                                   || 'ACTION=SELECT'
                                                   || ' MESSAGE='
                                                   || 'Error while selecting'
                                                   || ' from loc table'
                                                   || ' - sqlcode= '
                                                   || sqlcode;
                        RAISE;
                     END;
                  END IF;

                  IF (lb_location_found) THEN
                     lb_status := TRUE;
                     EXIT outer ;
                  END IF;

               END LOOP;    -- end next zones loop

               IF (c_next_zones%ISOPEN) THEN
                  CLOSE c_next_zones;
               END IF;

            END IF;
         END IF;
      END LOOP outer;

      -- Close the cursor as it could be open at this point.
      IF (c_next_zones%ISOPEN) THEN
         CLOSE c_next_zones;
      END IF;

   ELSE
      -- Replenishment code
      -- Currently this is not used in replenishment. It is used in transfer
      -- to find available reserve slots for msku pallets. The logic is
      -- similar to finding reserve slots for msku pallets during PO/SN open.
      -- But it finds up to 10 available reserve locations instead of 1.

     <<outer1>>
     FOR i_counter in tbl_items.first .. tbl_items.last LOOP

         pl_putaway_utilities.p_get_item_info(tbl_items(i_counter).prod_id,
                                              tbl_items(i_counter).cpv,
                                              lt_item_info_rec);

         --
         -- Log item info.
         --
         log_item_info(lt_item_info_rec);

          -- Reset the global variable
         pl_log.g_program_name     := 'PL_MSKU';
         lv_pallet_type := lt_item_info_rec.v_pallet_type;

         -- prppxx 11812
         -- Look for an open non-deep reserve slot for the MSKU in
         -- the primary PUT zone large enough for the MSKU.
         -- The cubes are rounded to 2 decimal places.

         pl_log.ins_msg('INFO', lv_fname, ' parent LP=' || i_parent_pallet_id ||
                  ' Looking for open slot in zone ' || lv_zone_id || '.',
                  NULL, NULL);

     BEGIN
            -- Find the rank 1 case home slot and it's zone for the item.
            SELECT l.logi_loc logi_loc,
                   l.put_aisle  put_aisle,
                   l.put_slot put_slot,
                   l.put_level put_level,
                   z.zone_id
              INTO lv_home_slot,
                   ln_put_aisle,
                   ln_put_slot,
                   ln_put_level,
                   lv_zone_id
              FROM loc l,lzone lz, zone z
             WHERE l.prod_id          = tbl_items(i_counter).prod_id
               AND l.cust_pref_vendor = tbl_items(i_counter).cpv
               AND l.logi_loc         = lz.logi_loc
               AND lz.zone_id         = z.zone_id
               AND z.zone_type        = 'PUT'
               AND l.perm             = 'Y'
               AND l.status           = 'AVL'
               AND l.uom              IN (0,2)
               AND l.rank             = 1;

         EXCEPTION
         WHEN NO_DATA_FOUND THEN
            pl_log.ins_msg('INFO',lv_fname, 'TABLE=loc'
                                           ||'KEY='
                                           ||tbl_items(i_counter).prod_id
                                           ||','|| tbl_items(i_counter).cpv
                                           || ','  || lv_pallet_type
                                           ||'ACTION = SELECT '
                                           ||'MESSAGE ='
                                           ||'No zone of home slot found for'
                                           ||' item'
                                           || tbl_items(i_counter).prod_id
                                           ||'pallet type'
                                           || i_parent_pallet_id,
                                           NULL,SQLCODE);
            -- Search zone_id from last_ship_slot for floating items.
        BEGIN
          SELECT  l.put_aisle  put_aisle,
                      l.put_slot put_slot,
                      l.put_level put_level,
              z.zone_id
        INTO  ln_put_aisle,
              ln_put_slot,
              ln_put_level,
              lv_zone_id
            FROM loc l,lzone lz, zone z
           WHERE l.prod_id          = tbl_items(i_counter).prod_id
             AND l.cust_pref_vendor = tbl_items(i_counter).cpv
         AND l.logi_loc         = lz.logi_loc
                 AND lz.zone_id         = z.zone_id
                 AND z.zone_type        = 'PUT'
         AND l.perm             = 'N'
                 AND l.status           = 'AVL'
         AND z.rule_id = 1
         AND l.logi_loc = lt_item_info_rec.v_last_ship_slot;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg('INFO',lv_fname, 'TABLE=loc'
                                           ||'KEY='
                                           ||tbl_items(i_counter).prod_id
                                           ||','|| tbl_items(i_counter).cpv
                                           || ','  || lv_pallet_type
                                           ||'ACTION = SELECT '
                                           ||'MESSAGE ='
                                           ||'No zone of last_ship_slot found for'
                                           ||' item'
                                           || tbl_items(i_counter).prod_id
                                           ||'pallet type'
                                           || i_parent_pallet_id,
                                           NULL,SQLCODE);
        RAISE;
        WHEN OTHERS THEN
        pl_log.ins_msg('INFO',lv_fname, 'TABLE=loc'
                                             ||'KEY='
                                             ||tbl_items(i_counter).prod_id
                                             ||','||tbl_items(i_counter).cpv
                                             || ','  || lv_pallet_type
                                             ||'ACTION=SELECT'
                                             ||' MESSAGE='
                                             ||'Error while selecting'
                                             ||' from loc table_1',
                                             SQLCODE, SQLERRM);
        RAISE;
        END;
     WHEN OTHERS THEN
            pl_log.ins_msg('INFO',lv_fname, 'TABLE=loc'
                                             ||'KEY='
                                             ||tbl_items(i_counter).prod_id
                                             ||','||tbl_items(i_counter).cpv
                                             || ','  || lv_pallet_type
                                             ||'ACTION=SELECT'
                                             ||' MESSAGE='
                                             ||'Error while selecting'
                                             ||' from loc table_2',
                                             SQLCODE, SQLERRM);
         RAISE;
         END;

         FOR c_nondp_rsv IN c_non_deep_rsv_slot(lv_zone_id, lv_pallet_type,
                                                ln_put_aisle, ln_put_slot,
                                                ln_put_level,ln_msku_reserve_cube) LOOP
            o_avl_locations(ln_num_recs) := c_nondp_rsv.logi_loc;
--dbms_output.put_line('c_nondp_rsv:'||to_char(ln_num_recs)||', ' || c_nondp_rsv.logi_loc);
            ln_num_recs := ln_num_recs + 1;
            EXIT WHEN ln_num_recs > io_num_of_req_loc;
         END LOOP;

         IF ln_num_recs > io_num_of_req_loc THEN
             EXIT;
         ELSE
            -- Did not find enough reserve slot in the items
            -- primary PUT zone.  Now look in the next zones and the
            -- default MSKU PUT zone for the area.
            ln_next_zones := 0;
            lb_location_found := FALSE;

            OPEN c_next_zones(lv_zone_id, lt_item_info_rec.v_area);
               LOOP
                  FETCH c_next_zones INTO r_next_zones;
                  EXIT WHEN c_next_zones%NOTFOUND;

                  ln_next_zones := ln_next_zones + 1;

                  IF (ln_next_zones > lt_item_info_rec.n_num_next_zones
                      AND r_next_zones.what_kind_of_zone = 'NEXTZONE')  THEN
                     -- The maximum number of next zones has been reached.
                     -- Skip over the remaining next zones.
                     NULL;
                  ELSIF (    r_next_zones.what_kind_of_zone = 'DFLTZONE'
                         AND r_next_zones.zone_id IS NULL)  THEN
                     -- The default MSKU put zone for the area is null.
                     -- This is not an error.  Log a message and continue.
                     lv_message := 'SN=' || i_sn_number
                                     || ' TABLE=swms_area'
                                     || ' Area='
                                     || lt_item_info_rec.v_area
                                     || ' Item='
                                     || tbl_items(i_counter).prod_id
                                     || ' CPV='
                                     || tbl_items(i_counter).cpv
              || ' MESSAGE=The default MSKU PUT zone for this area is null.';

                     pl_log.ins_msg('INFO', lv_fname, lv_message, NULL, NULL);

                  ELSE
                        -- Look for a slot for the MSKU large enough.
                        -- The cubes are rounded to 2 decimal places.

                        IF (r_next_zones.what_kind_of_zone = 'NEXTZONE') THEN
                           pl_log.ins_msg('INFO', lv_fname,
                             'SN=' || i_sn_number ||
                             ' parent LP=' || i_parent_pallet_id ||
                             ' Looking for open slot in next zone ' ||
                             r_next_zones.zone_id || '.',
                             NULL, NULL);
                        ELSE
                           pl_log.ins_msg('INFO', lv_fname,
                             'SN=' || i_sn_number ||
                             ' parent LP=' || i_parent_pallet_id ||
                             ' Looking for open slot in dflt msku put zone ' ||
                             r_next_zones.zone_id || '.',
                             NULL, NULL);
                        END IF;
                        FOR c_nondp_rsv IN c_non_deep_rsv_slot(r_next_zones.zone_id,lv_pallet_type,
                                                       ln_put_aisle, ln_put_slot,
                                                       ln_put_level,ln_msku_reserve_cube) LOOP
                           o_avl_locations(ln_num_recs) := c_nondp_rsv.logi_loc;
                           ln_num_recs := ln_num_recs + 1;
                           EXIT WHEN ln_num_recs > io_num_of_req_loc;
                        END LOOP;
          END IF;

                  IF (ln_num_recs > io_num_of_req_loc) THEN
                        EXIT outer1 ;
                  END IF;
               END LOOP;    -- end next zones loop
        CLOSE c_next_zones;
         END IF; -- end not enough reserve loc found.
     END LOOP outer1;
     IF ln_num_recs > 1 THEN
    lb_status := TRUE;
     END IF;
   END IF;
   IF lb_record_found AND putaway_repl_indicator = 'IP' THEN
      io_num_of_req_loc := 1;
      o_avl_locations(ln_num_recs) := o_dest_loc;
   END IF;
   IF lb_status = FALSE AND putaway_repl_indicator = 'IP' THEN
      o_avl_locations(ln_num_recs) := '*';
      pl_log.ins_msg('INFO',lv_fname,'SN='||i_sn_number
                                          || ' TABLE=none'
                                          || ' KEY=' || i_sn_number || ','
                                          || i_parent_pallet_id || ','
                                          || 'MESSAGE='
                                          || 'No open slot found to putaway '
                                          || 'MSKU pallet id '
                                          || i_parent_pallet_id
                                          || 'SN=' || i_sn_number,
                                          NULL,NULL);
      io_num_of_req_loc := 1;
   END IF;

   IF putaway_repl_indicator = 'R' THEN
      io_num_of_req_loc := ln_num_recs - 1;
   END IF;
EXCEPTION
WHEN OTHERS THEN
   RAISE;
END p_find_reserve_slot_for_msku;

/*-----------------------------------------------------------------------
-- Procedure
--    p_find_anchor_pick_items
--
-- Description:
-- This procedure will return an array of the anchor pick items sorted on
-- the items with max qty, then height/cube and then by product id.
--
-- Parameters:
--    i_parent_pallet_id   - Parent pallet id
--    i_sn_no              - SN
--    i_putaway_repl_ind   - Initial Putaway, Putaway or Replenishment
--    o_items              - Array of items and their putaway locs.
--    o_msku_reserve_cube  - The cube of the child pallets on the MSKU going to
--                           reserve.  It includes the skid cube.
--
-- Exceptions raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------
--    12/08/04 prpbcb   Added o_msku_reserve_cube.  It will be used in
--                      determining the reserve slot for the MSKU when
--                      the MSKU is going to reserve.  Before no check
--                      was made of the cube so it was possible the
--                      MSKU could be directed to a slot (for putaway only)
--                      where the MSKU would not fit.
---------------------------------------------------------------------*/
PROCEDURE p_find_anchor_pick_items
           (i_parent_pallet_id           IN      erd_lpn.parent_pallet_id%TYPE,
            i_sn_no                      IN      erd_lpn.sn_no%TYPE,
            i_putaway_repl_ind           IN      VARCHAR2,
            o_items                      OUT     t_items,
            o_msku_reserve_cube          OUT     NUMBER)
IS
   lv_put_dim_syspar  sys_config.config_flag_val%TYPE;
   lv_pname           VARCHAR2(50) := 'p_find_anchor_pick_items';

   -- This cursor is for putaway_repl_ind = 'IP'
   CURSOR c_item_info_ip(cp_put_dim_syspar sys_config.config_flag_val%TYPE)
   IS
      SELECT erd_lpn.prod_id           prod_id,
             erd_lpn.cust_pref_vendor  cpv,
             SUM(erd_lpn.qty/pm.spc)   qty,
             SUM(CEIL(erd_lpn.qty/(pm.ti*pm.spc))* pm.case_height)  height,
             SUM((erd_lpn.qty*pm.case_cube)/pm.spc)                 cube
        FROM erd_lpn, pm
       WHERE erd_lpn.sn_no            = i_sn_no
         AND erd_lpn.parent_pallet_id = i_parent_pallet_id
         AND erd_lpn.prod_id          = pm.prod_id
         AND erd_lpn.cust_pref_vendor = pm.cust_pref_vendor
         AND NOT EXISTS (SELECT 'X'
                           FROM putawaylst
                          WHERE sn_no      = i_sn_no
                            AND pallet_id  = erd_lpn.pallet_id)
       GROUP BY erd_lpn.prod_id, erd_lpn.cust_pref_vendor
       ORDER BY qty DESC,
                DECODE(cp_put_dim_syspar,'I',SUM(CEIL(erd_lpn.qty/(pm.ti*pm.spc))* pm.case_height),SUM((erd_lpn.qty*pm.case_cube)/pm.spc)) DESC;

---------------------------------------------------------------------------

-- This cursor is for putaway_repl_ind = 'P'
   CURSOR c_item_info_p(cp_put_dim_syspar sys_config.config_flag_val%TYPE)
   IS
      SELECT erd_lpn.prod_id           prod_id,
             erd_lpn.cust_pref_vendor  cpv,
             SUM(erd_lpn.qty/pm.spc)   qty,
             SUM(ceil(erd_lpn.qty / (pm.ti * pm.spc)) * pm.case_height) height,
             SUM((erd_lpn.qty * pm.case_cube) / pm.spc)                 cube
        FROM erd_lpn, pm
       WHERE erd_lpn.sn_no            = i_sn_no
         AND erd_lpn.parent_pallet_id = i_parent_pallet_id
         AND erd_lpn.prod_id          = pm.prod_id
         AND erd_lpn.cust_pref_vendor = pm.cust_pref_vendor
       GROUP BY erd_lpn.prod_id, erd_lpn.cust_pref_vendor
       ORDER BY qty DESC,
             DECODE(cp_put_dim_syspar,'I',SUM(ceil(erd_lpn.qty/(pm.ti*pm.spc))* pm.case_height), SUM((erd_lpn.qty*pm.case_cube)/pm.spc) ) DESC;
---------------------------------------------------------------------------

-- This cursor is for putaway_repl_ind = 'R'
   CURSOR c_item_info_r(cp_put_dim_syspar sys_config.config_flag_val%TYPE)
   IS
      SELECT inv.prod_id           prod_id,
             inv.cust_pref_vendor  cpv,
             SUM(inv.qoh/pm.spc)   qoh,
             SUM(CEIL(inv.qoh / (pm.ti * pm.spc)) * pm.case_height)  height,
             SUM((inv.qoh * pm.case_cube) / pm.spc)                  cube
        FROM inv, pm
       WHERE inv.parent_pallet_id = i_parent_pallet_id AND
             inv.prod_id          = pm.prod_id AND
             inv.cust_pref_vendor = pm.cust_pref_vendor
       GROUP BY inv.prod_id, inv.cust_pref_vendor
       ORDER BY qoh DESC,
             DECODE(cp_put_dim_syspar,'I',SUM(CEIL(inv.qoh/(pm.ti*pm.spc))* pm.case_height),SUM((inv.qoh*pm.case_cube)/pm.spc) ) DESC;
---------------------------------------------------------------------------

   ln_size               NUMBER;

BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_MSKU';

    --This will be used in the Exception message
    pl_putaway_utilities.gv_program_name := lv_pname;
    pl_log.ins_msg ('INFO',lv_pname,'Starting '
                   ||'p_find_anchor_pick_items',NULL, NULL);

    ln_size := 0;
    lv_put_dim_syspar := pl_common.f_get_syspar('PUTAWAY_DIMENSION');

    -- Initialize the cube of the reserve pallet to the skid cube for
    -- the LW pallet type.   The business rule is a MSKU will always be on
    -- a LW.

    o_msku_reserve_cube := f_get_msku_skid_cube;

    IF i_putaway_repl_ind = 'IP' THEN
        BEGIN
            FOR l_item_info IN c_item_info_ip(lv_put_dim_syspar)
            LOOP
                ln_size := ln_size + 1;
                o_items(ln_size).prod_id := l_item_info.prod_id;
                o_items(ln_size).cpv     := l_item_info.cpv;
                o_msku_reserve_cube := o_msku_reserve_cube + l_item_info.cube;
                pl_log.ins_msg('WARN',lv_pname,
                      'find anchor pick items for parent'
                      || ' pallet id during IP:'
                      ||i_parent_pallet_id || ',item:' || o_items(ln_size).prod_id,NULL,SQLCODE);
            END LOOP;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_log.ins_msg('WARN',lv_pname,'Unable '
                      ||'to find anchor pick items for parent'
                      || ' pallet id during initial putaway'
                      ||i_parent_pallet_id,NULL,SQLCODE);

        RAISE;

        END;

    ELSIF i_putaway_repl_ind = 'P' THEN
        BEGIN
            FOR l_item_info IN c_item_info_p(lv_put_dim_syspar)
            LOOP
                ln_size := ln_size + 1;
                o_items(ln_size).prod_id := l_item_info.prod_id;
                o_items(ln_size).cpv     := l_item_info.cpv;
                o_msku_reserve_cube := o_msku_reserve_cube + l_item_info.cube;
            END LOOP;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_log.ins_msg('WARN',lv_pname,'Unable '
                      ||'to find anchor pick items for parent'
                      || ' pallet id during putaway'
                      ||i_parent_pallet_id,NULL,SQLCODE);

       RAISE;
       END;

    ELSIF i_putaway_repl_ind = 'R' THEN
        BEGIN
            FOR l_item_info IN c_item_info_r(lv_put_dim_syspar)
            LOOP
                ln_size := ln_size + 1;
                o_items(ln_size).prod_id := l_item_info.prod_id;
                o_items(ln_size).cpv     := l_item_info.cpv;
                o_msku_reserve_cube := o_msku_reserve_cube + l_item_info.cube;
            END LOOP;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_log.ins_msg('WARN',lv_pname,'Unable '
                      ||'to find anchor pick items for parent'
                      || ' pallet id during replenishment'
                      ||i_parent_pallet_id,NULL,SQLCODE);

        RAISE;
        END;

    END IF;

END p_find_anchor_pick_items;


/*-----------------------------------------------------------------------
-- Procedure
--    p_process_floating_items_msku
--
-- Description:
-- This procedure will be used to assign open locations
-- to floating items present on a MSKU pallet.
--
-- Parameters:
     --i_item_info_rec         Record for item information
     --i_sn_no                 sn_no
     --i_work_var_rec          Record for work var parameters
     --i_parent_pl_id          Parent pallet id
     --i_items                 Record of t_floating_putaway
     --i_aging_days            Aging days
     --i_clam_bed_tracked_flag Syspar flag
--
-- Exceptions raised:
--
---------------------------------------------------------------------*/
PROCEDURE p_process_floating_items_msku
    (i_item_info_rec IN   pl_putaway_utilities.t_item_related_info,
     i_sn_no         IN   erd_lpn.sn_no%TYPE,
     io_work_var_rec  IN OUT   pl_putaway_utilities.t_work_var,
     i_parent_pl_id  IN   erd_lpn.parent_pallet_id%TYPE,
     i_items         IN   t_floating_putaway,
     i_aging_days    IN   aging_items.aging_days%TYPE,
     i_clam_bed_tracked_flag IN sys_config.config_flag_val%TYPE)
IS
l_index NUMBER;
lv_dest_loc          loc.logi_loc%TYPE;
ln_put_aisle1        loc.put_aisle%TYPE;
ln_put_slot1         loc.put_slot%TYPE;
ln_put_level1        loc.put_level%TYPE;
lv_slot_type         slot_type.slot_type%TYPE;

lv_phys_loc          loc.logi_loc%TYPE;
ln_put_aisle2        loc.put_aisle%TYPE;
ln_put_slot2         loc.put_slot%TYPE;
ln_put_level2        loc.put_level%TYPE;
ln_shipped_ti        erd_lpn.shipped_ti%TYPE;
lv_putaway_dimension sys_config.config_flag_val%TYPE;
lv_pname             VARCHAR2(50)  := 'p_process_floating_items_msku';
e_pallet_id_fetch_fail EXCEPTION;
e_syspar_null          EXCEPTION;
e_shipped_ti           EXCEPTION;
ln_child_pallet_count  NUMBER;
BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_MSKU';
    --This will be used in the Exception message
    pl_putaway_utilities.gv_program_name := lv_pname;
    pl_log.ins_msg ('INFO',lv_pname,'Starting '
                  ||'p_process_floating_items_msku',NULL, NULL);

    -- populate io_work_var_rec before inserting

      /* 10/27/06 BEG DEL Infosys - MSKU pallets can have qty > 1 */
      /* io_work_var_rec.n_each_pallet_qty := 1; */
      /* 10/27/06 END DEL Infosys */

      io_work_var_rec.v_no_splits := i_item_info_rec.n_spc;
      io_work_var_rec.b_first_home_assign := FALSE;
    ------------------section A--------------------------------------------
    BEGIN
       SELECT DISTINCT shipped_ti
       INTO ln_shipped_ti
       FROM erd_lpn
       WHERE sn_no = i_sn_no
         AND prod_id = i_items.prod_id
         AND parent_pallet_id = i_parent_pl_id
         AND ROWNUM = 1;
    EXCEPTION
    WHEN OTHERS THEN
       pl_log.ins_msg ('WARN',lv_pname,'Error in fetching shipped_ti'
                                        ||'from erd_lpn for product['
                                        ||i_items.prod_id || '], SN['
                                        ||i_sn_no || '], Parent pallet['
                                        || i_parent_pl_id ||']',NULL, SQLERRM);

      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN= '
                                                     || i_sn_no;
            pl_putaway_utilities.
            gv_crt_message := RPAD(pl_putaway_utilities.gv_crt_message,80)
                         || 'Error in fetching shipped_ti'
                         ||'from erd_lpn for product['
                         ||i_items.prod_id || '], SN['
                         ||i_sn_no || '], Parent pallet['
                         || i_parent_pl_id ||']';
      RAISE e_shipped_ti;

    END;



   lv_putaway_dimension := pl_common.f_get_syspar('PUTAWAY_DIMENSION');

   --reset the global variable
   pl_log.g_program_name     := 'PL_MSKU';

   IF lv_putaway_dimension IS NOT NULL THEN
   --log the success message


      pl_log.ins_msg('INFO',lv_pname,'Value of PUTAWAY_DIMENSION syspar is :'
                    || lv_putaway_dimension,NULL,SQLERRM);

   ELSIF lv_putaway_dimension IS NULL THEN

      pl_log.ins_msg('WARN',lv_pname,'TABLE=SYS_CONFIG KEY='
                    ||' PUTAWAY_DIMENSION ACTION= SELECT MESSAGE= ORACLE '
                    ||'failed to select PUTAWAY_DIMENSION syspar',
                     null,sqlerrm);


      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN= '
                                               || i_sn_no;
      pl_putaway_utilities.
      gv_crt_message := RPAD(pl_putaway_utilities.gv_crt_message,80)
                  || 'REASON: Unable to select'
                  || ' PUTAWAY_DIMENSION syspar from sys_config';

      RAISE e_syspar_null;

   END IF;
   ln_child_pallet_count := i_items.child_pallet_ids.COUNT;
  -------------------end section A------------------------------------------------
    -- call p_insert_table for each of child pallet_ids
    BEGIN

        SELECT logi_loc,put_aisle,put_slot,
           put_level,slot_type INTO
           lv_dest_loc,
           ln_put_aisle1,
           ln_put_slot1,
           ln_put_level1,
           lv_slot_type
        FROM

           (SELECT l.logi_loc logi_loc,l.put_aisle put_aisle,
            l.put_slot put_slot,l.put_level put_level,
            l.slot_type slot_type
            FROM slot_type s, loc l, lzone z, inv i
            WHERE s.slot_type = l.slot_type
              AND l.logi_loc = z.logi_loc
              AND z.logi_loc = i.plogi_loc
              AND z.zone_id = i_item_info_rec.v_zone_id
              AND i.prod_id = i_items.prod_id
              AND i.cust_pref_vendor = i_items.cpv
            ORDER BY i.exp_date, i.qoh, i.logi_loc)

        WHERE ROWNUM=1;

    EXCEPTION WHEN NO_DATA_FOUND THEN
        pl_log.ins_msg ('INFO',lv_pname,'Couldnt find item '
                  ||'in inv table.',NULL, NULL);

    END;
    IF SQL%FOUND THEN

       pl_log.ins_msg ('INFO',lv_pname,'item '
                 ||i_items.prod_id||' exists in INV table,getting the '
                 ||'open slot closest to this slot',NULL, NULL);
      BEGIN
        SELECT logi_loc, put_aisle,
           put_slot, put_level INTO
           lv_phys_loc,
           ln_put_aisle2,
           ln_put_slot2,
           ln_put_level2
        FROM
            (SELECT l.logi_loc logi_loc, l.put_aisle put_aisle,
               l.put_slot put_slot, l.put_level put_level
             FROM pallet_type p, slot_type s,loc l,lzone z
             WHERE p.pallet_type = l.pallet_type
               AND s.slot_type = l.slot_type
               AND l.pallet_type = i_item_info_rec.v_pallet_type
               AND l.logi_loc = z.logi_loc
               AND l.perm = 'N'
               AND l.status = 'AVL'
               AND z.zone_id = i_item_info_rec.v_zone_id
               AND NOT EXISTS(SELECT 'x'
                              FROM inv i
                              WHERE i.plogi_loc = l.logi_loc)
        -----------------section B-------------------------------
        AND ((lv_putaway_dimension = 'C'
                      AND (ln_child_pallet_count
                           * NVL(i_item_info_rec.n_case_cube,0))
                             < NVL(l.cube,0))
                     OR
                    (lv_putaway_dimension = 'I'
                      AND CEIL(ln_child_pallet_count/ln_shipped_ti)
                               * NVL(i_item_info_rec.n_case_height,0)
                                   < NVL(l.available_height,0)))
       -----------------end section B-----------------------------------
             ORDER BY ABS(ln_put_aisle1 - l.put_aisle),l.put_aisle,
                        ABS(ln_put_slot1 - l.put_slot),l.put_slot,
                        ABS(ln_put_level1 - l.put_level),l.put_level)

        WHERE ROWNUM = 1;

        FOR l_index IN
        i_items.child_pallet_ids.FIRST..i_items.child_pallet_ids.LAST
        LOOP
            io_work_var_rec.n_erm_line_id := i_items.child_pallet_ids(l_index);

            /* 10/27/06 BEG MOD Infosys - Query changed to retrieve quantity information too */
            BEGIN
               SELECT pallet_id,qty
               INTO io_work_var_rec.v_pallet_id,io_work_var_rec.n_each_pallet_qty
               FROM erd_lpn
               WHERE erm_line_id = io_work_var_rec.n_erm_line_id
               AND   sn_no = i_sn_no;
            /* 10/27/06 END MOD Infosys */

            EXCEPTION
            WHEN OTHERS THEN
               pl_log.ins_msg('WARN',lv_pname,'SN ='  ||i_sn_no
                                                      || ' TABLE = erd_lpn'
                                                      ||'KEY='
                                                      || io_work_var_rec.n_erm_line_id
                                                      ||'ACTION = SELECT'
                                                      ||' MESSAGE ='
                                                      ||'error while selecting pallet_id'
                                                      ||' from erd_lpn table',
                                                      NULL,SQLCODE);
               pl_putaway_utilities.gv_crt_message :=
                                 RPAD(pl_putaway_utilities.gv_crt_message,80)
                                                ||'SN ='||i_sn_no
                                                || ' TABLE = erd_lpn'
                                                ||'KEY='
                                                || io_work_var_rec.n_erm_line_id
                                                ||'ACTION = SELECT'
                                                ||' MESSAGE ='
                                                ||'error while selecting'
                                                ||' from erd_lpn table'
                                                ||' - sqlcode= '
                                                ||sqlcode;
                RAISE e_pallet_id_fetch_fail;
            END;

        /*10/27/06 BEG INS Infosys - Inserted to support MSKU LPs with qty > 1 */
             io_work_var_rec.n_each_pallet_qty := io_work_var_rec.n_each_pallet_qty/i_item_info_rec.n_spc;
            /* 10/27/06 END INS Infosys */

            pl_putaway_utilities.p_insert_table
                       (i_items.prod_id,
                        i_items.cpv,
                        lv_phys_loc,
                        pl_putaway_utilities.ADD_RESERVE,
                        i_sn_no,
                        i_aging_days,
                        i_clam_bed_tracked_flag,
                        i_item_info_rec,
                        io_work_var_rec);

        END LOOP;
     EXCEPTION WHEN NO_DATA_FOUND THEN
            FOR l_index IN
            i_items.child_pallet_ids.FIRST..i_items.child_pallet_ids.LAST
            LOOP
                io_work_var_rec.n_erm_line_id := i_items.child_pallet_ids(l_index);

                /* 10/27/06 BEG MOD Infosys - Query changed to retrieve quantity information too */
                BEGIN
                   SELECT pallet_id,qty
                   INTO io_work_var_rec.v_pallet_id,io_work_var_rec.n_each_pallet_qty
                   FROM erd_lpn
                   WHERE erm_line_id = io_work_var_rec.n_erm_line_id
                   AND   sn_no = i_sn_no;
                /* 10/27/06 END MOD Infosys */

                EXCEPTION
                WHEN OTHERS THEN
                   pl_log.ins_msg('WARN',lv_pname,'SN ='  ||i_sn_no
                                                          || ' TABLE = erd_lpn'
                                                          ||'KEY='
                                                          || io_work_var_rec.n_erm_line_id
                                                          ||'ACTION = SELECT'
                                                          ||' MESSAGE ='
                                                          ||'error while selecting pallet_id'
                                                          ||' from erd_lpn table',
                                                          NULL,SQLCODE);
                   pl_putaway_utilities.gv_crt_message :=
                                     RPAD(pl_putaway_utilities.gv_crt_message,80)
                                                    ||'SN ='||i_sn_no
                                                    || ' TABLE = erd_lpn'
                                                    ||'KEY='
                                                    || io_work_var_rec.n_erm_line_id
                                                    ||'ACTION = SELECT'
                                                    ||' MESSAGE ='
                                                    ||'error while selecting'
                                                    ||' from erd_lpn table'
                                                    ||' - sqlcode= '
                                                    ||sqlcode;
                    RAISE e_pallet_id_fetch_fail;
            END;

                /* 10/27/06 BEG INS Infosys - Inserted to support MSKU LPs with qty > 1 */
                io_work_var_rec.n_each_pallet_qty := io_work_var_rec.n_each_pallet_qty/i_item_info_rec.n_spc;
                /* 10/27/06 END INS Infosys */

                pl_putaway_utilities.p_insert_table
                           (i_items.prod_id,
                            i_items.cpv,
                            '*',
                            pl_putaway_utilities.ADD_NO_INV,
                            i_sn_no,
                            i_aging_days,
                            i_clam_bed_tracked_flag,
                            i_item_info_rec,
                            io_work_var_rec);

        END LOOP;

          pl_log.ins_msg ('INFO',lv_pname,'Item located in INV table, but no'
                ||'records found for slots closest to this slot',NULL, NULL);

     END;
    ELSE

        pl_log.ins_msg ('INFO',lv_pname,'item '
                 ||i_items.prod_id ||' doesnt exist in INV table,getting '
                 ||'the slot closest to its last ship slot ',NULL, NULL);
      BEGIN
        SELECT logi_loc, put_aisle,
           put_slot, put_level INTO
           lv_phys_loc,
           ln_put_aisle2,
           ln_put_slot2,
           ln_put_level2
        FROM
            (SELECT l.logi_loc logi_loc, l.put_aisle put_aisle,
               l.put_slot put_slot, l.put_level put_level
             FROM pallet_type p, slot_type s,loc l,lzone z
             WHERE p.pallet_type = l.pallet_type
               AND s.slot_type = l.slot_type
               AND l.pallet_type = i_item_info_rec.v_pallet_type -- pallet type
               AND l.logi_loc = z.logi_loc
               AND l.perm = 'N'
               AND l.status = 'AVL'
               AND z.zone_id = i_item_info_rec.v_zone_id -- zone_id
               AND NOT EXISTS(SELECT 'x'
                              FROM inv i
                              WHERE i.plogi_loc = l.logi_loc)
               --------------section C-----------------------------------------
               AND ((lv_putaway_dimension = 'C'
                      AND (ln_child_pallet_count
                           * NVL(i_item_info_rec.n_case_cube,0))
                             < nvl(l.cube,0))
                     OR
                    (lv_putaway_dimension = 'I'
                      AND CEIL(ln_child_pallet_count/ln_shipped_ti)
                               * NVL(i_item_info_rec.n_case_height,0)
                    < NVL(l.available_height,0)))
               -------------end section C------------------------------------------
             ORDER BY
               ABS(i_item_info_rec.n_last_put_aisle1 - l.put_aisle),l.put_aisle,
               ABS(i_item_info_rec.n_last_put_slot1 - l.put_slot),l.put_slot,
               ABS(i_item_info_rec.n_last_put_level1 - l.put_level),l.put_level)

        WHERE ROWNUM = 1;


        FOR l_index IN
        i_items.child_pallet_ids.FIRST..i_items.child_pallet_ids.LAST
        LOOP
            io_work_var_rec.n_erm_line_id := i_items.child_pallet_ids(l_index);

            /* 10/27/06 BEG MOD Infosys - Query changed to retrieve quantity information too */
            BEGIN
               SELECT pallet_id,qty
               INTO io_work_var_rec.v_pallet_id,io_work_var_rec.n_each_pallet_qty
               FROM erd_lpn
               WHERE erm_line_id = io_work_var_rec.n_erm_line_id
               AND   sn_no = i_sn_no;
            /* 10/27/06 END MOD Infosys */

            EXCEPTION
            WHEN OTHERS THEN
               pl_log.ins_msg('WARN',lv_pname,'SN ='  ||i_sn_no
                                                      || ' TABLE = erd_lpn'
                                                      ||'KEY='
                                                      || io_work_var_rec.n_erm_line_id
                                                      ||'ACTION = SELECT'
                                                      ||' MESSAGE ='
                                                      ||'error while selecting pallet_id'
                                                      ||' from erd_lpn table',
                                                      NULL,SQLCODE);
               pl_putaway_utilities.gv_crt_message :=
                                 RPAD(pl_putaway_utilities.gv_crt_message,80)
                                                ||'SN ='||i_sn_no
                                                || ' TABLE = erd_lpn'
                                                ||'KEY='
                                                || io_work_var_rec.n_erm_line_id
                                                ||'ACTION = SELECT'
                                                ||' MESSAGE ='
                                                ||'error while selecting'
                                                ||' from erd_lpn table'
                                                ||' - sqlcode= '
                                                ||sqlcode;
                RAISE e_pallet_id_fetch_fail;
            END;

            /* 10/27/06 BEG INS Infosys - Inserted to support MSKU LPs with qty > 1 */
            io_work_var_rec.n_each_pallet_qty := io_work_var_rec.n_each_pallet_qty/i_item_info_rec.n_spc;
            /* 10/27/06 END INS Infosys */

            pl_putaway_utilities.p_insert_table
                       (i_items.prod_id,
                        i_items.cpv,
                        lv_phys_loc,
                        pl_putaway_utilities.ADD_RESERVE,
                        i_sn_no,
                        i_aging_days,
                        i_clam_bed_tracked_flag,
                        i_item_info_rec,
                        io_work_var_rec);
        END LOOP;
      EXCEPTION WHEN NO_DATA_FOUND THEN
          FOR l_index IN
          i_items.child_pallet_ids.FIRST..i_items.child_pallet_ids.LAST
          LOOP
              io_work_var_rec.n_erm_line_id := i_items.child_pallet_ids(l_index);
              /* 10/27/06 BEG MOD Infosys - Query changed to retrieve quantity information too */
              BEGIN
                 SELECT pallet_id,qty
                 INTO io_work_var_rec.v_pallet_id,io_work_var_rec.n_each_pallet_qty
                 FROM erd_lpn
                 WHERE erm_line_id = io_work_var_rec.n_erm_line_id
                 AND   sn_no = i_sn_no;
              /* 10/27/06 END MOD Infosys */

              EXCEPTION
              WHEN OTHERS THEN
                 pl_log.ins_msg('WARN',lv_pname,'SN ='  ||i_sn_no
                                                        || ' TABLE = erd_lpn'
                                                        ||'KEY='
                                                        || io_work_var_rec.n_erm_line_id
                                                        ||'ACTION = SELECT'
                                                        ||' MESSAGE ='
                                                        ||'error while selecting pallet_id'
                                                        ||' from erd_lpn table',
                                                        NULL,SQLCODE);
                 pl_putaway_utilities.gv_crt_message :=
                                   RPAD(pl_putaway_utilities.gv_crt_message,80)
                                                  ||'SN ='||i_sn_no
                                                  || ' TABLE = erd_lpn'
                                                  ||'KEY='
                                                  || io_work_var_rec.n_erm_line_id
                                                  ||'ACTION = SELECT'
                                                  ||' MESSAGE ='
                                                  ||'error while selecting'
                                                  ||' from erd_lpn table'
                                                  ||' - sqlcode= '
                                                  ||sqlcode;
                  RAISE e_pallet_id_fetch_fail;
            END;

              /* 10/27/06 BEG INS Infosys - Inserted to support MSKU LPs with qty > 1 */
              io_work_var_rec.n_each_pallet_qty := io_work_var_rec.n_each_pallet_qty/i_item_info_rec.n_spc;
              /* 10/27/06 END INS Infosys  */

              pl_putaway_utilities.p_insert_table
                         (i_items.prod_id,
                          i_items.cpv,
                          '*',
                          pl_putaway_utilities.ADD_NO_INV,
                          i_sn_no,
                          i_aging_days,
                          i_clam_bed_tracked_flag,
                          i_item_info_rec,
                          io_work_var_rec);

        END LOOP;
          pl_log.ins_msg ('INFO',lv_pname,'Item located in INV table, but no'
                ||'records found for slots closest to this slot',NULL, NULL);
      END;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN',lv_pname,'Unable to process floating item_id '
                                ||i_items.prod_id,NULL,SQLCODE);
        RAISE;
END p_process_floating_items_msku;


/*-----------------------------------------------------------------------
   -- Function:
   --    f_is_msku_pallet
   --
   -- Description:
   -- This function determines if the input pallet id is
   -- part of an MSKU pallet.
   --
   -- Parameters:
   --    i_pallet_id                - pallet id

   -- RETURN VALUE                  - STATUS
---------------------------------------------------------------------*/

FUNCTION f_is_msku_pallet
        (i_pallet_id    IN  inv.logi_loc%TYPE,
         i_indicator    IN  CHAR)
RETURN BOOLEAN

IS
    status                BOOLEAN;
    ln_parent_pallet_id   inv.parent_pallet_id%TYPE;
    lv_fname              VARCHAR2(50)  := 'f_is_msku_pallet';

BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_MSKU';
    --This will be used in the Exception message
    pl_putaway_utilities.gv_program_name := lv_fname;
    pl_log.ins_msg ('INFO', lv_fname,
                 'Starting f_is_msku_pallet',NULL, NULL);

    status := FALSE;
    ln_parent_pallet_id := '0';
    --check if the input pallet id is an MSKU child pallet id.

    BEGIN
      IF i_indicator = 'I' THEN
        SELECT    NVL(parent_pallet_id,'0')
          INTO    ln_parent_pallet_id
          FROM    inv
         WHERE    logi_loc = i_pallet_id
          AND     status != 'CDK';
      ELSIF i_indicator = 'P' THEN
        SELECT    NVL(parent_pallet_id,'0')
          INTO    ln_parent_pallet_id
          FROM    putawaylst
         WHERE    pallet_id = i_pallet_id
          AND     inv_status != 'CDK';
      ELSIF (i_indicator = 'R') THEN
        SELECT    NVL (parent_pallet_id, '0')
          INTO    ln_parent_pallet_id
          FROM    replenlst
         WHERE    (pallet_id = i_pallet_id OR
             (parent_pallet_id = i_pallet_id AND ROWNUM = 1));
      END IF;
        IF ln_parent_pallet_id = '0' THEN
            status := FALSE;
            pl_log.ins_msg ('DEBUG', lv_fname,
                 'Pallet id '||i_pallet_id
                 ||' does not have a valid parent pallet id' ,NULL, NULL);

        ELSE
            status := TRUE;
            pl_log.ins_msg ('DEBUG', lv_fname,
                 'Pallet id '||i_pallet_id
                 ||' has parent pallet id '
                 ||ln_parent_pallet_id ,NULL, NULL);
        END IF;
        RETURN status;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            BEGIN
              IF i_indicator = 'I' THEN

                SELECT DISTINCT parent_pallet_id
                INTO ln_parent_pallet_id
                FROM inv WHERE parent_pallet_id = i_pallet_id
				AND status != 'CDK';
              ELSIF i_indicator = 'P' THEN

                SELECT DISTINCT parent_pallet_id
                INTO ln_parent_pallet_id
                FROM putawaylst WHERE parent_pallet_id = i_pallet_id
				 AND inv_status != 'CDK';
              END IF;

                IF SQL%FOUND THEN
                pl_log.ins_msg ('DEBUG', lv_fname,
                     'Pallet id '||i_pallet_id
                     ||' is a valid parent pallet id' ,NULL, NULL);
                    RETURN TRUE;
                END IF;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                pl_log.ins_msg ('DEBUG', lv_fname,
                     'Pallet id '||i_pallet_id
                  ||' does not have a valid parent pallet id'
                  ||' nor is a valid parent pallet id by itself',NULL, NULL);
                RETURN FALSE;
            END;
    END;

EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END f_is_msku_pallet;


/*-----------------------------------------------------------------------
   -- Function:
   --    f_val_multiple_pk
   --
   -- Description:
   -- This function performs validations such as, when a user has picked a
   -- MSKU pallet he should not be allowed to pick up any other pallet.
   -- If he has picked up some other pallet he should not be allowed to
   -- pick a MSKU pallet.

   -- Parameters:
   --    i_pallet_id                - pallet id
   --    i_user_id                  - user id
   --    i_mode                     - mode

   -- RETURN VALUES                  - STATUS
---------------------------------------------------------------------*/
FUNCTION f_val_multiple_pk
          (i_pallet_id          IN      trans.pallet_id%TYPE,
           i_user_id            IN      trans.user_id%TYPE,
           i_mode               IN      CHAR)
RETURN NUMBER

IS
    status     NUMBER;
    lv_tmp_check          VARCHAR2(1);
    lv_temp_task_id       replenlst.task_id%TYPE;
    lv_fname              VARCHAR2(50)  := 'f_val_multiple_pk';
BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_MSKU';
    --This will be used in the Exception message
    pl_putaway_utilities.gv_program_name := lv_fname;
    pl_log.ins_msg ('INFO', lv_fname,
                 'Starting f_val_multiple_pk',NULL, NULL);

    status := 0;

    -- validation is during replenishment
    IF i_mode = 'R' THEN

        IF f_is_msku_pallet(i_pallet_id,'I') THEN
          BEGIN
            SELECT task_id INTO lv_temp_task_id
            FROM replenlst WHERE status = 'PIK'
               AND user_id = i_user_id AND parent_pallet_id IS NULL
               AND ROWNUM = 1;
            IF SQL%FOUND THEN
               pl_log.ins_msg('INFO',lv_fname,'Cannot pick MSKU pallet '
                ||i_pallet_id ||' as there is a pending replenishment task '
                ||'for NON MSKU pallet',NULL,NULL);
               status := pl_exc.f_get_rf_errcode(pl_exc.ct_msku_msku_rep_pik);
            END IF;
          EXCEPTION WHEN NO_DATA_FOUND THEN
               pl_log.ins_msg('INFO',lv_fname,'MSKU pallet '
                ||i_pallet_id ||' doesnt have any pending replenishment task '
                ||'for any NON MSKU pallet',NULL,NULL);
          END;
        ELSE
          BEGIN
            SELECT TASK_ID INTO lv_temp_task_id
            FROM REPLENLST WHERE STATUS = 'PIK'
               AND USER_ID = i_user_id
               AND PARENT_PALLET_ID IS NOT NULL
               AND ROWNUM = 1;
            -- cannot pick pallet since there is a pending
            -- replenishment task for MSKU pallet
            IF SQL%FOUND THEN
               pl_log.ins_msg('INFO',lv_fname,
                'Cannot pick pallet as there is a pending replenishment task '
                ||'for MSKU pallet '||i_pallet_id,NULL,NULL);
               status := pl_exc.f_get_rf_errcode(pl_exc.ct_msku_non_msku_rep_pik);
            END IF;
          EXCEPTION WHEN NO_DATA_FOUND THEN
               pl_log.ins_msg('INFO',lv_fname,
                'There is no pending replenishment task '
                ||'for MSKU pallet '||i_pallet_id,NULL,NULL);
          END;
        END IF;
    END IF;

    RETURN status;

EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN',lv_fname,
            'Unable to validate for '
             ||'MSKU pallet '||i_pallet_id,NULL,NULL);
    RETURN status;
END f_val_multiple_pk;



/*-----------------------------------------------------------------------
-- Function:
--    f_update_msku_info_by_lp
--
-- Description:
--    This procedure will be used for updating PUTAWAYLST and INV whenever
--    there is a change in parent child information for a LP.  This is used
--    in the sub-divide functionality where a MSKU pallet is split.
--
--    Rules when sub-dividing:
--    1.  No new slot will be found for the LP for the item when:
--           a.  The LP is going to he home slot.
--           b.  The item is a floating item.
--           c.  The LP is going to the miniloader induction location.
--        This is done by NOT setting ERD_LPN.PALLET_ASSIGNED_FLAG to N.
--        The PUTAWAYLST record is not deleted.
--        Inventory is not changed.
--
--    2.  A new slot will be found (actually a potential new slot as the slot
--        found may be the same as the origial slot) for the LP for the item
--        when:
--           a.  The LP is going to a reserve slot and the item has a home
--               slot.
--           b.  The LP putaway task dest loc is *.
--        This is done by setting ERD_LPN.PALLET_ASSIGNED_FLAG to N
--        and if the dest loc is not * deleting the putaway task and
--        deleting the inventory record.
--
--    Later on in the MSKU-sub-divde processing procedure
--    p_assign_msku_putaway_slots() is called to find slots for records
--    on the SN with ERD_LPN.PALLET_ASSIGNED_FLAG set to N.  This creates the
--    putaway task and the inventory.
--    p_assign_msku_putaway_slots() does not look at any records with
--    ERD_LPN.PALLET_ASSIGNED_FLAG set to Y.
--
-- Parameters:
--         i_sn_number        shipment no.
--         i_parent_pallet_id can be the existing parent pallet id as in
--                            ERD_LPN table or can be a new pallet id.
--                            for example,in case we subdivide a MSKU pallet
--                            into two then one pallet will retain the old
--                            parent pallet id and one will be new
--         i_child_pallet_id  child pallet id which is or going to be a part
--                            of the parent pallet id.
--         i_pallet_type      pallet type of the MSKU pallets generated
--         i_indicator        indicates whether the subdivided pallet
--                            has a new parent pallet id.
--
-- Return Value:
--    TRUE  - If the sub-divide processed successfully.
--    FALSE - If there was an error in the sub-divide processing.
--
-- Called By:
--    - f_update_msku_info_by_item
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    10/25/04 prpbcb   Added call to delete_putaway_batch before
--                      deleting the putawaylst record.
---------------------------------------------------------------------*/
FUNCTION f_update_msku_info_by_lp
           (i_sn_number        IN erd_lpn.sn_no%TYPE,
            i_parent_pallet_id IN erd_lpn.parent_pallet_id%TYPE,
            i_child_pallet_id  IN erd_lpn.pallet_id%TYPE,
            i_pallet_type      IN erd_lpn.pallet_type%TYPE,
            i_indicator        IN VARCHAR2)
RETURN BOOLEAN
IS
   lv_fname         VARCHAR2(50)  := 'f_update_msku_info_by_lp';

   lv_dest_loc      putawaylst.dest_loc%TYPE;
   ln_qty_expected  putawaylst.qty_expected%TYPE;
   lv_perm          loc.perm%TYPE;
   lb_status        BOOLEAN := TRUE;
   lv_putaway_loc   putawaylst.dest_loc%TYPE;

   l_num_erd_lpn_recs_updated  PLS_INTEGER;  -- Keep track of number of
                                             -- ERD_LPN records updated.

   l_num_putawaylst_recs_updated  PLS_INTEGER;  -- Keep track of number of
                                                -- PUTAWAYLST records updated.

   e_finished_processing EXCEPTION;  -- Raised when wanting to get out of
                                     -- function without doing any more
                                     -- processing.

   --
   -- This cursor selects info about the child LP from ERD_LPN.
   --
   CURSOR c_erd_lpn_info(cp_child_lp  putawaylst.pallet_id%TYPE,
                         cp_sn_no     putawaylst.rec_id%TYPE)
   IS
      SELECT NVL(e.pallet_assigned_flag, 'N')  pallet_assigned_flag
        FROM erd_lpn e
       WHERE e.pallet_id    = cp_child_lp
         AND e.sn_no        = cp_sn_no;
         -- FOR UPDATE NOWAIT;   -- Lock the record  (Brian Bent Don't lock)

   --
   -- This cursor selects info about the child LP putaway task.
   --
   CURSOR c_putaway_task_info(cp_child_lp  putawaylst.pallet_id%TYPE,
                              cp_sn_no     putawaylst.rec_id%TYPE)
   IS
      SELECT p.dest_loc                        dest_loc,
             p.putaway_put                     putaway_put,
             p.prod_id                         prod_id,
             p.cust_pref_vendor                cust_pref_vendor,
             loc.perm                          perm
        FROM loc,
             putawaylst p
       WHERE p.pallet_id       = cp_child_lp
         AND p.rec_id          = cp_sn_no    -- Also match SN as a sanity check
         AND loc.logi_loc (+)  = p.dest_loc;
         -- FOR UPDATE OF p.dest_loc NOWAIT;   -- Lock the putawaylst record
                                               -- (Brian Bent Don't lock)

   r_erd_lpn_info       c_erd_lpn_info%ROWTYPE;
   r_putaway_task_info  c_putaway_task_info%ROWTYPE;
BEGIN
   --
   -- Create log message when starting.
   --
   pl_log.ins_msg('INFO', lv_fname,
                'Starting ' || lv_fname
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_indicator[' || i_indicator || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

   --
   -- Check for a null parameter.
   --
   IF (   i_sn_number         IS NULL
       OR i_parent_pallet_id  IS NULL
       OR i_child_pallet_id   IS NULL
       OR i_pallet_type       IS NULL
       OR i_indicator         IS NULL) THEN
         RAISE gl_e_parameter_null;
   END IF;

   --
   -- Get ERD_LPN info about the child LP.
   --
   OPEN c_erd_lpn_info(i_child_pallet_id, i_sn_number);
   FETCH c_erd_lpn_info INTO r_erd_lpn_info;

   IF (c_erd_lpn_info%NOTFOUND) THEN
      --
      -- Did not find the child LP in ERD_LPN.  This is an error.
      --
      CLOSE c_erd_lpn_info;

      --
      --  Log a message then return from the function with a failed status.
      --
      pl_log.ins_msg('FATAL', lv_fname,
                'TABLE=erd_lpn  KEY='
                || '(' || i_child_pallet_id || ')'
                || '(i_child_pallet_id)'
                || '  i_sn_number [' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=SELECT  MESSAGE='
                || 'Did not find the child LP.'
                || '  This is an error.',
                NULL, NULL, gl_application_func, gl_pkg_name);

      lb_status := FALSE;
      RETURN lb_status;
   ELSE
      CLOSE c_erd_lpn_info;
   END IF;

   --
   -- Always delete the forklift labor mgmt batch.  It will get re-created
   -- later in the processing.
   --
   delete_putaway_batch(i_child_pallet_id);

   --
   -- If the pallet has not been processed then do nothing.
   -- This is done by checking the ERD_LPN pallet assigned flag.  If it is
   -- 'N' then the child LP has not been processed.
   --
   IF (r_erd_lpn_info.pallet_assigned_flag = 'N') THEN
      --
      -- Child LP not processed.  There is nothing to do.
      --
      pl_log.ins_msg('INFO', lv_fname,
                '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  ERD_LPN.PALLET_ASSIGNED_FLAG is N so the'
                || '  child LP has not been processed.  There will be no'
                || '(should not be) putaway task or inventory so do nothing.',
                NULL, NULL, gl_application_func, gl_pkg_name);

      RAISE e_finished_processing;
   END IF;

   --
   -- Get putaway task info about the child LP.
   --
   OPEN c_putaway_task_info(i_child_pallet_id, i_sn_number);
   FETCH c_putaway_task_info INTO r_putaway_task_info;

   IF (c_putaway_task_info%NOTFOUND) THEN
      --
      -- Did not find the putaway task.  This is an error.
      --
      CLOSE c_putaway_task_info;

      --
      --  Log a message then return from the function with a failed status.
      --
      pl_log.ins_msg('FATAL', lv_fname,
                'TABLE=putawaylst  KEY='
                || '(' || i_sn_number || ','
                || i_child_pallet_id || ')'
                || '(i_sn_number,i_child_pallet_id)'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=SELECT  MESSAGE='
                || 'Did not find the child LP putaway task.'
                || '  This is an error.',
                NULL, NULL, gl_application_func, gl_pkg_name);

      lb_status := FALSE;
      RETURN lb_status;
   ELSE
      --
      -- Found the putaway task.
      -- Check that the dest_loc is a valid location.
      --
      CLOSE c_putaway_task_info;

      IF (    r_putaway_task_info.perm IS NULL
          AND r_putaway_task_info.dest_loc <> '*')  THEN
         --
         -- Did not find the dest loc in LOC.  This is an error.
         --
         pl_log.ins_msg('FATAL', lv_fname,
                'TABLE=loc  KEY='
                || '(' || r_putaway_task_info.dest_loc || ')'
                || '(r_putaway_task_info.dest_loc)'
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=SELECT  MESSAGE='
                || 'The dest loc is not a valid location.'
                || '  This is an error.',
                NULL, NULL, gl_application_func, gl_pkg_name);

         lb_status := FALSE;
         RETURN lb_status;
      END IF;
   END IF;

   --
   -- Log the item and dest loc.
   --
   pl_log.ins_msg('INFO', lv_fname,
                'r_putaway_task_info.prod_id['
                || r_putaway_task_info.prod_id || ']'
                || '  r_putaway_task_info.dest_loc['
                || r_putaway_task_info.dest_loc || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

   --
   -- If the child LP is putaway then do nothing.
   --
   IF (r_putaway_task_info.putaway_put = 'Y') THEN
      --
      -- Child LP putaway.  Leave the child LP alone.
      --
      pl_log.ins_msg('INFO', lv_fname,
                '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  The child LP is putaway.  It will be left alone.',
                NULL, NULL, gl_application_func, gl_pkg_name);

      RAISE e_finished_processing;
   END IF;


   --
   -- If a new parent LP is to be assigned to the child LP then update
   -- ERD_LPN and PUTAWAYLST tables.
   --
   IF (i_indicator = 'Y') THEN
      --
      -- Assign the new parent LP to the child LP in the ERD_LPN table.
      --
      UPDATE erd_lpn
         SET parent_pallet_id = i_parent_pallet_id
       WHERE pallet_id = i_child_pallet_id
         AND sn_no     = i_sn_number;
         --
         --  7/7/2009 Brian Bent  Don't need this in WHERE clause because
         --           this point in processing reached only if the
         --           child LP is not putaway.
         -- If a LP putaway, which could happen if OpCo puts away some
         -- of the LPs then decides to sub-divide, then leave the LP alone.
         --
         -- AND NOT EXISTS
         --         (SELECT 'x'
         --            FROM putawaylst p
         --           WHERE p.pallet_id        = erd_lpn.pallet_id
         --             AND p.rec_id           = erd_lpn.sn_no
         --             AND p.putaway_put      = 'Y');

      --
      -- Save the number of ERD_LPN records updated (should be 1).
      -- It will be compared against the number of PUTAWAYLST records updated.
      --
      l_num_erd_lpn_recs_updated := SQL%ROWCOUNT;

      pl_log.ins_msg('INFO',lv_fname,
                'TABLE=erd_lpn  KEY='
                || '(' || i_sn_number || ','
                || i_child_pallet_id || ')'
                || '(i_sn_number,i_child_pallet_id)'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=UPDATE  MESSAGE='
                || 'Update of parent_pallet_id for LP not putaway.'
                || '  Number of records updated['
                || TO_CHAR(l_num_erd_lpn_recs_updated) || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

      --
      -- Assign the new parent LP to the child LP in the PUTAWAYLST table.
      --
      UPDATE putawaylst
         SET parent_pallet_id = i_parent_pallet_id
       WHERE pallet_id   = i_child_pallet_id
         AND rec_id      = i_sn_number;
         --
         --  7/7/2009 Brian Bent  Don't need this in WHERE clause because
         --           this point in processing reached only if the
         --           child LP is not putaway.
         -- AND putaway_put = 'N';   -- Only update LPs not putaway

      --
      -- Save the number of PUTAWAYLST records updated (should be 1).
      -- It will be compared against the number of ERD_LPN records updated.
      --
      l_num_putawaylst_recs_updated := SQL%ROWCOUNT;

      pl_log.ins_msg('INFO', lv_fname,
                'TABLE=putawaylst  KEY='
                || '(' || i_sn_number || ','
                || i_child_pallet_id || ')'
                || '(i_sn_number,i_child_pallet_id)'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=UPDATE  MESSAGE='
                || 'Update of parent_pallet_id for LP not putaway.'
                || '  Number of records updated['
                || TO_CHAR(l_num_putawaylst_recs_updated) || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

      --
      -- The number of ERD_LPN records updated and the number of PUTAWAYLST
      -- records updated need to be the same.
      --
      IF (l_num_erd_lpn_recs_updated  <> l_num_putawaylst_recs_updated) THEN
         --
         -- The number of ERD_LPN records updated and the number of PUTAWAYLST
         -- records updated are not the same.  This is an error.
         --
         pl_log.ins_msg('FATAL', lv_fname,
                'i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  Number of ERD_LPN records updated['
                || TO_CHAR(l_num_putawaylst_recs_updated) || ']'
                || '  not same as number of PUTAWAYLST records updated['
                || TO_CHAR(l_num_putawaylst_recs_updated) || ']'
                || '  This is an error as the number of records updated'
                || ' should be the same.',
                NULL, NULL, gl_application_func, gl_pkg_name);

         lb_status := FALSE;
         RETURN lb_status;
      END IF;
   END IF;  -- end IF (i_indicator = 'Y')


   --
   -- At this point the parent pallet id has been updated if appropriate.
   -- Now do the following if the child LP is going to a reserve slot and
   -- the item has a home slot OR the child LP dest loc is *.
   --    1. Delete the inventory if the dest loc is <> *.
   --    2. Delete the putaway task.
   --    3. Set the ERD_LPN.PALLET_ASSIGNED_FLAG to N.
   --

   --
   -- If the child LP is going to the miniloader induction location then
   -- leave the putaway task and inventory alone.
   --
   IF (pl_ml_common.f_is_induction_loc(r_putaway_task_info.dest_loc) = 'Y')
   THEN
      --
      -- Child LP going to the miniloader induction location.  There is nothing
      -- else to do.  Do not clear the putaway task and inventory.
      --
      pl_log.ins_msg('INFO', lv_fname,
                '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  Child LP going to the miniload induction location.'
                || '  Leave putaway task and inventory alone.',
                NULL, NULL, gl_application_func, gl_pkg_name);

      RAISE e_finished_processing;
   END IF;

   --
   -- If the child LP is going to a reserve slot and
   -- the item has a home slot OR the child LP dest loc is * then do the
   -- following:
   --    1. Delete the inventory if the dest loc is <> *.
   --    2. Delete the putaway task.
   --    3. Set the ERD_LPN.PALLET_ASSIGNED_FLAG to N.
   --
   IF (      ((item_has_case_home_slot
                        (r_putaway_task_info.prod_id,
                         r_putaway_task_info.cust_pref_vendor) = TRUE)
              AND r_putaway_task_info.perm = 'N')
        OR (r_putaway_task_info.dest_loc = '*'))
   THEN
      --
      -- Item has a home slot and the the child LP is going to reserve
      -- OR the dest loc is *.
      --
      -- Log what will take place.
      --
      pl_log.ins_msg('INFO', lv_fname,
                'Item[' || r_putaway_task_info.prod_id || ']'
                || ' has a case home slot, child LP['
                || i_child_pallet_id || '] is going to reserve'
                || ' OR dest loc[' || r_putaway_task_info.dest_loc
                || '] is *.'
                || '  Delete inv(if dest loc not *), delete putaway task'
                || ' and set pallet_assigned_flag to N',
                NULL, NULL, gl_application_func, gl_pkg_name);

      --
      -- Delete inventory if dest loc is not *.
      --
      IF (r_putaway_task_info.dest_loc <> '*') THEN
         DELETE FROM inv
          WHERE inv.logi_loc         = i_child_pallet_id
            AND inv.qoh              = 0
            AND inv.prod_id          = r_putaway_task_info.prod_id
            AND inv.cust_pref_vendor = r_putaway_task_info.cust_pref_vendor;

         IF (SQL%ROWCOUNT = 0) THEN
            pl_log.ins_msg('FATAL', lv_fname,
                'TABLE=inv  KEY='
                || '[' || i_child_pallet_id || ']'
                || '[' || r_putaway_task_info.prod_id || ']'
                || '[' || r_putaway_task_info.cust_pref_vendor || ']'
                || '[qoh=0]'
                || '(i_child_pallet_id,prod_id,cpv)'
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=DELETE  MESSAGE=Delete failed.'
                || '  Did not find child LP in inventory or the child LP'
                || ' is in inventory with another item or the child LP'
                || ' is in inventory with qoh > 0.',
                NULL, NULL, gl_application_func, gl_pkg_name);

            lb_status := FALSE;
            RAISE e_finished_processing;
         ELSE
            --
            -- Inventory record deleted successfully.  Log this.
            --
            pl_log.ins_msg('INFO', lv_fname,
                'TABLE=inv  KEY='
                || '(' || i_child_pallet_id || ','
                || r_putaway_task_info.prod_id || ','
                || r_putaway_task_info.cust_pref_vendor || ','
                || 'qoh=0)'
                || '(i_child_pallet_id,prod_id,cpv)'
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  Location[' || r_putaway_task_info.dest_loc || ']'
                || '  ACTION=DELETE  MESSAGE=Inventory record deleted.',
                NULL, NULL, gl_application_func, gl_pkg_name);
         END IF;
      ELSE
         --
         -- r_putaway_task_info.dest_loc is a *.  There is no inventory
         -- to delete.
         --
         NULL;
      END IF;


      --
      -- Delete the putaway task for the child LP.
      --
      DELETE FROM putawaylst p
       WHERE p.pallet_id  = i_child_pallet_id
         AND p.rec_id     = i_sn_number;

         IF (SQL%ROWCOUNT = 0) THEN
            pl_log.ins_msg('FATAL', lv_fname,
                'TABLE=putawaylst  KEY='
                || '(' || i_child_pallet_id || ','
                || i_sn_number || ')'
                || '(i_child_pallet_id,i_sn_number)'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=DELETE  MESSAGE=Delete failed.'
                || '  Did not find the putaway task for the child LP',
                NULL, NULL, gl_application_func, gl_pkg_name);

            lb_status := FALSE;
            RAISE e_finished_processing;
         ELSE
            --
            -- Putaway task deleted successfully.  Log this.
            --
            pl_log.ins_msg('INFO', lv_fname,
                'TABLE=putawaylst  KEY='
                || '(' || i_child_pallet_id || ','
                || i_sn_number || ')'
                || '(i_child_pallet_id,i_sn_number)'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=DELETE  MESSAGE=Putaway task deleted.',
                NULL, NULL, gl_application_func, gl_pkg_name);
         END IF;

      --
      -- Update the pallet assigned flag to N.  This forces the erd_lpn
      -- record to be processed when we go back and finding putaway slots for
      -- the sub-divided MKSU.
      --
      UPDATE erd_lpn
         SET pallet_assigned_flag = 'N'
       WHERE pallet_id = i_child_pallet_id
         AND sn_no     = i_sn_number;

         IF (SQL%ROWCOUNT = 0) THEN
            pl_log.ins_msg('FATAL',lv_fname,
                'TABLE=erd_lpn  KEY='
                || '(' || i_child_pallet_id || ','
                || i_sn_number || ')'
                || '(i_child_pallet_id,i_sn_number)'
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=UPDATE  MESSAGE='
                || 'Did not find the ERD_LPN record for the child LP',
                NULL, NULL, gl_application_func, gl_pkg_name);

            lb_status := FALSE;
            RAISE e_finished_processing;
         ELSE
            --
            -- Pallet assigned flag updated successfully.  Log this.
            --
            pl_log.ins_msg('FATAL',lv_fname,
                'TABLE=erd_lpn  KEY='
                || '(' || i_child_pallet_id || ','
                || i_sn_number || ')'
                || '(i_child_pallet_id,i_sn_number)'
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  ACTION=UPDATE  MESSAGE='
                || 'pallet_assigned_flag set to N',
                NULL, NULL, gl_application_func, gl_pkg_name);
         END IF;
   ELSE
      --
      -- Child LP is:
      --   - Not going to reserve and the item has a home slot.
      --   - The dest loc is not *.
      -- So, the child LP is going to a home slot or the
      -- child LP is a floating item going to a slot.
      -- Leave the putaway task and inventory alone.
      -- Output log message.
      --
      pl_log.ins_msg('INFO', lv_fname,
                '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  Child LP is going to a home slot or the child LP'
                || ' is a floating item going to a slot.'
                || '  Leave putaway task and inventory alone.',
                NULL, NULL, gl_application_func, gl_pkg_name);

   END IF;  -- end if the child LP going to reserve and the item has a
            -- home slot OR the putaway task dest loc is *.

   RETURN lb_status;
EXCEPTION
   WHEN gl_e_parameter_null THEN
      pl_log.ins_msg('FATAL', lv_fname,
                'i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_indicator[' || i_indicator || ']'
                || '   A parameter is null',
                NULL, NULL, gl_application_func, gl_pkg_name);

      lb_status := FALSE;
      RETURN lb_status;

   WHEN e_finished_processing THEN
      RETURN lb_status;
   WHEN OTHERS THEN
      pl_log.ins_msg('FATAL', lv_fname,
                'i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_child_pallet_id[' || i_child_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_indicator[' || i_indicator || ']'
                || '   OTHERS exception',
                SQLCODE, SQLERRM, gl_application_func, gl_pkg_name);

      lb_status := FALSE;
      RETURN lb_status;
END f_update_msku_info_by_lp;


/*-----------------------------------------------------------------------
-- Function:
--    f_update_msku_info_by_item
--
-- Description:
--    This procedure is used to sub-divide an item on a MSKU.
--
--    The parent pallet of the item is updated in ERD_LPN and PUTAWAYLST
--    if i_indicator is set to Y.  Procedure f_udpate_msku_info_by_lp() is
--    then called for each child LP on the original parent LP and the new
--    parent LP to do the rest of the sub-divide processing.
--
--
-- Parameters:
--         i_sn_number        shipment no.
--         i_parent_pallet_id can be the existing parent pallet id as in
--                            ERD_LPN table or can be a new pallet id.
--                            for example,in case we subdivide a MSKU pallet
--                            into two then one pallet will retain the old
--                            parent pallet id and one will be new
--         i_pallet_type      pallet type of the MSKU pallets generated
--       i_prod_id         item # needs to be grouped in the new parent
--                 pallet id.
--         i_original_parent_pallet_id  Parent pallet id for the item.
--                                      This may be the same as
--                                      i_parent_pallet_id.  We need this
--                                      for the update where clause because
--                                      an item can be on different MSKUs on
--                                      the same SN and we need to only
--                                      update records for the parent LP
--                                      being processed.
--         i_indicator        indicates whether the subdivided pallet
--                            has a new parent pallet id.
--
-- RETURN VALUES                  - STATUS
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    11/30/04 prppxx   Added this function to sub_divide MSKU pallets by
--                      item. DN 11812
--
--    07/10/00 prpbcb   Fix sub-divide bug.  Changed to call
--                      f_update_msku_info_by_lp
---------------------------------------------------------------------*/
FUNCTION f_update_msku_info_by_item
         (i_sn_number                  IN erd_lpn.sn_no%type,
          i_parent_pallet_id           IN erd_lpn.parent_pallet_id%TYPE,
          i_pallet_type                IN erd_lpn.pallet_type%TYPE,
          i_prod_id                    IN erd_lpn.prod_id%TYPE,
          i_original_parent_pallet_id  IN erd_lpn.parent_pallet_id%TYPE,
          i_indicator                  IN VARCHAR2)
RETURN BOOLEAN
IS
   lv_fname         VARCHAR2(50)  := 'f_update_msku_info_by_item';

   lv_dest_loc      putawaylst.dest_loc%TYPE;
   ln_qty_expected  putawaylst.qty_expected%TYPE;
   lb_status        BOOLEAN := TRUE;

   l_num_erd_lpn_recs_updated  PLS_INTEGER;  -- Keep track of number of
                                                -- records updated.

   l_num_putawaylst_recs_updated  PLS_INTEGER;  -- Keep track of number of
                                                -- records updated.

   --
   -- This cursor selects the child LP's for the item.
   -- For each child LP selected procedure f_udpate_msku_info_by_lp()
   -- is called.
   --
   CURSOR c_sub_divide_by_item
               (cp_sn_number                  erd_lpn.sn_no%TYPE,
                cp_prod_id                    erd_lpn.prod_id%TYPE,
                cp_parent_pallet_id           erd_lpn.parent_pallet_id%TYPE,
                cp_original_parent_pallet_id  erd_lpn.parent_pallet_id%TYPE)
   IS
   SELECT p.pallet_id         pallet_id,
          p.parent_pallet_id  parent_pallet_id
     FROM erd_lpn,
          putawaylst p
    WHERE p.rec_id                     = cp_sn_number
      AND p.prod_id                    = cp_prod_id
      AND p.parent_pallet_id           IN (cp_original_parent_pallet_id,
                                           cp_parent_pallet_id)
      AND erd_lpn.sn_no                = p.rec_id
      AND erd_lpn.prod_id              = p.prod_id
      AND erd_lpn.cust_pref_vendor     = p.cust_pref_vendor
      AND erd_lpn.pallet_id            = p.pallet_id
   ORDER BY p.dest_loc ASC;

BEGIN
   --
   -- Log messages to note what is happening.
   --
   pl_log.ins_msg('INFO', lv_fname,
                'Starting ' || lv_fname
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_prod_id[' || i_prod_id || ']'
                || '  i_original_parent_pallet_id['
                || i_original_parent_pallet_id || ']'
                || '  i_indicator[' || i_indicator || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

   pl_log.ins_msg('INFO', lv_fname,
                 'If i_indicator is Y then update the parent LP in tables'
                 || ' ERD_LPN and PUTAWAYLST from '
                 || i_original_parent_pallet_id || ' to '
                 || i_parent_pallet_id
                 || ' for item ' || i_prod_id || '.'
                 || '  Then do the following for the child LPs for the item'
                 || ' on both the original parent LP and the new parent LP'
                 || '(note that the item will either be on the original'
                 || ' parent LP or new parent)'
                 || ' if the child LP is going to a reserve slot and the'
                 || ' item has a home slot OR the child dest loc is *:'
                 || '  (1) Delete the inventory if the dest loc is not *.'
                 || '  (2) Delete the putaway task.'
                 || '  (3) Set the ERD_LPN.PALLET_ASSIGNED_FLAG to N.'
                 || '    Other than possibly updating the parent LP'
                 || ' nothing is done to the putaway task or inventory for'
                 || ' child LP going to a home slot, child LP for a floating'
                 || ' item going to a slot or child LP going to the'
                 || ' miniload induction location.',
                NULL, NULL, gl_application_func, gl_pkg_name);

   --
   -- Check for null parameter.
   --
   IF (   i_sn_number                  IS NULL
       OR i_parent_pallet_id           IS NULL
       OR i_prod_id                   IS NULL
       OR i_pallet_type                IS NULL
       OR i_original_parent_pallet_id  IS NULL
       OR i_indicator                  IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- First thing to do is assign the new parent LP to the item.
   --
   IF (i_indicator = 'Y') THEN
      --
      -- Assign the new parent LP to the item.
      --
      -- Two tables to update:
      --    ERD_LPN
      --    PUTAWAYLST
      --
      UPDATE erd_lpn
         SET parent_pallet_id = i_parent_pallet_id
       WHERE prod_id          = i_prod_id
         AND sn_no            = i_sn_number
         AND parent_pallet_id = i_original_parent_pallet_id
         --
         -- If a LP putaway, which could happen if OpCo puts away some
         -- of the LPs then decides to sub-divide, then leave the LP alone.
         --
         AND NOT EXISTS
              (SELECT 'x'
                 FROM putawaylst p
                WHERE p.pallet_id        = erd_lpn.pallet_id
                  AND p.rec_id           = erd_lpn.sn_no
                  AND p.prod_id          = erd_lpn.prod_id
                  AND p.cust_pref_vendor = erd_lpn.cust_pref_vendor
                  AND p.putaway_put      = 'Y');

      --
      -- Save the number of ERD_LPN records updated.  It will be compared
      -- against the number of PUTAWAYLST records updated.
      --
      l_num_erd_lpn_recs_updated := SQL%ROWCOUNT;

      pl_log.ins_msg('INFO', lv_fname,
                'TABLE=erd_lpn'
                || '  KEY=(' || i_sn_number || ',' || i_prod_id || ','
                || i_original_parent_pallet_id || ')'
                || '(i_sn_number,i_prod_id,i_original_parent_pallet_id)'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_indicator[' || i_indicator || ']'
                ||'  ACTION=UPDATE  MESSAGE=Update parent pallet id['
                || i_original_parent_pallet_id || '] to ['
                || i_parent_pallet_id || ']'
                || '  Number of records updated['
                || TO_CHAR(l_num_erd_lpn_recs_updated) || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

      UPDATE putawaylst
         SET parent_pallet_id = i_parent_pallet_id
       WHERE prod_id           = i_prod_id
         AND rec_id            = i_sn_number
         AND parent_pallet_id  = i_original_parent_pallet_id
         AND putaway_put       = 'N';  -- Only update LPs not putaway

      --
      -- Save the number of PUTAWAYLST records updated.  It will be compared
      -- against the number of ERD_LPN records updated.
      --
      l_num_putawaylst_recs_updated := SQL%ROWCOUNT;

      pl_log.ins_msg('INFO', lv_fname,
                'TABLE=putawaylst'
                || '  KEY=(' || i_sn_number || ',' || i_prod_id || ','
                || i_original_parent_pallet_id || ')'
                || '(i_sn_number,i_prod_id,i_original_parent_pallet_id)'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_indicator[' || i_indicator || ']'
                ||'  ACTION=UPDATE  MESSAGE=Update parent pallet id['
                || i_original_parent_pallet_id || '] to ['
                || i_parent_pallet_id || ']'
                || '  Number of records updated['
                || TO_CHAR(l_num_putawaylst_recs_updated) || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

      --
      -- The number of ERD_LPN records updated and the number of PUTAWAYLST
      -- records updated need to be the same.
      --
      IF (l_num_erd_lpn_recs_updated  <> l_num_putawaylst_recs_updated) THEN
         --
         -- The number of ERD_LPN records updated and the number of PUTAWAYLST
         -- records updated are not the same.  This is an error.
         --
         pl_log.ins_msg('FATAL', lv_fname,
                'i_sn_number[' || i_sn_number || ']'
                || '  i_prod_id[' || i_prod_id || ']'
                || '  i_original_parent_pallet_id['
                || i_original_parent_pallet_id || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_indicator[' || i_indicator || ']'
                || '  Number of ERD_LPN records updated['
                || TO_CHAR(l_num_putawaylst_recs_updated) || ']'
                || '  not same as number of PUTAWAYLST records updated['
                || TO_CHAR(l_num_putawaylst_recs_updated) || ']'
                || '  This is an error as the number of records updated'
                || ' should be the same.',
                NULL, NULL, gl_application_func, gl_pkg_name);

         lb_status := FALSE;
         RETURN lb_status;
      END IF;

   END IF;  -- end IF (i_indicator = 'Y')

   --
   -- Now do the following for the child LPs on both the original parent LP
   -- and the new parent LP:
   --    -  If the child LP is going to a reserve slot and the item has a home
   --       slot or the child dest loc is * then
   --          1. Delete the inventory if the dest loc is not *.
   --          2. Delete the putaway task.
   --          3. Set the ERD_LPN.PALLET_ASSIGNED_FLAG to N.
   --
   -- Procedure f_udpate_msku_info_by_lp is called to do the work.
   --
   FOR r_sub_divide_by_item in c_sub_divide_by_item
                                         (i_sn_number,
                                          i_prod_id,
                                          i_parent_pallet_id,
                                          i_original_parent_pallet_id)
   LOOP
      pl_log.ins_msg('INFO', lv_fname,
                'Before call to f_update_msku_info_by_lp'
                || '  prod_id[' || i_prod_id || ']'
                || '  r_sub_divide_by_item.parent_pallet_id['
                || r_sub_divide_by_item.parent_pallet_id || ']'
                || '  r_sub_divide_by_item.pallet_id['
                || r_sub_divide_by_item.pallet_id || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

      lb_status := f_update_msku_info_by_lp
                                 (i_sn_number,
                                  r_sub_divide_by_item.parent_pallet_id,
                                  r_sub_divide_by_item.pallet_id,
                                  i_pallet_type,
                                  'N');

      IF (lb_status = FALSE)
         THEN EXIT;    -- Got an error in f_update_msku_info_by_lp
      END IF;
   END LOOP;

   pl_log.ins_msg('INFO', lv_fname,
                'Leaving ' || lv_fname
                || '  i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_prod_id[' || i_prod_id || ']'
                || '  i_original_parent_pallet_id['
                || i_original_parent_pallet_id || ']'
                || '  i_indicator[' || i_indicator || ']',
                NULL, NULL, gl_application_func, gl_pkg_name);

   RETURN lb_status;
EXCEPTION
   WHEN gl_e_parameter_null THEN
      pl_log.ins_msg('FATAL', lv_fname,
                'i_sn_number[' || i_sn_number || ']'
                || '  i_parent_pallet_id[' || i_parent_pallet_id || ']'
                || '  i_pallet_type[' || i_pallet_type || ']'
                || '  i_prod_id[' || i_prod_id || ']'
                || '  i_original_parent_pallet_id['
                || i_original_parent_pallet_id || ']'
                || '  i_indicator[' || i_indicator || ']'
                || '  A parameter is null',
                NULL, NULL, gl_application_func, gl_pkg_name);

      lb_status := FALSE;
      RETURN lb_status;

END f_update_msku_info_by_item;


/*-----------------------------------------------------------------------
   -- Function:
   --    f_substitute_msku_pallet
   --
   -- Description:During replenishment(demand or non-demand) from a MSKU pallet
   --             there maybe cases the user might scan the wrong pallet id.
   --             At this point if the pallet id that has
   --             been scanned and the pallet id to be scanned have the same
   --             product with the same expiry date in the inventory then
   --             they can be substituted.

   -- Parameters:
   --               i_pallet_id  scanned pallet_id
   --               i_dest_loc   scanned physical location
   --               i_type       whether NDM or DMD replenishment
   --               i_task_id    Task id of the LP which has replenishment.
   --               o_pallet_id  LP with which the input pallet id has been
   --                            substituted.

   -- RETURN VALUES                  - STATUS
---------------------------------------------------------------------*/
FUNCTION f_substitute_msku_pallet(
            i_pallet_id        IN erd_lpn.pallet_id%TYPE,
            i_type             IN VARCHAR2,
            i_task_id          IN replenlst.task_id%TYPE,
            o_pallet_id        OUT erd_lpn.pallet_id%TYPE)
RETURN BOOLEAN
IS
lv_prod_id            putawaylst.prod_id%TYPE;
lv_task_prod_id       putawaylst.prod_id%TYPE;
lv_cpv                putawaylst.cust_pref_vendor%TYPE;
ld_exp_date           putawaylst.exp_date%TYPE;
lv_lot_id             putawaylst.lot_id%TYPE;
ln_qty_received       putawaylst.qty_received%TYPE;
ln_qty                replenlst.qty%TYPE;
lv_dest_loc           putawaylst.dest_loc%TYPE;
lv_task_dest_loc      putawaylst.dest_loc%TYPE;
lv_parent_pallet_id   putawaylst.parent_pallet_id%TYPE;
lv_task_parent_pallet putawaylst.parent_pallet_id%TYPE;
lv_substitute_lp      putawaylst.pallet_id%TYPE;
lv_pallet_id          putawaylst.pallet_id%TYPE;
lv_perm1              loc.perm%TYPE;
lv_perm2              loc.perm%TYPE;
lv_fname              VARCHAR2(50)  := 'f_substitute_msku_pallet';
lv_spc              pm.spc%TYPE;
lb_status             BOOLEAN := FALSE;
lb_replenlst_swap     BOOLEAN := FALSE;
dummy                 VARCHAR2(1);
lv_substitute_taskid  replenlst.task_id%type;
lv_substitute_float   replenlst.float_no%type;
BEGIN
   IF i_pallet_id IS NULL OR i_task_id IS NULL OR i_type IS NULL THEN
      pl_log.ins_msg('INFO',lv_fname,
                              'TABLE=none KEY=['
                              ||i_pallet_id ||'],['
                              ||i_task_id||'],['
                              ||i_type ||']'
                              ||' ACTION=none REASON='
                              ||'one of the arguments passed is null'
                              ,NULL,NULL);
      lb_status := FALSE;
      RETURN lb_status;
   END IF;

         --There are three possibilities which are
         --  handled by the following functionality:
         -- 1)as per the replenlst pallet scanned should
         --   go  to the scanned location:
         --   in this case the function returns true without
         --   any further processing.
         -- 2)The scanned pallet is supposed to go to some other
         --   location as per replenlst:
         --   in this case, if there are no replenishment tasks for
         --   the scanned location then function returns false else
         --   a swap with  the/one of the pallet(s) supposed to go
         --   to the scanned location is attempted
         -- 3) The scanned pallet is not a part of any replenishment
         --   task:
         --   in this case if there are no replenishment tasks for
         --   the scanned location then function returns false else
         --   a swap with  the/one of the pallet(s) supposed to go
         --   to the scanned location is attempted

         BEGIN
      /*Select the details like pallet_id,dest_loc
        based on the input task id.*/

           SELECT parent_pallet_id, pallet_id, r.prod_id, dest_loc, spc
             INTO lv_task_parent_pallet,lv_pallet_id,lv_task_prod_id,lv_task_dest_loc, lv_spc
             FROM pm p, replenlst r
            WHERE task_id= i_task_id
              AND r.status = 'PIK'
          AND p.prod_id = r.prod_id
          AND p.cust_pref_vendor = r.cust_pref_vendor;

           /*If the input pallet id and pallet id selected based on task_id are same
         then substitution is not required */

           IF lv_pallet_id = i_pallet_id THEN
              --no substitution required
              o_pallet_id := NULL;
              lb_status := TRUE;
              RETURN lb_status;
           END IF;
         EXCEPTION
         WHEN OTHERS THEN
           pl_log.ins_msg('INFO',lv_fname,
                                'TABLE=replenlst KEY=['
                              ||i_task_id||']'
                              ||' ACTION=SELECT REASON='
                              ||' Select failed for this '
                              ||'task id'
                              ,NULL,SQLCODE);

          lb_status := FALSE;
          RETURN lb_status;
        END;
        BEGIN
    /*Select details for the scanned pallet id */
            SELECT prod_id,
                   cust_pref_vendor,
                   exp_date,
                   qty,
                   dest_loc,
                   parent_pallet_id
             INTO lv_prod_id,
                  lv_cpv,
                  ld_exp_date,
                  ln_qty,
                  lv_dest_loc,
                  lv_parent_pallet_id
              FROM replenlst
              WHERE pallet_id = i_pallet_id;


              lb_replenlst_swap := TRUE;


        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            BEGIN
               lb_replenlst_swap := FALSE;
              /* This is when scanned LP does not have any replenishments.
             In this case retrieve the data from inv. table.*/
               SELECT prod_id,
                      cust_pref_vendor,
                      exp_date,
                      lot_id,
                      qoh,
                     parent_pallet_id
                INTO lv_prod_id,
                     lv_cpv,
                     ld_exp_date,
                     lv_lot_id,
                     ln_qty,
                     lv_parent_pallet_id
                FROM inv
               WHERE logi_loc = i_pallet_id;

            EXCEPTION
            WHEN NO_DATA_FOUND THEN
               pl_log.ins_msg('INFO',lv_fname,
                                    'TABLE=inv KEY=['
                                    ||i_pallet_id ||
                                    ' ACTION=SELECT REASON='
                                    ||' pallet doesn''t exist'
                                    ,NULL,SQLCODE);

               lb_status := FALSE;
               RETURN lb_status;
            WHEN OTHERS THEN
               pl_log.ins_msg('INFO',lv_fname,
                                    'TABLE=inv KEY=['
                                    ||i_pallet_id ||
                                    ' ACTION=SELECT REASON='
                                    ||'Unable to select from inv'
                                    ,NULL,SQLCODE);

               lb_status := FALSE;
               RETURN lb_status;
            END;
         WHEN OTHERS THEN
            pl_log.ins_msg('INFO',lv_fname,
                                'TABLE=replenlst KEY=['
                                ||i_pallet_id ||
                                ' ACTION=SELECT REASON='
                                ||'Unable to select from replenlst'
                                ,NULL,SQLCODE);

            lb_status := FALSE;
            RETURN lb_status;
         END;

         /* In case the products of scanned pallet id and the pallet id selected based on task id
       are different then throw the error.
       */

         IF (lv_prod_id <> lv_task_prod_id)THEN

            pl_log.ins_msg('INFO',lv_fname,
                                 'KEY=Prod id for scanned pallet:['
                                 ||lv_prod_id||']Prod id based on task id: ['
                                 ||lv_task_prod_id || ']'
                                 ||' REASON='
                                 ||' Products are different.'
                                 ,NULL,SQLCODE);

            lb_status := FALSE;
            RETURN lb_status;
         END IF;
     /* Check whether the scanned LP and LP against the task_id are on the same parent pallet
        or not.*/
          IF lv_parent_pallet_id <> lv_task_parent_pallet THEN

            pl_log.ins_msg('INFO',lv_fname,
                                 'KEY=Parent pallet id for scanned pallet:['
                                 ||lv_parent_pallet_id||']Paernt pallet id based on task id: ['
                                 ||lv_task_parent_pallet || ']'
                                 ||' REASON='
                                 ||' Scanned pallet and the pallet based on task id on diff. MSKU pallets.'
                                 ,NULL,SQLCODE);

            lb_status := FALSE;
            RETURN lb_status;

      END IF;


         /*If all the validations are through, then pick the LP with which scanned LP
       can be substituted */

         BEGIN


                 IF i_type = 'NDM' THEN
                       SELECT task_id,pallet_id
                       INTO lv_substitute_taskid,lv_substitute_lp
                       FROM replenlst,pm,inv
                       WHERE pm.prod_id = replenlst.prod_id
               AND pm.cust_pref_vendor = replenlst.cust_pref_vendor
                       AND replenlst.dest_loc=lv_task_dest_loc
                       AND pm.prod_id=lv_prod_id
                       AND pm.cust_pref_vendor =lv_cpv
                       AND replenlst.pallet_id = inv.logi_loc
                       AND replenlst.status = 'PIK'
                       AND NVL(trunc(inv.exp_date),SYSDATE)
                            =NVL(trunc(ld_exp_date),SYSDATE)
                       AND (NVL(pm.lot_trk,'N') = 'N' OR (NVL(pm.lot_trk,'N') = 'Y'
                             AND inv.lot_id = lv_lot_id))
                       AND qty = ln_qty
                       AND replenlst.parent_pallet_id = lv_parent_pallet_id
               AND replenlst.type='NDM'
                       AND ROWNUM=1;

                 /* For DMD replenishment lot_id check can not be done as inventory would have been
            already deleted by the order processing program so lot_id can not be
            retrieved from database.

            acpppp-
            Following query is for Demand replenishment.
            Qty for DMD replenishment task will be stored in cases in replenlst
            table. Hence divide the qty by spc while comparing.*/

                 ELSIF i_type='DMD' THEN
                       SELECT task_id,pallet_id,float_no
                       INTO lv_substitute_taskid,lv_substitute_lp,lv_substitute_float
                       FROM replenlst
                       WHERE replenlst.dest_loc=lv_task_dest_loc
                       AND replenlst.prod_id=lv_prod_id
                       AND replenlst.cust_pref_vendor =lv_cpv
                       AND replenlst.status = 'PIK'
                       AND NVL(trunc(replenlst.exp_date),SYSDATE)
                            =NVL(trunc(ld_exp_date),SYSDATE)
                       AND qty = ln_qty / DECODE (NVL (lv_spc, 0), 0, 1, lv_spc)
                       AND replenlst.parent_pallet_id = lv_parent_pallet_id
               AND replenlst.type='DMD'
                       AND ROWNUM=1;
                END IF;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  pl_log.ins_msg('INFO',lv_fname,
                                       'TABLE=replenlst KEY=[' ||
                    i_task_id || ', ' || i_pallet_id || ', ' || lv_task_dest_loc ||
                    ', ' || lv_prod_id || ', ' || lv_cpv ||
                    ', ' || ln_qty || ', ' || lv_parent_pallet_id ||
                    ', ' || ld_exp_date || ']  ACTION=SELECT REASON=' ||
                    'can''t substitute pallet since no ' ||
                    'matching pallet was found'
                                       ,NULL,SQLCODE);

                  lb_status := FALSE;
                  RETURN lb_status;
               WHEN OTHERS THEN
                  pl_log.ins_msg('INFO',lv_fname,
                                       'TABLE=replenlst KEY=['
                                       ||i_pallet_id ||
                                       ' ACTION=SELECT REASON='
                                       ||'Unable to select from replenlst'
                                       ,NULL,SQLCODE);

                  lb_status := FALSE;
                  RETURN lb_status;
            END;


           SAVEPOINT S;

       /*Delete the row from replenlst where task id is same as substitute task id.
         This record has to be deleted from replenishment table now.*/

       DELETE replenlst
        WHERE task_id = lv_substitute_taskid;

        IF SQL%NOTFOUND THEN
         pl_log.ins_msg('INFO',lv_fname,
                             'TABLE=replenlst KEY=['
                             ||lv_substitute_taskid ||']'
                             ||' ACTION=DELETE REASON='
                             ||'Unable to delete from replenlst'
                             ,NULL,SQLCODE);

            END IF;

           IF i_type = 'NDM' THEN
            BEGIN

         /*delete the inventory record
           where pallet_id equal to
           the substitute lp
              */
         DELETE from inv
          WHERE logi_loc= lv_substitute_lp;

         /* Update the inv record from scanned LP
            to substitute LP
         */

               UPDATE inv
                 SET logi_loc=lv_substitute_lp
               WHERE logi_loc = i_pallet_id;

              /* Update the Home slot inventory
          */
          UPDATE inv
             SET    qoh = qoh + ln_qty,
                qty_planned = qty_planned - ln_qty
           WHERE    plogi_loc = lv_task_dest_loc
         AND    logi_loc = plogi_loc;

               IF sql%NOTFOUND OR sql%ROWCOUNT = 0 THEN
             ROLLBACK TO S;
                 pl_log.ins_msg('INFO',lv_fname,
                                    'KEY=['
                                    ||lv_task_dest_loc ||
                                    ' ACTION=UPDATE REASON='
                                    ||'Unable to update Home inventory '
                                    ||SQLERRM
                                    ,NULL,SQLCODE);
                lb_status := FALSE;
                RETURN lb_status;
               END IF;


              UPDATE trans
                 SET pallet_id = i_pallet_id,
             trans_type= 'RPL',
             cmt       = lv_substitute_lp
               WHERE pallet_id = lv_substitute_lp
                 AND trans_type ='IND';

               IF sql%NOTFOUND OR sql%ROWCOUNT = 0 THEN
             ROLLBACK TO S;
                 pl_log.ins_msg('INFO',lv_fname,
                                    'KEY=['
                                    ||lv_substitute_lp ||
                                    ' ACTION=UPDATE REASON='
                                    ||'Unable to update IND transaction to RPL '
                                    ||SQLERRM
                                    ,NULL,SQLCODE);
                lb_status := FALSE;
                RETURN lb_status;
              END IF;
          /*If updates goes through fine Log the success message */
              pl_log.ins_msg('INFO',lv_fname,
                                    ' ACTION=UPDATE REASON='
                                    ||'All the NDM substitution updates completed successfully.'
                                    ,NULL,SQLCODE);

           EXCEPTION
           WHEN OTHERS THEN
               ROLLBACK TO S;
               pl_log.ins_msg('INFO',lv_fname,
                                    'KEY=['
                                    ||i_pallet_id ||
                                    ' ACTION=SELECT REASON='
                                    ||'unable to substitute pallet '
                                    ||SQLERRM
                                    ,NULL,SQLCODE);
               lb_status := FALSE;
               RETURN lb_status;
           END;

         ELSIF i_type = 'DMD' THEN

           BEGIN
              IF  lb_replenlst_swap = TRUE THEN
                  /* update the scanned LP to
             substitute LP */
                  UPDATE replenlst
                     SET pallet_id = lv_substitute_lp
                  WHERE pallet_id = i_pallet_id;

          /* Update the transactions */
                  UPDATE trans
                     SET pallet_id = i_pallet_id,
                 cmt = lv_substitute_lp
                   WHERE pallet_id = lv_substitute_lp
                     AND trans_type IN ('RPL','PFK','DFK');

                  /*INSERT INTO trans(trans_id,
                                    trans_type,
                                    trans_date,
                                    prod_id,
                                    pallet_id,
                                    dest_loc,
                                    exp_date,
                                    user_id,
                                    cmt,
                                    cust_pref_vendor,
                                    batch_no)
                            VALUES (trans_id_seq.NEXTVAL,
                                    'SPR',
                                    SYSDATE,
                                    lv_prod_id,
                                    i_pallet_id,
                                    lv_task_dest_loc,
                                    ld_exp_date,
                                    USER,
                                    'Old Pallet = '|| lv_substitute_lp
                                                   ||'substituted pallet = '
                                                   ||i_pallet_id,
                                     lv_cpv,
                                     0);--  function not yet complete.
                                                 --Updates to
                                                 --batch table have
                                                 --to be done and new
                                                 --batch no has to be
                                                 --inserted in the trans
                                                 --table. Currently we are
                                                 --inserting only
                                                 --dummy value.Need further
                                                 --inputs from client*/
              ELSE

                  /*Update the floats table */
          UPDATE floats
                     SET pallet_id = i_pallet_id
                   WHERE pallet_id = lv_substitute_lp
             AND float_no  = lv_substitute_float;
                  /*
            Update pallet id in inv to substitute
            LP.
          */
                  UPDATE inv
                  SET logi_loc = lv_substitute_lp
                  WHERE logi_loc = i_pallet_id;

                  /* Update the transactions */
                  UPDATE trans
                     SET pallet_id = i_pallet_id,
                 cmt = lv_substitute_lp
                   WHERE pallet_id = lv_substitute_lp
                     AND trans_type IN ('RPL','PFK','DFK');

                  /*INSERT INTO trans(trans_id,
                                    trans_type,
                                    trans_date,
                                    prod_id,
                                    pallet_id,
                                    dest_loc,
                                    exp_date,
                                    user_id,
                                    cmt,
                                    cust_pref_vendor,
                                    batch_no)
                            VALUES (trans_id_seq.NEXTVAL,
                                    'SPR',
                                    SYSDATE,
                                    lv_prod_id,
                                    i_pallet_id,
                                    lv_task_dest_loc,
                                    ld_exp_date,
                                    USER,
                                    'Old Pallet = '|| lv_substitute_lp
                                                   ||'substituted pallet = '
                                                   ||i_pallet_id,
                                     lv_cpv,
                                     0);--  function not yet complete.
                                                 --Updates to
                                                 --batch table have
                                                 --to be done and new
                                                 --batch no has to be
                                                 --inserted in the trans
                                                 --table. Currently we are
                                                 --inserting only
                                                 --dummy value.Need further
                                                 --inputs from client*/
           END IF;
           /*If updates goes through fine Log the success message */
           pl_log.ins_msg('INFO',lv_fname,
                          ' ACTION=UPDATE REASON='
                          ||'All the DMD substitution updates completed successfully.'
                          ,NULL,SQLCODE);
        EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO S;
            pl_log.ins_msg('INFO',lv_fname,
                                 'KEY=['
                                 ||i_pallet_id ||
                                 ' ACTION=SELECT REASON='
                                 ||'unable to substitute pallet '
                                 ||'SQLERRM='||SQLERRM
                                 ,NULL,SQLCODE);

            lb_status := FALSE;
            RETURN lb_status;
       END;

    END IF; -- demand or non demand replenishment

    /*acpppp-Insert the SPR transaction.*/
    INSERT INTO trans(trans_id,
                      trans_type,
                      trans_date,
                      prod_id,
                      pallet_id,
                      dest_loc,
                      exp_date,
                      user_id,
                      cmt,
                      cust_pref_vendor,
                      batch_no)
               VALUES (trans_id_seq.NEXTVAL,
                       'SPR',
                       SYSDATE,
                       lv_prod_id,
                       i_pallet_id,
                       lv_task_dest_loc,
                       ld_exp_date,
                       USER,
                       'Old Pallet = '|| lv_substitute_lp,
                       lv_cpv,
                       0);

    -- Update the labor mgmt batch ref# to reflect the substituted pallet.
    IF (i_type = 'NDM') THEN
       pl_lm_msku.pallet_substitution(pl_lmc.ct_forklift_nondemand_rpl,
                                      lv_substitute_lp, i_pallet_id);
    ELSIF (i_type = 'DMD') THEN
       pl_lm_msku.pallet_substitution(pl_lmc.ct_forklift_demand_rpl,
                                      lv_substitute_lp, i_pallet_id);
    ELSE
       NULL;  -- Have a value in i_type that will be ignored.
    END IF;

    --if all goes well, assign the pallet_id with which the input LP has been
    --substituted to the out parameter

o_pallet_id := lv_substitute_lp;
lb_status := TRUE;

RETURN lb_status;
END f_substitute_msku_pallet;
/*-----------------------------------------------------------------------
   -- Function:
   --    f_substitute_msku_pallet
   --
   -- Description:During putaway of a MSKU pallet to the
   --             home location or reserve location
   --             there maybe cases the user might scan the
   --             wrong pallet id. At this point if the pallet id that has
   --             been scanned and the pallet id to be scanned have the same
   --             product with the same expiry date in the inventory then
   --             they can be substituted.

   -- Parameters:
   --               i_pallet_id  scanned pallet_id
   --               i_dest_loc   scanned physical location
   --

   -- RETURN VALUES                  - STATUS
---------------------------------------------------------------------*/
FUNCTION f_substitute_msku_pallet(
            i_pallet_id        IN erd_lpn.pallet_id%TYPE,
            i_dest_loc         IN loc.logi_loc%TYPE)
RETURN BOOLEAN
IS
lv_prod_id            putawaylst.prod_id%TYPE;
lv_cpv                putawaylst.cust_pref_vendor%TYPE;
ld_exp_date           putawaylst.exp_date%TYPE;
lv_lot_id             putawaylst.lot_id%TYPE;
ln_qty_received       putawaylst.qty_received%TYPE;
ln_qty                replenlst.qty%TYPE;
lv_dest_loc           putawaylst.dest_loc%TYPE;
lv_parent_pallet_id   putawaylst.parent_pallet_id%TYPE;
lv_substitute_lp      putawaylst.pallet_id%TYPE;
lv_perm1              loc.perm%TYPE;
lv_perm2              loc.perm%TYPE;
lv_fname              VARCHAR2(50)  := 'f_substitute_msku_pallet';
lb_status             BOOLEAN := FALSE;
lb_replenlst_swap     BOOLEAN := FALSE;
lv_rec_id             putawaylst.rec_id%TYPE;
dummy                 VARCHAR2(1);
BEGIN
   IF i_pallet_id IS NULL OR i_dest_loc IS NULL THEN
      pl_log.ins_msg('INFO',lv_fname,
                              'TABLE=none KEY=['
                              ||i_pallet_id ||'],['
                              ||i_dest_loc||']'
                              ||' ACTION=none REASON='
                              ||'one of the arguments passed is null'
                              ,NULL,NULL);
      lb_status := FALSE;
      RETURN lb_status;
   END IF;

       BEGIN
         SELECT prod_id,
                cust_pref_vendor,
                exp_date,
                lot_id,
                qty_received,
                dest_loc,
                parent_pallet_id
          INTO lv_prod_id,
               lv_cpv,
               ld_exp_date,
               lv_lot_id,
               ln_qty_received,
               lv_dest_loc,
               lv_parent_pallet_id
           FROM putawaylst
           WHERE pallet_id = i_pallet_id;

        EXCEPTION
        WHEN NO_DATA_FOUND THEN
           pl_log.ins_msg('INFO',lv_fname,
                                'TABLE=putawaylst KEY=['
                                ||i_pallet_id ||'],['
                                ||i_dest_loc||']'
                                ||' ACTION=SELECT REASON='
                                ||'invalid pallet id, can''t substitute pallet'
                                ,NULL,SQLCODE);
           lb_status := FALSE;
           RETURN lb_status;
        WHEN OTHERS THEN
            pl_log.ins_msg('INFO',lv_fname,
                                'TABLE=putawaylst KEY=['
                                ||i_pallet_id ||'],['
                                ||i_dest_loc||']'
                                ||' ACTION=SELECT REASON='
                                ||'Unable to select from putawaylst'
                                ,NULL,SQLCODE);
            lb_status := FALSE;
            RETURN lb_status;
        END;
        --Check if Substitution is required at all. If the pallet is supposed to
        --go to the input location then substitution is not required.
        IF lv_dest_loc = i_dest_loc THEN
           lb_status := TRUE;
            pl_log.ins_msg('INFO',lv_fname,
                                  'TABLE=loc KEY=['
                                  ||i_dest_loc ||']'
                                  ||' ACTION=NONE REASON='
                                  ||'No substitution required '
                           ,NULL,SQLCODE);
           RETURN lb_status;
        ELSE
           BEGIN
                 SELECT perm
                 INTO lv_perm1
                 FROM loc
                 WHERE logi_loc = i_dest_loc;
              EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 pl_log.ins_msg('INFO',lv_fname,
                                      'TABLE=loc KEY=['
                                      ||i_dest_loc ||']'
                                      ||' ACTION=SELECT REASON='
                                      ||'input location doesn''t exist'
                                      ,NULL,SQLCODE);
                 lb_status := FALSE;
                 RETURN lb_status;
              WHEN OTHERS THEN
                 pl_log.ins_msg('INFO',lv_fname,
                                      'TABLE=loc KEY=['
                                      ||i_dest_loc ||']'
                                      ||' ACTION=SELECT REASON='
                                      ||'Unable to select from loc'
                                      ,NULL,SQLCODE);
                 lb_status := FALSE;
                 RETURN lb_status;
              END;

              BEGIN
                 SELECT perm
                 INTO lv_perm2
                 FROM loc
                 WHERE logi_loc = lv_dest_loc;
              EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 pl_log.ins_msg('INFO',lv_fname,
                                      'TABLE=loc KEY=['
                                      ||lv_dest_loc ||']'
                                      ||' ACTION=SELECT REASON='
                                      ||'input location doesn''t exist'
                                      ,NULL,SQLCODE);
                 lb_status := FALSE;
                 RETURN lb_status;
              WHEN OTHERS THEN
                 pl_log.ins_msg('INFO',lv_fname,
                                      'TABLE=loc KEY=['
                                      ||lv_dest_loc ||']'
                                      ||' ACTION=SELECT REASON='
                                      ||'Unable to select from loc'
                                      ,NULL,SQLCODE);
                 lb_status := FALSE;
                 RETURN lb_status;
            END;




           --Select a pallet if from putawaylst which is from the same parent pallet
            --that is still not putaway and whose expiry dates match and that is actually
            --supposed to go to the specified destination location.This pallet would
            --be suitable for substitution.


           BEGIN
               SELECT pallet_id,rec_id
               INTO lv_substitute_lp,lv_rec_id
               FROM putawaylst,pm
               WHERE pm.prod_id = putawaylst.prod_id
               AND dest_loc=i_dest_loc
               AND pm.prod_id=lv_prod_id
               AND pm.cust_pref_vendor =lv_cpv
               AND (((NVL(pm.fifo_trk,'N') = 'S'
                     OR NVL(pm.fifo_trk,'N') = 'A')
                    AND (NVL(trunc(exp_date),SYSDATE)
                    =NVL(trunc(ld_exp_date),SYSDATE)))
                    OR (NVL(pm.fifo_trk,'N') = 'N'))
               AND  ((NVL(pm.lot_trk,'N') = 'Y'
                     AND(NVL(lot_id,'0') = NVL(lv_lot_id,'0')))
                     OR (NVL(pm.lot_trk,'N') = 'N'))
               AND qty_received = ln_qty_received
               AND putaway_put='N'
               AND parent_pallet_id = lv_parent_pallet_id
               AND ROWNUM=1;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
               pl_log.ins_msg('INFO',lv_fname,
                                    'TABLE=putawaylst KEY=['
                                    ||i_pallet_id ||'],['
                                    ||i_dest_loc||']'
                                    ||' ACTION=SELECT REASON='
                                    ||'can''t substitute pallet since no '
                                    ||'matching pallet was found'
                                    ,NULL,SQLCODE);
               lb_status := FALSE;
               RETURN lb_status;
            WHEN OTHERS THEN
               pl_log.ins_msg('INFO',lv_fname,
                                    'TABLE=putawaylst KEY=['
                                    ||i_pallet_id ||'],['
                                    ||i_dest_loc||']'
                                    ||' ACTION=SELECT REASON='
                                    ||'Unable to select from putawaylst'
                                    ,NULL,SQLCODE);
               lb_status := FALSE;
               RETURN lb_status;
            END;

            SAVEPOINT S;

            UPDATE putawaylst
            SET dest_loc = i_dest_loc
            WHERE pallet_id = i_pallet_id;
            IF SQL%FOUND = FALSE THEN
               ROLLBACK TO S;
               pl_log.ins_msg('INFO',lv_fname,
                                    'TABLE=putawaylst KEY=['
                                    ||i_pallet_id ||'],['
                                    ||i_dest_loc||']'
                                    ||' ACTION=UPDATE REASON='
                                    ||'Record doesn''t exist in putawaylst '
                                    ||'for input pallet id ['
                                    ||i_pallet_id||']'
                                    ,NULL,SQLCODE);
               lb_status := FALSE;

               RETURN lb_status;
            END IF;

               BEGIN
                  UPDATE putawaylst
                     SET dest_loc = lv_dest_loc
                  WHERE pallet_id = lv_substitute_lp;
                  IF SQL%FOUND = FALSE THEN
                     ROLLBACK TO S;
                     pl_log.ins_msg('INFO',lv_fname,
                                          'TABLE=putawaylst KEY=['
                                          ||lv_substitute_lp ||'],['
                                          ||lv_dest_loc||']'
                                          ||' ACTION=UPDATE REASON='
                                          ||'Record doesn''t exist in putawaylst '
                                          ||'for substituted pallet id ['
                                          ||lv_substitute_lp||']'
                                          ,NULL,SQLCODE);
                    lb_status := FALSE;
                     RETURN lb_status;
                   END IF;
               EXCEPTION
               WHEN OTHERS THEN
                  ROLLBACK TO S;
                       pl_log.ins_msg('INFO',lv_fname,
                                      'TABLE=putawaylst KEY=['
                                       ||lv_substitute_lp ||'],['
                                       ||lv_dest_loc||']'
                                       ||' ACTION=UPDATE REASON='
                                       ||'Update of putawaylst failed '
                                       ||'for substituted pallet id ['
                                       ||lv_substitute_lp||']'
                                       ,NULL,SQLCODE);
                      lb_status := FALSE;
                  RETURN lb_status;
               END;



        --  the following code is based on the assumption that child pallets
        --  from a msku pallet can be put away to only those home slots which
        --  have rank 1,i.e. child pallets of an item on a msku pallet can't
        --  go to two different home slots thus if both perm1 and perm2 are
        --  'Y' or both are 'N' then no action is required since location in
        --  inv will be identical as we are substituting pallets
        --  within one msku pallet only


           IF lv_perm1 = 'Y' THEN
              IF lv_perm2 ='N' THEN
                 --substitute should go to home input pallet should
                 --go to reserve
                 BEGIN
                    UPDATE inv
                       SET logi_loc = lv_substitute_lp
                     WHERE logi_loc =i_pallet_id;

                    IF SQL%FOUND = FALSE THEN
                      ROLLBACK TO S;
                      pl_log.ins_msg('INFO',lv_fname,
                                           'TABLE=inv KEY=['
                                           ||i_pallet_id ||']'
                                           ||' ACTION=UPDATE REASON='
                                           ||'Record doesn''t exist in inv '
                                           ||'for input pallet id ['
                                           ||i_pallet_id||']'
                                           ,NULL,SQLCODE);
                        lb_status := FALSE;
                        RETURN lb_status;
                    END IF;
                 EXCEPTION
                 WHEN OTHERS THEN
                   ROLLBACK TO S;
                   pl_log.ins_msg('INFO',lv_fname,
                                          'TABLE=inv KEY=['
                                          ||i_pallet_id ||']'
                                          ||' ACTION=UPDATE REASON='
                                          ||'Update of inv failed '
                                          ||'for input pallet id ['
                                          ||i_pallet_id||']'
                                          ,NULL,SQLCODE);
                       lb_status := FALSE;
                       RETURN lb_status;
                 END;
              ELSIF lv_perm2 ='Y' THEN
                  NULL;--no action required this elsif condition is there
                       --just to check whether value of perm is valid or not
              ELSE
                 ROLLBACK TO S;
                 pl_log.ins_msg('INFO',lv_fname,
                                            'TABLE=loc KEY=['
                                            ||lv_dest_loc||']'
                                            ||' ACTION=SELECT REASON='
                                            ||'invalid value in PERM field'
                                             ,NULL,NULL);
                     lb_status := FALSE;
                     RETURN lb_status;
              END IF;
           ELSIF lv_perm1 = 'N' THEN
              IF lv_perm2 ='Y' THEN
                  --input pallet should go to home substitute should
                  --go to reserve
                 BEGIN
                     UPDATE inv
                       SET logi_loc = i_pallet_id
                       WHERE logi_loc =lv_substitute_lp;

                    IF SQL%FOUND = FALSE THEN
                       ROLLBACK TO S;
                       pl_log.ins_msg('INFO',lv_fname,
                                            'TABLE=inv KEY=['
                                            ||lv_substitute_lp ||']'
                                            ||' ACTION=UPDATE REASON='
                                            ||'Record doesn''t exist in inv '
                                            ||'for substituted pallet id ['
                                            ||lv_substitute_lp||']'
                                            ,NULL,SQLCODE);
                       lb_status := FALSE;
                     RETURN lb_status;

                     END IF;
                  EXCEPTION
                  WHEN OTHERS THEN
                     ROLLBACK TO S;
                     pl_log.ins_msg('INFO',lv_fname,
                                            'TABLE=inv KEY=['
                                            ||lv_substitute_lp ||']'
                                            ||' ACTION=UPDATE REASON='
                                            ||'Update of inv failed '
                                            ||'for substituted pallet id ['
                                            ||lv_substitute_lp||']'
                                            ,NULL,SQLCODE);
                     lb_status := FALSE;
                     RETURN lb_status;
                  END;
              ELSIF lv_perm2 ='N' THEN
               NULL;
              ELSE
                ROLLBACK TO S;
                pl_log.ins_msg('INFO',lv_fname,
                                          'TABLE=loc KEY=['
                                          ||lv_dest_loc||']'
                                          ||' ACTION=SELECT REASON='
                                          ||'invalid value in PERM field'
                                           ,NULL,NULL);
                  lb_status := FALSE;
                   RETURN lb_status;
              END IF;
           ELSE
               ROLLBACK TO S;
               pl_log.ins_msg('INFO',lv_fname,
                                       'TABLE=loc KEY=['
                                       ||i_dest_loc||']'
                                       ||' ACTION=SELECT REASON='
                                       ||'invalid value in PERM field'
                                        ,NULL,NULL);
               lb_status := FALSE;
                RETURN lb_status;
           END IF;--end updating inv

           --need  further clarification
       /*acpppp<11/04/03>
         1. Updated the comment so that it will
            just indicate old pallet id as new pallet id
            will be inserted in license # field
         2. sn_no inserted in "rec_id" field in trans table.
            Other fields like sn_no,po_no will be populated by trigger
            */
           BEGIN
           INSERT INTO trans (trans_id,
                              trans_type,
                              trans_date,
                              prod_id,
                  rec_id,
                              pallet_id,
                              dest_loc,
                              exp_date,
                              user_id,
                              cmt,
                              cust_pref_vendor,
                              batch_no)
             VALUES (trans_id_seq.NEXTVAL,
                     'SPR',
                     SYSDATE,
                     lv_prod_id,
             lv_rec_id,
                     i_pallet_id,
                     i_dest_loc,
                     ld_exp_date,
                     USER,
                     'Old Pallet = '|| lv_substitute_lp,
                      lv_cpv,
                      0);--  function not yet complete.Updates to
                                  --  batch table have to be done and new
                                  --  batch no has to be inserted in the trans
                                  --  table. Currently we are inserting only dummy
                                  --  value.Need further inputs from client

           -- Update the labor mgmt batch ref# to reflect the
           -- substituted pallet.
           pl_lm_msku.pallet_substitution(pl_lmc.ct_forklift_putaway,
                                          lv_substitute_lp, i_pallet_id);

           EXCEPTION
           WHEN OTHERS THEN
               ROLLBACK TO S;
               pl_log.ins_msg('INFO',lv_fname,
                                    'TABLE=trans KEY=['
                                    ||i_dest_loc||'],['
                                    ||lv_prod_id||'],['
                                    ||i_pallet_id ||']'
                                    ||' ACTION=INSERT REASON='
                                    ||'Unable to insert into trans table '
                                    ||'SQLERRM='||SQLERRM
                                     ,NULL,SQLCODE);
               lb_status := FALSE;
               RETURN lb_status;
           END;

        END IF;---end substitute


lb_status := TRUE;

RETURN lb_status;
END f_substitute_msku_pallet;

/*-----------------------------------------------------------------------
-- Procedure
--    p_sub_divide_msku_pallet
--
-- Description:
--    This procedure will be used when the user has selected the
--    SUB_DIVIDE option to divide a MSKU pallet during putaway
--
-- Parameters:
--    i_pallet_id            Pallet id
--    io_parent_pallet_id    Input parent pallet id
--    i_pallet_type          Pallet type
--    i_sub_divide_type
--    o_status               Output status
--
-- Exceptions raised:
--
---------------------------------------------------------------------*/
PROCEDURE p_sub_divide_msku_pallet
                (i_pallet_id         IN erd_lpn.pallet_id%TYPE,
                 io_parent_pallet_id IN OUT erd_lpn.parent_pallet_id%TYPE,
                 i_pallet_type       IN pallet_type.pallet_type%TYPE,
         i_sub_divide_type   IN VARCHAR2,
                 o_status            OUT NUMBER)
IS
  lv_pname                   VARCHAR2(50)  := 'p_sub_divide_msku_pallet';
  lv_sn_no                   erd_lpn.sn_no%TYPE;

  l_original_parent_pallet_id  erd_lpn.parent_pallet_id%TYPE;  -- Parent LP
                                                            -- for i_pallet_id

  lv_prod_id                 erd_lpn.prod_id%TYPE;
  ln_status                  NUMBER := 0;
  lb_status                  BOOLEAN;

  e_error_getting_pallet_id  EXCEPTION;
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_MSKU';
   --This will be used in the Exception message
   pl_putaway_utilities.gv_program_name := lv_pname;

   pl_log.ins_msg('INFO', lv_pname,
                 'Starting p_sub_divide_msku_pallet', NULL, NULL);

   pl_log.ins_msg('INFO', lv_pname,
             'i_pallet_id[' || i_pallet_id || ']'
             || '  io_parent_pallet_id[' || io_parent_pallet_id || ']'
             || '  i_pallet_type[' || i_pallet_type || ']'
             || '  i_sub_divide_type[' || i_sub_divide_type || ']',
             NULL, NULL,
             gl_application_func, gl_pkg_name);

   o_status := 0;

   IF io_parent_pallet_id IS NULL THEN
      pl_log.ins_msg ('INFO', lv_pname,
                 'Obtaining unique parent pallet id', NULL, NULL);

      --
      -- Get the new parent LP
      --
      -- 7/1/2009 Brian Bent  Use f_get_new_pallet_id instead of
      --                      p_get_unique_lp
      --
      -- pl_common.p_get_unique_lp(io_parent_pallet_id, ln_status);
      --
      io_parent_pallet_id := pl_common.f_get_new_pallet_id;

      pl_log.ins_msg ('INFO', lv_pname,
                 'New parent LP[' || io_parent_pallet_id || ']', NULL, NULL);

      IF ln_status <> 0 THEN     -- ln_status always 0 at this point
         RAISE e_error_getting_pallet_id;
      END IF;
   END IF;

   BEGIN
      SELECT m.erm_id, p.prod_id, p.parent_pallet_id
        INTO lv_sn_no, lv_prod_id, l_original_parent_pallet_id
        FROM putawaylst p, erm m
       WHERE p.pallet_id = i_pallet_id
         AND p.rec_id    = m.erm_id
         AND (m.status = 'NEW' OR m.status= 'OPN')
         AND p.putaway_put = 'N';
         -- AND ROWNUM = 1;  -- 7/1/2009  Brian Bent  Don't need,
                             -- putawaylst.pallet id is primary key and
                             -- erm.rec_id is primary key.

      IF SQL%FOUND THEN
         pl_log.ins_msg('INFO', lv_pname,
              'Found i_pallet_id and the SN in putawaylst and erm'
              || ' and i_pallet_id not putaway and SN status NEW or OPN'
              || '  lv_sn_no[' || lv_sn_no || ']'
              || '  lv_prod_id[' || lv_prod_id || ']'
              || '  l_original_parent_pallet_id['
              || l_original_parent_pallet_id || ']',
              NULL, NULL, gl_application_func, gl_pkg_name);

     IF i_sub_divide_type = 'L' THEN
            pl_log.ins_msg('INFO', lv_pname,
              'i_sub_divide_type is L, Calling f_update_msku_info_by_lp',
               NULL, NULL, gl_application_func, gl_pkg_name);

            lb_status := f_update_msku_info_by_lp
                                           (lv_sn_no,
                                            io_parent_pallet_id,
                                            i_pallet_id,
                                            i_pallet_type,
                                            'Y');
     ELSE
            pl_log.ins_msg('INFO', lv_pname,
              'i_sub_divide_type is not L, will call'
              || ' f_update_msku_info_by_item',
              NULL, NULL, gl_application_func, gl_pkg_name);

           pl_log.ins_msg('INFO', lv_pname,
                     'i_pallet_id[' || i_pallet_id || ']'
                      || '  i_sub_divide_type[' || i_sub_divide_type || ']'
                      || '  prod_id[' || lv_prod_id || ']',
                      NULL, NULL);

            lb_status := f_update_msku_info_by_item
                                           (lv_sn_no,
                                            io_parent_pallet_id,
                                            i_pallet_type,
                        lv_prod_id,
                        l_original_parent_pallet_id,
                                            'Y');
     END IF;

         IF lb_status THEN
            o_status := 0;
         ELSE
            o_status := 1;
         END IF;
      END IF;
   EXCEPTION WHEN NO_DATA_FOUND THEN
      --
      -- Did not find the LP in the PUTAWAYLST table and/or the SN in the
      -- ERM table.
      --
      pl_log.ins_msg ('WARN', lv_pname,
              'Validation failed for sub-divide operation c_lp:'||i_pallet_id ||
          ',new_p_lp:' || io_parent_pallet_id,NULL, SQLERRM);
      o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_lm_cannot_divide_msku);
   END;

EXCEPTION
    WHEN e_error_getting_pallet_id THEN
   pl_log.ins_msg ('WARN', lv_pname,
                 'Error getting parent pallet id from p_get_unique_lp'
                 ||io_parent_pallet_id,NULL, SQLERRM);
   o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_lm_cannot_divide_msku);
    WHEN OTHERS THEN
   pl_log.ins_msg ('WARN', lv_pname,
                 'Sub-divide failed for parent pallet id '
                 ||io_parent_pallet_id,NULL, SQLERRM);
   o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_lm_cannot_divide_msku);
END p_sub_divide_msku_pallet;

/*-----------------------------------------------------------------------
   -- Procedure:
   --    p_is_msku_symb_multi_loc
   --
   -- Description:
   -- Check if MSKU have child pallets going to both Symbotic induction and warehouse location
   --
   -- Parameters:
   --    i_parent_pallet_id       parent pallet ID or any LP of thei MSKU
   --    o_status                 0=normal
   --    i_status_msku_lp_limit   338 =Force to subdivide the MSKU pallet
   --
   -- Called From
   --    pro*C program pre_putaway
   -- Exceptions raised:
   --
   ---------------------------------------------------------------------*/
PROCEDURE p_is_msku_symb_multi_loc (
                  i_parent_pallet_id              IN  putawaylst.parent_pallet_id%TYPE,
                  i_status_normal                 IN  NUMBER,
                  i_status_msku_lp_limit          IN  NUMBER,
                  o_status                        OUT NUMBER)
IS
    l_cnt   NUMBER;
BEGIN
   SELECT COUNT(*)
     INTO l_cnt
     FROM putawaylst p, loc l 
    WHERE p.dest_loc = l.logi_loc
      AND p.parent_pallet_id IN (SELECT parent_pallet_id 
                                 FROM putawaylst
                                WHERE i_parent_pallet_id IN (pallet_id, parent_pallet_id))
      AND l.slot_type IN ('MXI', 'MXT')
      AND EXISTS (SELECT 1 
                    FROM putawaylst p1, loc l1
                   WHERE p1.parent_pallet_id = p.parent_pallet_id
                     AND p1.dest_loc = l1.logi_loc
                     AND l1.slot_type NOT IN ('MXI', 'MXT'));
      
   IF (l_cnt > 0 ) THEN
       o_status := i_status_msku_lp_limit;
   ELSE
        o_status := i_status_normal;
   END IF;
   
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      o_status  := sqlerrm;      
   WHEN OTHERS THEN
      RAISE;
END;


BEGIN
   pl_log.g_application_func := 'MSKU RECEIVING AND PUTAWAY';

END pl_msku;
/
show errors

