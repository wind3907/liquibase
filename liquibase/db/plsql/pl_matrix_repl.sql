/* *************************************************************************/
-- Package Specification
/**************************************************************************/

CREATE OR REPLACE PACKAGE swms.pl_matrix_repl
AS
--------------------------------------------------------------------------
-- Package Name:
--   pl_matrix_repl
--
-- Description:
--    This package contain functions and procedures require to create matrix replenishment task
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    07/16/09 ayad5195 Initial Creation.
--
--    01/18/15 bben0556 Symbotic changes.
--
--                      Changed cursor "c_dmd_case_rpl" adding:
--                         AND fd.uom = 2
--                      to assure we only look at case orders.
--
--    01/26/15 bben0556 Symbotic changes.
--
--                      Matrix case to main warehouse split home demand
--                      replenishment created even though the split home
--                      had sufficient qoh for the order.
--
--                      Changed procedure "create_matrix_dmd_rpl()":
--                      Added
--                         AND NVL(fd.qty_alloc, 0) < fd.qty_order
--                      to the following cursors so that only float_detail
--                      records needing allocating are processed.
--                         - c_dmd_case_rpl
--                         - c_dmd_split_rpl
--                         - c_dmd_split_prod
--                         - cFD
--                     Changed the procedure to return the qty replenished
--                     as a split qty.  This procedure is called by
--                     alloc_inv.pc, function function AllocFRomHome()
--                     which needs the qty replenished.
--                     Add "i_call_type" parameter which will be
--                     optional.
--
--    08/04/15 bben0556 Brian Bent
--                      Symbotic project  WIB 517
--                      DXL replenishment (case DMD replenishment from the
--                      main warehouse to symbotic staging) not always
--                      created with the end result we pick from the main
--                      warehouse reserve slot.  Found we are looking at
--                      the qty allocated of each individual float detail
--                      record instead of the float detail total qty allocated
--                      in determining if there is sufficient qoh in symbotic.
--                      Example of the issue:
--                          10 cases ordered and all 10 allocated.
--                          Symbotic has qoh of 5 cases.
--                          There is a pallet of 20 cases in the main warehouse
--                          reserve.
--                          Selection equipment zones per float: 2
--                          The float was built such that 5 cases were
--                          in float zone 1 and 5 cases in float zone 2.
--                          So we have 2 float detail records.
--                          Since we are looking at each line in the float
--                          detail there is sufficient qoh in the matrix to
--                          cover the float detail qty allocated.
--                          Therefore no DXL created even though there is not
--                          sufficient qoh in symbotic to cover the total
--                          allocated.
--                          PIK created for 5 cases from symbotic
--                          PIK created for 5 cases from the main warehouse
--                          pallet.
--                      Modified:
--                         - create_matrix_dmd_rpl
--                           Changed cursor "c_dmd_case_rpl" to look at the
--                           float detail total qty allocated for the item
--                           on the order in determining if a DXL needed.
--                      NOTE:  Remember this is for an order for cases and
--                             not splits.
--
--    08/12/15 ayad5195 Comment out 3 validations in procedure
--                      Symbotic project  WIB 517
--                      "create_unassign_matrix_rpl()" because they form is doing
--                      the validation.  See the comments in the procedure
--                      dated 08/12/15 for more info.
--
--    09/17/15 bben0556 Brian Bent
--                      Symbotic project.  WIB 543
--
--                      Bug fix--user getting "No LM batch" error message
--                      on RF when attempting to perform a DXL or DSP 
--                      replenishment.
--
--                      FLOATS and FLOAT_DETAIL records not created for DXL
--                      and DSP replenishments (DXL-demand repl from the main
--                      warehouse to the matrix staging location; DSP-demand
--                      repl from the matrix to the split home) thus no
--                      forklift labor batch was created since the labor
--                      batch is created from the FLOATS and
--                      FLOAT_DETAIL records.  Made modifications to
--                      insert FLOATS and FLOAT_DETAIL records for
--                      DXL and DSP replenishments.
--
--                      Modified:
--                         - create_matrix_dmd_rpl procedure
--                           Add stop_no parameter.
--                           Pass the order_id, order_line_id and stop_no to 
--                           "gen_matrix_case_replen()"
--
--                         - gen_matrix_case_replen procedure
--                           Add order_id, order_line_id and stop_no parameters.
--                           Add call to "create_float_for_dmd_replen"
--
--                      New Procedure:
--                         - create_float_for_dmd_replen
--
--                      Remove add_date from the REPLENLST insert statements
--                      because the add_date column has a default value of sysdate.
--
--    10/02/15 bben0556 Brian Bent
--                      Symbotic project.  WIB 552
--
--                      Fix bug introduced with last change. Creating
--                      unnecessary DXL replenishment instead of allocating
--                      from existing inventory at the staging location.
--
--    01/24/16 bben0556 Brian Bent
--                      Project:
--           R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
--
--                      MXP slot changes.
--                      The MXP slots are slots in the main warehouse with slot
--                      type MXP where matrix items are put because the case(s)
--                      could not be inducted onto the matrix because of
--                      tolerance issues.  The rule is these get allocated first.
--                      There will be no replenishments from MXP slots to the
--                      matrix for matrix items in MXP slots.
--                      If for whatever reason non matrix items have inventory
--                      in MXP slots then the MXP slots are treated like normal
--                      slots.
--
--                      Changed cursor "c_dmd_case_rpl" in procedure
--                      "create_matrix_dmd_rpl()" to consider locations with
--                      slot_type in MXP as pickable inventory.
--
--                      Change cursor "c_inv" in procedure
--                      "Gen_Matrix_Case_Replen()" to leave out MXP slots.
--
--                      ******** 01/24/16 Still need to have DSP come from MXP
--                      ******** slot first so what this means is we have split
--                      ******** DMD repl from MXP slot to the split home.
--
--    03/17/16 bben0556 Brian Bent
--                      Project:
--            R30.4--WIB#625--Charm6000011676_Symbotic_Throttling_enhancement
--
--                      Add log messages to help in resolving issues, answering
--                      questions.
--
--                      FLOAT_DETAIL QTY_ORDER and QTY_ALLOC incorrect for DSP.
--                      The qty used was the qoh of the pallet the cases
--                      were taken from instead of the replenishment qty.
--
--                      Change cursor "c_dmd_split_rpl" back to accepting
--                      parameters prod_id and cpv instead of float_no and
--                      float detail seq_no.  Now need to get the REPLENLST.ORDER_ID
--                      to reflect the actual order.
--
--    04/13/16 bben0556 Creation of NSP replenishments was looking at v.max_mx_cases
--                      instead of v.min_mx_cases.
--                      Changed
--              ' WHERE NVL(v.curr_mx_cases, 0) + NVL(v.curr_repl_cases, 0) < NVL(v.max_mx_cases, 0)                    
--                      to
--              ' WHERE NVL(v.curr_mx_cases, 0) + NVL(v.curr_repl_cases, 0) <= NVL(v.min_mx_cases, 0)                    
--
--
--    05/31/16 bben0556 Brian Bent
--                      Project:
--       R30.4.2--WIB#646--Charm6000013323_Symbotic_replenishment_fixes
--
--                      The changes I made on 03/17/16 introduced a bug in
--                      version 30.4.1--too many DSP's are getting created. 
--                      I found the bug when doing additional testing on
--                      Sunday morning 5/22/16.  OpCo 007 got the bugging
--                      version on Saturday 5/21/16.
--                      On Sunday afternon we installed at OpCo 007 the version
--                      OpCo 001 has (30.4) has which does not have the bug.
--
--                      Change cursor "c_dmd_split_rpl" once again to accept
--                      parameters float_no and float detail seq_no and not
--                      the item and cpv.
--
--                      DSP not getting created when there is qty planned to
--                      the split home for a putaway.  Column
--                      "curr_resv_split_qty" from view "v_matrix_splithome_info"
--                      is used for the qty in the split home when deciding if
--                      a DSP is needed.  This column includes the qty planned
--                      to the split home so qty planned for a putaway to the split
--                      home is considered "pickable" inventory which it is not
--                      so a DSP may not get created.
--                      View "v_matrix_splithome_info" was changed to have these columns:
--                         - split_home_qoh
--                         - split_home_qty_planned
--                         - split_home_qoh_qty_planned (column was called curr_resv_split_qty)
--
--                      Changed cursor "c_dmd_split_rpl" to use v_matrix_splithome_info.split_home_qoh 
--                      instead of v_matrix_splithome_info.curr_resv_split_qty
--                      Changed "curr_resv_split_qty" to "split_home_qoh_qty_planned"
--                      in RECORD TYPE t_splhome_record.
--                      Changed "curr_resv_split_qty" to "split_home_qoh_qty_planned"
--                      in MX_MAIN_SQL.
--                      Changed "curr_resv_split_qty" to "split_home_qoh_qty_planned"
--                      in MX_SUB_NSP.
--                      Changed "curr_resv_split_qty" to "split_home_qoh_qty_planned"
--                      in
--      rpl_qty := (r_splhome_rpl.case_qty_for_split_rpl - CEIL(r_splhome_rpl.split_home_qoh_qty_planned/r_splhome_rpl.spc)) * r_splhome_rpl.spc - NVL(r_splhome_rpl.curr_repl_cases, 0)  ;
--
--                      DSP not getting created when the only case inventory is in
--                      the staging, outduct or induction location.  The split order
--                      shorts.
----------------------------------------------------------------------------------
        
--------------------------------------------------------------------------
-- Public Constants 
--------------------------------------------------------------------------
C_PROGRAM_CODE   CONSTANT VARCHAR2 (50) := 'MXRPL';

    
---------------------------------------------------------------------------
-- Procedure:
--    create_matrix_ndm_case_rpl
--
-- Description:
--    Create case non-demand replenishment task from Reserve to Matrix
--
---------------------------------------------------------------------------
    PROCEDURE create_matrix_ndm_case_rpl (
        i_call_type         IN  VARCHAR2    DEFAULT NULL,
        i_area              IN  VARCHAR2    DEFAULT NULL,
        i_putzone           IN  VARCHAR2    DEFAULT NULL,
        i_prod_id           IN  VARCHAR2    DEFAULT NULL,
        i_cust_pref_vendor  IN  VARCHAR2    DEFAULT NULL,
        i_route_batch_no    IN  NUMBER      DEFAULT NULL,
        i_route_no          IN  VARCHAR2    DEFAULT NULL,
        i_qty_reqd          IN  NUMBER      DEFAULT NULL,
        i_uom               IN  NUMBER      DEFAULT 2,
        i_batch_no          IN  NUMBER,
        o_status            OUT NUMBER);

        
---------------------------------------------------------------------------
-- Procedure:
--    create_throttle_rpl_options
--
-- Description:
--    Create throttle non-demand replenishment options for user to select
--
---------------------------------------------------------------------------
PROCEDURE create_throttle_rpl_options (        
        i_area              IN  VARCHAR2    DEFAULT NULL,        
        i_prod_id           IN  VARCHAR2    DEFAULT NULL,
        i_cust_pref_vendor  IN  VARCHAR2    DEFAULT NULL,        
        i_batch_no          IN  NUMBER,
        i_item_type         IN  VARCHAR2    DEFAULT 'BOTH',     
        o_status            OUT NUMBER);        
        
        
---------------------------------------------------------------------------
-- Procedure:
--    Gen_Matrix_Case_Replen
--
-- Description:
--    Generate replenishment task based on input
--
---------------------------------------------------------------------------
PROCEDURE Gen_Matrix_Case_Replen (i_rb_no     IN NUMBER,
                                  i_route_no  IN VARCHAR2,
                                  i_prod_id   IN VARCHAR2,
                                  i_cpv       IN VARCHAR2,
                                  i_rpl_qty   IN NUMBER,
                                  i_priority  IN NUMBER,
                                  --i_ind_loc   VARCHAR2,
                                  i_call_type IN VARCHAR2,            
                                  i_spc       IN NUMBER,
                                  i_batch_no  IN NUMBER,
                                  i_def_stg   IN VARCHAR2 DEFAULT NULL,
                                  i_order_id      IN float_detail.order_id%TYPE        DEFAULT NULL,
                                  i_order_line_id IN float_detail.order_line_id%TYPE   DEFAULT NULL,
                                  i_stop_no       IN ordm.stop_no%TYPE                 DEFAULT NULL,
                                  i_logi_loc      IN inv.logi_loc%TYPE                 DEFAULT NULL)    ;   
---------------------------------------------------------------------------
-- Procedure:
--    create_matrix_dmd_rpl
--
-- Description:
--    Create case demand replenishment task based on route_no
--
---------------------------------------------------------------------------     
PROCEDURE create_matrix_dmd_rpl (            
   i_call_type                  IN  VARCHAR2                        DEFAULT NULL,
   i_prod_id                    IN  VARCHAR2                        DEFAULT NULL,
   i_cust_pref_vendor           IN  VARCHAR2                        DEFAULT NULL,
   i_order_id                   IN  float_detail.order_id%TYPE      DEFAULT NULL,
   i_order_line_id              IN  float_detail.order_line_id%TYPE DEFAULT NULL,
   i_route_batch_no             IN  NUMBER                          DEFAULT NULL,
   i_route_no                   IN  VARCHAR2                        DEFAULT NULL,                
   i_stop_no                    IN  ordm.stop_no%TYPE               DEFAULT NULL,
   o_qty_replenished_in_splits  OUT NUMBER,
   o_status                     OUT NUMBER);      


---------------------------------------------------------------------------
-- Procedure:
--    send_SYS05_to_matrix
--
-- Description:
--    Send SYS05 (Release pallet to SPUR) message to matrix
--
--------------------------------------------------------------------------- 
    FUNCTION send_SYS05_to_matrix(
        i_batch_no          IN  NUMBER ,
        i_replen_type       IN  VARCHAR2    DEFAULT NULL,
        i_replen_status     IN  VARCHAR2    DEFAULT NULL)
    RETURN NUMBER;
    
---------------------------------------------------------------------------
-- Procedure:
--    create_split_home_rpl
--
-- Description:
--    Create split replenishment task from Matrix to Main Warehouse
--
---------------------------------------------------------------------------    
    PROCEDURE create_split_home_rpl (
        i_call_type         IN  VARCHAR2    DEFAULT NULL,
        i_area              IN  VARCHAR2    DEFAULT NULL,
        i_putzone           IN  VARCHAR2    DEFAULT NULL,
        i_prod_id           IN  VARCHAR2    DEFAULT NULL,
        i_cust_pref_vendor  IN  VARCHAR2    DEFAULT NULL,
        i_route_batch_no    IN  NUMBER      DEFAULT NULL,
        i_route_no          IN  VARCHAR2    DEFAULT NULL,
        i_qty_reqd          IN  NUMBER      DEFAULT NULL,
        i_uom               IN  NUMBER      DEFAULT 2,
        i_batch_no          IN  NUMBER,
        o_status            OUT NUMBER);
        
---------------------------------------------------------------------------
-- Procedure:
--    create_assign_matrix_rpl
--
-- Description:
--    Create Assign to Matrix (MXL) replenishment task from Home location to Matrix
--
---------------------------------------------------------------------------    
    PROCEDURE  create_assign_matrix_rpl(        
        i_prod_id           IN  VARCHAR2,
        i_cust_pref_vendor  IN  VARCHAR2 DEFAULT NULL,
        i_split_home_loc    IN  VARCHAR2,               
        o_status            OUT NUMBER); 

---------------------------------------------------------------------------
-- Procedure:
--    create_unassign_matrix_rpl
--
-- Description:
--    Create Unassign to Matrix (UNA) replenishment task from Matrix to home and Reserve
--
---------------------------------------------------------------------------    
    PROCEDURE create_unassign_matrix_rpl (
        i_prod_id           IN  VARCHAR2,
        i_cust_pref_vendor  IN  VARCHAR2 DEFAULT NULL,
        i_case_home_loc     IN  VARCHAR2,      
        o_status            OUT NUMBER); 

----------------------------------------------------------------------------------
-- Procedure: 
--     create_split_transfer_rpl
--
-- Description:
--     This procedure create non-demand replenishment tasks (NDM) to move split to split home location
--     which is left after assigning the cases to Matrix from home location  
--
----------------------------------------------------------------------------------

    PROCEDURE  create_split_transfer_rpl(       
        i_prod_id           IN  VARCHAR2,
        i_cust_pref_vendor  IN  VARCHAR2 DEFAULT NULL,
        i_case_home_loc     IN  VARCHAR2 DEFAULT NULL,      
        i_split_home_loc    IN  VARCHAR2 DEFAULT NULL,
        i_qty               IN  NUMBER   DEFAULT NULL,
        i_batch_no          IN  NUMBER,
        o_status            OUT NUMBER)  ;      
---------------------------------------------------------------------------
-- Function: 
--     is_replenlst_exists
--
-- Description:
--     This function return TRUE or FALSE base on record present in 
--     table replenlst for the input prod_id
--
----------------------------------------------------------------------------

    FUNCTION  is_replenlst_exists(i_prod_id IN  VARCHAR2)
        RETURN BOOLEAN ;

---------------------------------------------------------------------------
-- Function: 
--     is_putawaylst_exists
--
-- Description:
--     This function return TRUE or FALSE base on record present in 
--     table putawaylst for the input prod_id
--
----------------------------------------------------------------------------

    FUNCTION  is_putawaylst_exists(i_prod_id IN  VARCHAR2)
        RETURN BOOLEAN ;

---------------------------------------------------------------------------
-- Function: 
--     is_float_detail_exists
--
-- Description:
--     This function return TRUE or FALSE base on record present in 
--     table float_detail for the input prod_id
--
----------------------------------------------------------------------------

    FUNCTION  is_float_detail_exists(i_prod_id IN  VARCHAR2)
        RETURN BOOLEAN ;        
END pl_matrix_repl;
/


/**************************************************************************/
-- Package Body
/**************************************************************************/

CREATE OR REPLACE PACKAGE BODY swms.pl_matrix_repl
AS
/*=============================================================================================
 This package contain functions and procedures require to create matrix replenishment task
             
Modification History
Date           Designer         Comments
-----------    ---------------  --------------------------------------------------------
15-JUL-2014    ayad5195         Initial Creation    
                     
=============================================================================================*/

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
   gl_pkg_name           VARCHAR2 (30) := 'pl_matrix_repl';    -- Package name used in error messages.

   gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                    -- function is null.


   
--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

    ct_application_function      VARCHAR2(20) := 'ORDER PROCESSING';


    -- Application function for the log messages.
    ct_app_func CONSTANT VARCHAR2 (9) := 'MX REPL';

    SHP_PRI_CD  CONSTANT VARCHAR2 (3) := 'HGH';
    DMD_PRI_CD  CONSTANT VARCHAR2 (3) := 'URG';
    NDM_PRI_CD  CONSTANT VARCHAR2 (3) := 'LOW';
    C_SUCCESS   CONSTANT NUMBER       := 0;
    C_FAILURE   CONSTANT NUMBER       := 1; 


---------------------------------------------------------------------------
-- Procedure:
--    create_float_for_dmd_replen  (Private module)
--
-- Description:
--    The procedures creates the FLOAT and FLOAT_DETAIL record for a matrix
--    DXL and DSP replenishment.
--
-- Parameters:
--    i_task_id         - Demand replenishment task id.  The replenlst task
--                        id.
--    i_float_no        - Float number to use.
--    i_route_no        - Route being processed.
--    i_pallet_id       - LP being replenished
--    i_src_loc         - Source location of the replenishment
--    i_dest_loc        - inv.plogi_loc%TYPE,
--    i_prod_id         - pm.prod_id%TYPE,
--    i_cpv             - pm.cust_pref_vendor%TYPE,
--    i_order_id        - ordd.order_id%TYPE,
--    i_order_line_id   - ordd.order_line_id%TYPE,
--    i_stop_no         - ordm.stop_no%TYPE,
--    i_rpl_qty         - replenlst.qty%TYPE
--
-- Called by:
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/17/15 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE create_float_for_dmd_replen
             (i_task_id         replenlst.task_id%TYPE,
              i_float_no        floats.float_no%TYPE,
              i_route_no        route.route_no%TYPE,
              i_pallet_id       inv.logi_loc%TYPE,
              i_src_loc         inv.plogi_loc%TYPE,
              i_dest_loc        inv.plogi_loc%TYPE,
              i_prod_id         pm.prod_id%TYPE,
              i_cpv             pm.cust_pref_vendor%TYPE,
              i_order_id        ordd.order_id%TYPE,
              i_order_line_id   ordd.order_line_id%TYPE,
              i_stop_no         ordm.stop_no%TYPE,
              i_rpl_qty         replenlst.qty%TYPE)
IS
   l_object_name  VARCHAR2(30) := 'create_float_for_dmd_replen';
   l_message      VARCHAR2(512);

   --
   -- This cursor gets the selection method group number and selection
   -- equipment for the pick zone of the replenishment source location.
   -- They are used in the FLOATS record.
   --
   CURSOR c_sel_method_info(cp_route_no   route.route_no%TYPE,
                            cp_location   lzone.logi_loc%TYPE)
   IS
   SELECT sm.group_no,
          sm.equip_id,
          z.zone_id       -- Pick zone of the replenishment source location
     FROM sel_method sm,
          sel_method_zone smz,
          route r,
          lzone lz,
          zone z
    WHERE r.route_no      = cp_route_no
      AND sm.method_id    = r.method_id
      AND sm.sel_type     = 'PAL'        -- The PAL is for demand replenishments (and bulk pulls).
      AND smz.method_id   = sm.method_id
      AND smz.group_no    = sm.group_no
      AND smz.zone_id     = z.zone_id
      AND lz.logi_loc     = cp_location
      AND z.zone_id       = lz.zone_id
      AND z.zone_type     = 'PIK';

   r_sel_method_info   c_sel_method_info%ROWTYPE;

BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
            'Starting procedure'
         || '  (i_route_no[' || i_route_no || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   --
/*****
   IF (i_task_id IS NULL) THEN
       RAISE gl_e_parameter_null;
   END IF;
*****/


   --
   -- Get the selection method group number and selection equipment.
   -- They are used in the FLOATS record.
   --
   OPEN c_sel_method_info(i_route_no, i_src_loc);
   FETCH c_sel_method_info INTO r_sel_method_info;
   CLOSE c_sel_method_info;


   --
   -- Create the FLOATS demand replenishment record.
   --
   INSERT INTO floats
                   (batch_no,
                    batch_seq,
                    float_no,
                    float_seq,
                    route_no,
                    b_stop_no,
                    e_stop_no,
                    group_no,
                    equip_id,
                    pallet_pull,
                    pallet_id,
                    home_slot,
                    status,
                    zone_id,
                    parent_pallet_id)
            VALUES
                   (0,
                    0,
                    i_float_no,
                    0,
                    i_route_no,
                    i_stop_no,
                    i_stop_no,
                    r_sel_method_info.group_no,
                    r_sel_method_info.equip_id,
                    'R',
                    i_pallet_id,
                    i_dest_loc,
                    'NEW',
                    r_sel_method_info.zone_id,
                    NULL);

   --
   -- Create the FLOAT_DETAIL demand replenishment record.
   --
   INSERT INTO float_detail
                        (float_no,
                         seq_no,
                         zone,
                         stop_no,
                         prod_id,
                         cust_pref_vendor,
                         src_loc,
                         qty_order,
                         qty_alloc,
                         status,
                         order_id, 
                         order_line_id,
                         route_no)
                  VALUES 
                        (i_float_no,
                         1,
                         1,
                         i_stop_no,
                         i_prod_id,
                         i_cpv,
                         i_src_loc,
                         i_rpl_qty,
                         i_rpl_qty,
                         'ALC',
                         i_order_id,
                         i_order_line_id, 
                         i_route_no);

   --
   -- Log when done.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
            'Ending procedure'
         || '  (i_route_no[' || i_route_no || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_message := l_object_name
             || '(i_route_no[' || i_route_no || '],'
             || '  An input parameter is null.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error,
                     NULL, ct_application_function,  gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := l_object_name
             || '(i_route_no[' || i_route_no || '],';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END create_float_for_dmd_replen;


----------------------------------------------------------------------------------
-- Procedure (Private)
--   Gen_Matrix_Case_Replen 
--
-- Description
--   This procedure insert record into replenishment table             
--
-- Parameters
--
--  Input:
--      i_rb_no     Route Batch Number
--      i_route_no  Route Number
--      i_prod_id   Product ID
--      i_cpv       Cust Preferred Vendor
--      i_rpl_qty   Replenishment Quantity
--      i_priority  Priority
--      i_ind_loc   Induction Location
--      i_call_type Call type (NXL, DXL)          
--      i_spc       Quantity in a Case
--      i_order_id       The order being processed.
--      i_order_line_id  The order line id being processed.
--      i_stop_no        The stop number being processed.
--
--  Output:
--      N/A
--
-- Modification History
--
-- Date         User             Comment
-- --------     ---------        ------------------------------------------
-- 07/18/14     ayad5195         Initial Creation
-- 09/29/14     bben0556         Brian Bent
--                               Add order_id, order_line_id and stop_no parameters.
--                               Populate REPLENLST.FLOAT_NO and REPLENLST.LABOR_BATCH_NO
--                               Add call to procedure "create_float_for_dmd_replen()"
--                               to create FLOATS and FLOAT_DETAIL record for the DXL
--                               replenishment.
----------------------------------------------------------------------------------

    PROCEDURE Gen_Matrix_Case_Replen (i_rb_no     IN NUMBER,
                                      i_route_no  IN VARCHAR2,
                                      i_prod_id   IN VARCHAR2,
                                      i_cpv       IN VARCHAR2,
                                      i_rpl_qty   IN NUMBER,
                                      i_priority  IN NUMBER,
                                      --i_ind_loc   VARCHAR2,
                                      i_call_type IN VARCHAR2,            
                                      i_spc       IN NUMBER,
                                      i_batch_no  IN NUMBER,
                                      i_def_stg   IN VARCHAR2 DEFAULT NULL,
                                      i_order_id      IN float_detail.order_id%TYPE        DEFAULT NULL,
                                      i_order_line_id IN float_detail.order_line_id%TYPE   DEFAULT NULL,
                                      i_stop_no       IN ordm.stop_no%TYPE                 DEFAULT NULL,
                                      i_logi_loc      IN inv.logi_loc%TYPE                 DEFAULT NULL)
    IS
        l_rpl_qty       NUMBER;
        l_remaining     NUMBER;        
        l_fname         VARCHAR2 (50)       := 'Gen_Matrix_Case_Replen';
        l_status        NUMBER;       
        l_config_dest_loc replenlst.dest_loc%TYPE;
        l_pm_area       pm.area%TYPE;
        l_task_id       replenlst.task_id%TYPE;  -- Task id for the REPLENLST record.  Populated from sequence.
        l_float_no      floats.float_no%TYPE;    -- Float number for the FLOATS and FLOAT_DETAIL record for DXL replenishment.
                                                 -- Populated from sequence.
                                                 -- Also used to populate REPLENLST.FLOAT_NO and REPLENLST.LABOR_BATCH_NO.
                                                 -- labor batch number has format 'FR'<float no>
        
       /*Cursor for reserve inventory available to allocate*/
       CURSOR  c_inv (p_prod_id VARCHAR2,
                      p_CPV    VARCHAR2,
                      p_logi_loc VARCHAR2) IS
        SELECT  l.pik_path, i.logi_loc, plogi_loc, qoh, qty_alloc, exp_date,
                i.parent_pallet_id, i.rec_id, i.lot_id, i.mfg_date, i.rec_date,
                i.qty_planned, i.inv_date, i.min_qty, i.abc, p.spc, i.inv_uom,
                l.slot_type
          FROM  pm p, zone z, lzone lz, loc l, inv i
         WHERE  i.prod_id = p_prod_id
           AND  i.cust_pref_vendor = p_CPV
           AND  i.logi_loc = NVL(p_logi_loc, i.logi_loc)
           AND  p.prod_id = i.prod_id
           AND  p.cust_pref_vendor = i.cust_pref_vendor
           AND  i.status = 'AVL'
           AND  i.inv_uom IN (0, 2)
           AND  i.qoh > 0
           AND  NVL (i.qty_alloc, 0) = 0
           AND  l.logi_loc = i.plogi_loc
           AND  i.plogi_loc != i.logi_loc
           AND  lz.logi_loc = l.logi_loc
           AND  z.zone_id = lz.zone_id
           AND  z.zone_type = 'PUT'
           AND  z.induction_loc IS NULL
           AND  z.rule_id IN (0, 1, 2)
           AND  l.slot_type <> 'MXP'     -- 01/24/2015 Rule is inventory in MXP slots is not replenished to the matrix.
           AND  NVL(p.mx_eligible, 'N') = 'Y'
         ORDER  BY i.exp_date, i.qoh, i.logi_loc
           FOR  UPDATE OF i.qty_alloc NOWAIT;       
    BEGIN
        l_remaining := i_rpl_qty;
        Pl_Text_Log.ins_msg ('FATAL', l_fname, 'In Gen_Matrix_Case_Replen for Prod_id '||i_prod_id ||'   qty '||i_rpl_qty, NULL,NULL);
        
        IF i_def_stg IS NULL THEN
            --Get SYS_CONFIG matrix destination location  
            l_config_dest_loc := pl_matrix_common.f_get_mx_dest_loc(i_prod_id);    
        ELSE
            l_config_dest_loc := i_def_stg;
        END IF;
        
        IF  TRIM(l_config_dest_loc) IS NULL THEN     
            Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Not able to find induction location in SYS_CONFIG for prod_id.' || i_prod_id, SQLCODE,SQLERRM);
            RAISE_APPLICATION_ERROR(-20001, 'Error Gen_Matrix_Case_Replen: Unable to get SYS_CONFIG matrix destination location for prod_id '||i_prod_id);
        END IF;
        
        Pl_Text_Log.ins_msg ('INFO', l_fname, 'In Gen_Matrix_Case_Replen Before Loop  Prod_id '||i_prod_id, NULL,NULL);
        
        FOR r_inv IN c_inv (i_prod_id, i_cpv, i_logi_loc)
        LOOP
            Pl_Text_Log.ins_msg ('INFO', l_fname, 'In Gen_Matrix_Case_Replen IN Loop  repln qty '||r_inv.qoh, NULL,NULL);
            /* Whole pallet will replenish to Matrix */
            l_rpl_qty := r_inv.qoh;     

            l_task_id := repl_id_seq.NEXTVAL;

            --
            -- Get the float number for the FLOATS and FLOAT_DETAIL records.  We need it for populating the
            -- REPLENLST.LABOR_BATCH_NO.  There is a database trigger on the REPLENLST table that creates the RPL
            -- transaction when the replenlst record is inserted so we need REPLENLST.LABOR_BATCH_NO populated.
            --
            l_float_no := float_no_seq.NEXTVAL;
            
            /* Create replenishment task to move pallet from reserve location to Matrix Induction location */
            INSERT INTO replenlst (
                task_id, prod_id, cust_pref_vendor, uom, qty, type, 
                status, src_loc, pallet_id, 
                dest_loc, gen_uid, gen_date, exp_date, route_no, route_batch_no, priority, 
                parent_pallet_id, rec_id, lot_id, mfg_date, s_pikpath, 
                orig_pallet_id, case_no, print_lpn, batch_no, mx_batch_no,
                float_no,
                labor_batch_no,
                order_id,
                replen_type)
            VALUES (l_task_id, i_prod_id, i_cpv, 2, l_rpl_qty, i_call_type,
                DECODE (i_call_type, 'NXL', 'PRE', 'NEW'), r_inv.plogi_loc, r_inv.logi_loc , 
                l_config_dest_loc, REPLACE (USER, 'OPS$'), SYSDATE, r_inv.exp_date, i_route_no, i_rb_no, i_priority,
                r_inv.parent_pallet_id, r_inv.rec_id, r_inv.lot_id, r_inv.mfg_date, r_inv.pik_path,
                DECODE (r_inv.plogi_loc, r_inv.logi_loc, NULL, DECODE (r_inv.slot_type, 'MXS', NULL, r_inv.logi_loc)),
                ordd_seq.NEXTVAL, pl_matrix_common.print_lpn_flag(i_call_type), i_batch_no, mx_batch_no_seq.NEXTVAL,
                l_float_no,
                DECODE(i_call_type, 'DXL', 'FR' || TRIM(TO_CHAR(l_float_no)), NULL),
                i_order_id,        
                DECODE(i_call_type, 'DXL', 'D', NULL));
          
            IF (i_call_type = 'DXL')
            THEN            
                UPDATE  inv
                   SET  plogi_loc = l_config_dest_loc
                 WHERE  CURRENT OF c_inv;               

                --
                -- Now create the float record for the DXL replenishment.
                --
                create_float_for_dmd_replen
                       (i_task_id         => l_task_id,
                        i_float_no        => l_float_no,
                        i_route_no        => i_route_no,
                        i_pallet_id       => r_inv.logi_loc,
                        i_src_loc         => r_inv.plogi_loc,
                        i_dest_loc        => l_config_dest_loc,
                        i_prod_id         => i_prod_id,
                        i_cpv             => i_cpv,
                        i_order_id        => i_order_id,
                        i_order_line_id   => i_order_line_id,
                        i_stop_no         => i_stop_no,
                        i_rpl_qty         => r_inv.qoh);

            ELSE
                /*Update quantity allocated to replenishment quantity for allocated inventory record*/    
                UPDATE  inv
                   SET  qty_alloc = NVL(qty_alloc, 0) + l_rpl_qty
                 WHERE  CURRENT OF c_inv;
            END IF;                                     
                         
            l_remaining := l_remaining - l_rpl_qty;

            IF (l_remaining <= 0) THEN
                EXIT;
            END IF;
        END LOOP;

    END Gen_Matrix_Case_Replen;
    
----------------------------------------------------------------------------------
-- Procedure (Private)
--   Gen_SplitHome_Case_Replen 
--
-- Description
--   This procedure insert Split Home replenishment record into REPLENLST table             
--
-- Parameters
--
--  Input:
--      i_rb_no     Route Batch Number
--      i_route_no  Route Number
--      i_prod_id   Product ID
--      i_cpv       Cust Preferred Vendor
--      i_rpl_qty   Replenishment Quantity
--      i_priority  Priority
--      i_ind_loc   Induction Location
--      i_call_type Call type (NSP, DSP)          
--      i_spc       Quantity in a Case
--      i_order_id       The order being processed.  Applicable only for DSP.
--      i_order_line_id  The order line id being processed.  Applicable only for DSP.
--      i_stop_no        The stop number being processed.  Applicable only for DSP.
--
--  Output:
--      o_qty_replenished_in_splits - qty replenished as a split qty
--
-- Modification History
--
-- Date         User             Comment
-- --------     ---------        ------------------------------------------
-- 07/21/14     ayad5195         Initial Creation
-- 01/26/15     bben0556         Added o_qty_replenished_in_splits
-- 09/29/15     bben0556         Brian Bent
--                               Add order_id, order_line_id and stop_no parameters.
--                              
----------------------------------------------------------------------------------

PROCEDURE Gen_SplitHome_Case_Replen
               (i_rb_no                     IN NUMBER,
                i_route_no                  IN VARCHAR2,
                i_prod_id                   IN VARCHAR2,
                i_cpv                       IN VARCHAR2,
                i_rpl_qty                   IN NUMBER,
                i_priority                  IN NUMBER,
                i_call_type                 IN VARCHAR2,            
                i_spc                       IN NUMBER,
                i_batch_no                  IN NUMBER,
                i_order_id                  IN float_detail.order_id%TYPE        DEFAULT NULL,
                i_order_line_id             IN float_detail.order_line_id%TYPE   DEFAULT NULL,
                i_stop_no                   IN ordm.stop_no%TYPE                 DEFAULT NULL,
                o_qty_replenished_in_splits OUT NUMBER)
IS
   l_fname             VARCHAR2 (50)       := 'Gen_SplitHome_Case_Replen';

   l_rpl_qty           NUMBER;
   l_remaining         NUMBER;
   l_pallet_seq        NUMBER;
   l_status            NUMBER;
   l_splithome_loc     loc.logi_loc%TYPE;
   l_def_spur_loc      replenlst.src_loc%TYPE;
   /*l_inv_rec   pl_ml_repl_rf.inv_rec;*/

   l_task_id       replenlst.task_id%TYPE;  -- Task id for the REPLENLST record.  Populated from sequence.
   l_float_no      floats.float_no%TYPE;    -- Float number for the FLOATS and FLOAT_DETAIL record for DSP replenishment.
                                            -- Populated from sequence.
                                            -- Also used to populate REPLENLST.FLOAT_NO and REPLENLST.LABOR_BATCH_NO for DSP
                                            -- replenishment.  Labor batch number has format 'FR'<float no>

        
   --
   -- This cursor selects the matrix inventory available to allocate to a split replenishment.
   -- Only inventory in the matrix structure is selected--MXF and MXC slot types.
   --
   CURSOR  c_inv (p_prod_id VARCHAR2,
                  p_CPV    VARCHAR2)
   IS
      SELECT l.pik_path,
             i.logi_loc,
             plogi_loc,
             qoh - NVL(qty_alloc, 0) qoh,
             qty_alloc, exp_date,
             i.parent_pallet_id,
             i.rec_id,
             i.lot_id,
             i.mfg_date,
             i.rec_date,
             i.qty_planned,
             i.inv_date,
             i.min_qty,
             i.abc,
             p.spc,
             i.inv_uom,
             l.slot_type
        FROM pm p,
             zone z,
             lzone lz,
             loc l,
             inv i
       WHERE i.prod_id                   = p_prod_id
         AND i.cust_pref_vendor          = p_CPV
         AND p.prod_id                   = i.prod_id
         AND p.cust_pref_vendor          = i.cust_pref_vendor
         AND i.status                    = 'AVL'
         AND i.inv_uom                   IN (0, 2) 
         AND i.qoh - NVL (i.qty_alloc, 0) > 0
         AND l.logi_loc                   = i.plogi_loc
         AND lz.logi_loc                  = l.logi_loc
         AND z.zone_id                    = lz.zone_id
         AND z.zone_type                  = 'PUT'
         AND z.rule_id                    = 5
         AND l.slot_type                  IN ('MXF', 'MXC')
       ORDER BY i.exp_date, i.qoh, i.logi_loc
         FOR UPDATE OF i.qty_alloc NOWAIT;       
BEGIN
   --
   -- Log message to know what is going on.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_fname,
       'Starting procedure'
       || '  i_rb_no['              || TO_CHAR(i_rb_no)         || ']'
       || '  i_route_no['           || i_route_no               || ']'
       || '  i_prod_id['            || i_prod_id                || ']'
       || '  i_cpv['                || i_cpv                    || ']'
       || '  i_rpl_qty(in splits)[' || TO_CHAR(i_rpl_qty)       || ']'
       || '  i_priority['           || TO_CHAR(i_priority)      || ']'
       || '  i_call_type['          || i_call_type              || ']'
       || '  i_spc['                || TO_CHAR(i_spc)           || ']'
       || '  i_batch_no['           || TO_CHAR(i_batch_no)      || ']'
       || '  i_order_id['           || i_order_id               || ']'
       || '  i_order_line_id['      || TO_CHAR(i_order_line_id) || ']'
       || '  i_stop_no['            || TO_CHAR(i_stop_no)       || ']'
       || '  This procedure creates a case to split replenishment from the'
       || ' available inventory in the matrix (slot types MXC and MXF) to the split home.'
       || '  If there is no available inventory in the MXC and MXF slots'
       || ' then there is separate processing to create the split home'
       || ' replenishment from any available inventory in staging, outduct, induction and spurs.',
       NULL, NULL, ct_app_func, gl_pkg_name);


   l_remaining := i_rpl_qty;
   o_qty_replenished_in_splits := 0;
        
   /*Find the split home location of product*/
   BEGIN
      SELECT logi_loc 
        INTO l_splithome_loc
        FROM loc l
       WHERE l.prod_id = i_prod_id
         AND l.perm = 'Y'
         AND l.uom = 1
         AND rank = 1;
   EXCEPTION
      WHEN OTHERS THEN
         Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Not able to find Split home location for PROD_ID ='||i_prod_id, SQLCODE,SQLERRM);
         RAISE;  
   END;
        
   BEGIN
      SELECT config_flag_val
        INTO l_def_spur_loc
        FROM sys_config
       WHERE config_flag_name = 'MX_DEFAULT_SPUR_LOCATION';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Not able to find default spur location in SYS_CONFIG for flag MX_DEFAULT_SPUR_LOCATION.', SQLCODE,SQLERRM);
         RAISE;
   END;
        
   FOR r_inv IN c_inv (i_prod_id, i_cpv)
   LOOP
      /*If inventory quantity is less than quantity required then whole pallet will be replenished else required quantity*/
      IF r_inv.qoh <= l_remaining THEN
         l_rpl_qty := r_inv.qoh;                              
      ELSE
         l_rpl_qty := l_remaining;  
      END IF;
            
      --Change quantity to full case quantity 
      IF i_call_type = 'DSP' THEN
         l_rpl_qty := CEIL(l_rpl_qty / r_inv.spc) * r_inv.spc;
      END IF;

      l_task_id := repl_id_seq.NEXTVAL;

      --
      -- For DSP get the float number for the FLOATS and FLOAT_DETAIL records.  We need it for populating the
      -- REPLENLST.LABOR_BATCH_NO.  There is a database trigger on the REPLENLST table that creates the RPL
      -- transaction when the replenlst record is inserted so we need REPLENLST.LABOR_BATCH_NO populated.
      --
      IF (i_call_type = 'DSP') THEN
         l_float_no := float_no_seq.NEXTVAL;
      ELSE
         l_float_no := NULL;
      END IF;

              
      --
      -- Create replenishment task to move from default SPUR location (SP9999) to split home location.
      -- When the Matrix sends back the actual SPUR location information the task will be updated with the SPUR location.
      --
      INSERT INTO replenlst
               (task_id,
                prod_id,
                cust_pref_vendor,
                uom,
                qty,
                type, 
                status,
                src_loc,
                pallet_id, 
                dest_loc,
                gen_uid,
                gen_date,
                exp_date,
                route_no,
                route_batch_no,
                priority, 
                parent_pallet_id,
                rec_id,
                lot_id,
                mfg_date,
                s_pikpath, 
                orig_pallet_id, 
                case_no,
                print_lpn,
                batch_no,
                float_no,
                labor_batch_no,
                order_id,
                replen_type)
      VALUES
               (l_task_id,
                i_prod_id,
                i_cpv,
                2,
                l_rpl_qty,
                i_call_type,
                DECODE(i_call_type, 'NSP', 'PRE', 'PND'),
                l_def_spur_loc, 
                r_inv.logi_loc,  
                l_splithome_loc,
                REPLACE(USER, 'OPS$'),
                SYSDATE,
                r_inv.exp_date,
                i_route_no,
                i_rb_no,
                i_priority,
                r_inv.parent_pallet_id,
                r_inv.rec_id,
                r_inv.lot_id,
                r_inv.mfg_date,
                r_inv.pik_path,
                DECODE(r_inv.plogi_loc, r_inv.logi_loc, NULL, DECODE(r_inv.slot_type, 'MXS', NULL, r_inv.logi_loc)),
                ordd_seq.NEXTVAL,
                pl_matrix_common.print_lpn_flag(i_call_type),
                i_batch_no,
                l_float_no,
                DECODE(i_call_type, 'DSP', 'FR' || TRIM(TO_CHAR(l_float_no)), NULL),
                i_order_id,
                DECODE(i_call_type, 'DSP', 'D', NULL));
          
      IF (i_call_type = 'DSP') THEN            
         UPDATE inv
            SET qoh = NVL(qoh, 0) + l_rpl_qty
          WHERE logi_loc = l_splithome_loc; 
                  
         UPDATE  inv
            SET  qoh = NVL(qoh, 0) - l_rpl_qty
         WHERE  CURRENT OF c_inv;

         --
         -- Now create the float record for the DSP replenishment.
         --

         --
         -- 09/30/2015  Brian Bent
         -- For the FLOAT_DETAIL.SRC_LOC we want to use the matrix inventory
         -- location and not the default spur location.  This is to keep things
         -- consistent with the regular picks.  If we were to use the default
         -- spur location, which at this time is SP9999, things would not work
         -- correctly as SP9999 is not setup as a location in SWMS.
         --
         create_float_for_dmd_replen
                       (i_task_id         => l_task_id,
                        i_float_no        => l_float_no,
                        i_route_no        => i_route_no,
                        i_pallet_id       => r_inv.logi_loc,
                        i_src_loc         => r_inv.plogi_loc,
                        i_dest_loc        => l_splithome_loc,
                        i_prod_id         => i_prod_id,
                        i_cpv             => i_cpv,
                        i_order_id        => i_order_id,
                        i_order_line_id   => i_order_line_id,
                        i_stop_no         => i_stop_no,
                        i_rpl_qty         => l_rpl_qty);

                 
      ELSE
         /* Update quantity allocated for Matrix inventory record*/ 
         UPDATE inv
            SET qty_alloc = NVL(qty_alloc, 0) + l_rpl_qty
          WHERE CURRENT OF c_inv;
            
            
         /*Update quantity planned for split home inventory record*/
         UPDATE inv
            SET qty_planned = NVL(qty_planned, 0) + l_rpl_qty
          WHERE logi_loc = l_splithome_loc; 
      END IF;  

      l_remaining := l_remaining - l_rpl_qty;

      o_qty_replenished_in_splits := o_qty_replenished_in_splits + l_rpl_qty;
            
      IF (l_remaining <= 0) THEN
         EXIT;
      END IF;
   END LOOP;
        
END Gen_SplitHome_Case_Replen;



----------------------------------------------------------------------------------
-- Procedure (Private)
--   Gen_DMD_SplitHome_Replen 
--
-- Description
--   This procedure insert Split Home replenishment record into REPLENLST table             
--
-- Parameters
--
--  Input:
--      i_rb_no     Route Batch Number
--      i_route_no  Route Number
--      i_prod_id   Product ID
--      i_cpv       Cust Preferred Vendor
--      i_rpl_qty   Replenishment Quantity
--      i_priority  Priority
--      i_ind_loc   Induction Location
--      i_call_type Call type (NSP, DSP)          
--      i_spc       Quantity in a Case
--      i_batch_no
--      i_slot_type  Should be MXT, MXO, MXI or MXS
--
--  Output:
--      N/A`
--
-- Modification History
--
-- Date         User             Comment
-- --------     ---------        ------------------------------------------
-- 07/21/14     ayad5195         Initial Creation
-- 01/26/15     bben0556         Add out parameter o_qty_replenished_in_splits
-- 06/21/16     bben0556         Brian Bent
--                               Added parameters:
--                                  i_order_id
--                                  i_order_line_id
--                                  i_stop_no
--
--                               Added call to procedure "create_float_for_dmd_replen".
--
--                               Changed parameter "i_def_stg" to "i_slot_type".
--                               We now will select inventory records based on the
--                               slot type and not by a specific location.
----------------------------------------------------------------------------------

PROCEDURE Gen_DMD_SplitHome_Replen
               (i_rb_no                     IN NUMBER,
                i_route_no                  IN VARCHAR2,
                i_prod_id                   IN VARCHAR2,
                i_cpv                       IN VARCHAR2,
                i_rpl_qty                   IN NUMBER,
                i_priority                  IN NUMBER,
                i_spc                       IN NUMBER,
                i_batch_no                  IN NUMBER,
                i_slot_type                 IN loc.slot_type%TYPE,
                i_order_id                  IN float_detail.order_id%TYPE        DEFAULT NULL,
                i_order_line_id             IN float_detail.order_line_id%TYPE   DEFAULT NULL,
                i_stop_no                   IN ordm.stop_no%TYPE                 DEFAULT NULL,
                o_qty_replenished_in_splits OUT NUMBER)
IS
   l_fname             VARCHAR2 (50)       := 'Gen_DMD_SplitHome_Replen';

   l_float_no      floats.float_no%TYPE;    -- Float number for the FLOATS and FLOAT_DETAIL record for DSP replenishment.
                                            -- Populated from sequence.
                                            -- Also used to populate REPLENLST.FLOAT_NO and REPLENLST.LABOR_BATCH_NO for DSP
                                            -- replenishment.  Labor batch number has format 'FR'<float no>
   l_rpl_qty           NUMBER;
   l_remaining         NUMBER;
   l_pallet_seq        NUMBER;
   l_task_id           replenlst.task_id%TYPE;  -- Task id for the REPLENLST record.  Populated from sequence.
   l_status            NUMBER;
   l_splithome_loc     loc.logi_loc%TYPE;        
   /*l_inv_rec   pl_ml_repl_rf.inv_rec;*/
        
   /*Cursor for Matrix inventory available to allocate*/    
   CURSOR  c_inv (p_prod_id  VARCHAR2,
                  p_cpv      VARCHAR2) IS
      SELECT l.pik_path,
             i.logi_loc,
             plogi_loc,
             qoh - NVL(qty_alloc, 0) qoh,
             qty_alloc, 
             exp_date,
             i.parent_pallet_id,
             i.rec_id,
             i.lot_id,
             i.mfg_date,
             i.rec_date,
             i.qty_planned,
             i.inv_date,
             i.min_qty,
             i.abc,
             p.spc,
             i.inv_uom,
             l.slot_type
        FROM pm p,
             zone z,
             lzone lz,
             loc l,
             inv i
       WHERE i.prod_id                      = p_prod_id
         AND i.cust_pref_vendor             = p_CPV
         AND p.prod_id                      = i.prod_id
         AND p.cust_pref_vendor             = i.cust_pref_vendor
         AND i.status                       = 'AVL'
         AND i.inv_uom                      IN (0, 2) 
         AND i.qoh - NVL (i.qty_alloc, 0)   > 0
         AND l.logi_loc                     = i.plogi_loc
         AND lz.logi_loc                    = l.logi_loc
         AND z.zone_id                      = lz.zone_id
         AND z.zone_type                    = 'PUT'
         AND z.rule_id                      = 5
         AND l.slot_type                    = i_slot_type   -- 06/21/2016  Brian Bent  Now we go by slot type.
         -- AND i.plogi_loc                 = i_def_stg     -- 06/21/2016  Brian Bent  Now we go by slot type.
       ORDER BY i.exp_date, i.qoh, i.logi_loc
         FOR UPDATE OF i.qty_alloc NOWAIT;       

BEGIN
        l_remaining := i_rpl_qty;
        o_qty_replenished_in_splits := 0;
        
   /*Find the split home location of product*/
   BEGIN
      SELECT logi_loc 
        INTO l_splithome_loc
        FROM loc l
       WHERE l.prod_id = i_prod_id
         AND l.perm = 'Y'
         AND l.uom = 1
         AND l.rank = 1;
   EXCEPTION
      WHEN OTHERS THEN
         Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Not able to find Split home location for PROD_ID ='||i_prod_id, SQLCODE,SQLERRM);
      RAISE;  
   END;
        
        FOR r_inv IN c_inv (i_prod_id, i_cpv)
        LOOP
            /*If inventory quantity is less than quantity required then whole pallet will be replenished else required quantity*/
            IF r_inv.qoh <= l_remaining THEN
                l_rpl_qty := r_inv.qoh;                              
            ELSE
                l_rpl_qty := l_remaining;  
            END IF;
              

            l_task_id := repl_id_seq.NEXTVAL;
            l_float_no := float_no_seq.NEXTVAL;

            /*Create replenishment task to move from default SPUR location (SP9999) to split home location
              When Matrix sent back the actual SPUR location information, task will be updated with actual SPUR location*/

            --
            -- Wed Jun 22 13:18:00 CDT 2016  Brian Bent *****  The replenlst.qty needs to be in cases. *****
            -- In the VALUES clause changed   l_rpl_qty   to   TRUNC(l_rpl_qty / r_inv.spc)
            --
            INSERT INTO replenlst
                            (task_id,
                             prod_id,
                             cust_pref_vendor,
                             uom,
                             qty,
                             type, 
                             status,
                             src_loc,
                             pallet_id, 
                             dest_loc,
                             gen_uid,
                             gen_date,
                             exp_date,
                             route_no,
                             route_batch_no,
                             priority, 
                             parent_pallet_id,
                             rec_id,
                             lot_id,
                             mfg_date,
                             s_pikpath, 
                             orig_pallet_id,
                             case_no,
                             print_lpn,
                             batch_no,
                             float_no,
                             labor_batch_no,
                             order_id,
                             replen_type)
                      VALUES
                            (l_task_id,
                             i_prod_id,
                             i_cpv,
                             2,
                             TRUNC(l_rpl_qty / r_inv.spc),
                             'DMD',
                             'NEW',
                             r_inv.plogi_loc,
                             r_inv.logi_loc,  
                             l_splithome_loc,
                             REPLACE (USER, 'OPS$'),
                             SYSDATE, 
                             r_inv.exp_date,
                             i_route_no,
                             i_rb_no,
                             i_priority,
                             r_inv.parent_pallet_id,
                             r_inv.rec_id,
                             r_inv.lot_id,
                             r_inv.mfg_date,
                             r_inv.pik_path,
                             DECODE(r_inv.plogi_loc, r_inv.logi_loc, NULL,
                                                     DECODE (r_inv.slot_type, 'MXS', NULL,
                                                                               r_inv.logi_loc)),
                             ordd_seq.NEXTVAL,
                             'N',
                             i_batch_no,
                             l_float_no,
                             'FR' || TRIM(TO_CHAR(l_float_no)),
                             i_order_id,
                             NULL);         

            --
            -- Now create the float record for the DSP replenishment.
            --
            -- For the FLOAT_DETAIL.SRC_LOC we want to use the matrix inventory
            -- location and not the default spur location.  This is to keep things
            -- consistent with the regular picks.  If we were to use the default
            -- spur location, which at this time is SP9999, things would not work
            -- correctly as SP9999 is not setup as a location in SWMS.
            --
            create_float_for_dmd_replen
                       (i_task_id         => l_task_id,
                        i_float_no        => l_float_no,
                        i_route_no        => i_route_no,
                        i_pallet_id       => r_inv.logi_loc,
                        i_src_loc         => r_inv.plogi_loc,
                        i_dest_loc        => l_splithome_loc,
                        i_prod_id         => i_prod_id,
                        i_cpv             => i_cpv,
                        i_order_id        => i_order_id,
                        i_order_line_id   => i_order_line_id,
                        i_stop_no         => i_stop_no,
                        i_rpl_qty         => l_rpl_qty);

          
            
            UPDATE inv
               SET qoh = NVL(qoh, 0) + l_rpl_qty
             WHERE logi_loc = l_splithome_loc;
             
            UPDATE inv
               SET qoh = NVL(qoh, 0) - l_rpl_qty
             WHERE CURRENT OF c_inv;    
              
            l_remaining := l_remaining - l_rpl_qty;
            o_qty_replenished_in_splits := o_qty_replenished_in_splits + l_rpl_qty;

            IF (l_remaining <= 0) THEN
                EXIT;
            END IF;
        END LOOP;
        
    END Gen_DMD_SplitHome_Replen;


    
----------------------------------------------------------------------------------
-- Procedure: (Public)
--     create_matrix_ndm_case_rpl
--
-- Description:
--     This procedure create replenishment tasks for matrix cases. Called when user
--     generates replenishment task from form PN1SB for matrix items. It can also 
--     be called when the cron job runs to create replenishment for Matrix items.
--
-- Parameters:
--   Input:
--    i_call_type               Call Type (NXL, DXL)
--    i_area                    Area
--    i_putzone                 Put Zone
--    i_prod_id                 Product ID
--    i_cust_pref_vendor        Cust Prefered Vendor
--    i_route_batch_no          Route Batch Number
--    i_route_no                Route Number
--    i_qty_reqd                Required Quantity
--    i_uom                     Unit of Measure
--
--   Output:
--    o_status - return value
--          0  - Successful
--          1  - Error
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/16/14 ayad5195 Initial Creation
--    12/03/15 ayad5195 Throttling Changes
----------------------------------------------------------------------------------

    PROCEDURE create_matrix_ndm_case_rpl (
        i_call_type         IN  VARCHAR2    DEFAULT NULL,
        i_area              IN  VARCHAR2    DEFAULT NULL,
        i_putzone           IN  VARCHAR2    DEFAULT NULL,
        i_prod_id           IN  VARCHAR2    DEFAULT NULL,
        i_cust_pref_vendor  IN  VARCHAR2    DEFAULT NULL,
        i_route_batch_no    IN  NUMBER      DEFAULT NULL,
        i_route_no          IN  VARCHAR2    DEFAULT NULL,
        i_qty_reqd          IN  NUMBER      DEFAULT NULL,
        i_uom               IN  NUMBER      DEFAULT 2,
        i_batch_no          IN  NUMBER,
        o_status            OUT NUMBER)
    IS
        l_fname                  VARCHAR2 (50)       := 'create_matrix_ndm_case_rpl';
        l_msg_text               VARCHAR2 (512);
        l_sql_stmt               VARCHAR2 (2048);
        i                        NUMBER (6);
        e_fail                   EXCEPTION;

        TYPE    t_mx_record IS RECORD(prod_id                pm.prod_id%TYPE,
                                      cpv                    pm.cust_pref_vendor%TYPE,
                                      spc                    pm.spc%TYPE,
                                      split_trk              pm.split_trk%TYPE,
                                      ship_split_only        pm.auto_ship_flag%TYPE,                                  
                                      max_mx_cases           NUMBER,
                                      zone_id                pm.zone_id%TYPE,                                     
                                      min_mx_cases           NUMBER,
                                      curr_mx_cases          NUMBER,                                  
                                      curr_resv_cases        NUMBER,
                                      curr_repl_cases        NUMBER,                                  
                                      curr_qty_reqd          NUMBER
                                     );

        r_mx_rpl        t_mx_record;
        
        TYPE ref_RPL IS  REF CURSOR;
        c_RPL          ref_RPL;
        id_curRPL       NUMBER;
        l_result        NUMBER;
    
        /*Common Select clause for all replenishment types*/  
        MX_MAIN_SQL VARCHAR2 (512) :=                                                
                'SELECT v.prod_id, v.cust_pref_vendor, v.spc, v.split_trk,
                        v.ship_split_only, v.max_mx_cases,
                        v.zone_id, 
                        v.min_mx_cases, v.curr_mx_cases, 
                        v.curr_resv_cases, v.curr_repl_cases ';
                        
        /*Quantity required is 0 for Non-Demand (NXL) Home slot to Matrix replenishment */              
        MX_MAIN_SQL2    VARCHAR2 (24) := ', 0 qty_reqd';   
        
        /*Quantity required is order quantity for Demand (DXL) Home slot to Matrix replenishment*/
        MX_MAIN_SQL3    VARCHAR2 (26) := ', fd.qty_order qty_reqd'; 
    
        /*Where clause for Demand (DXL) replenishment*/
        MX_SUB_DXL  VARCHAR2 (512) :=
                '  FROM float_detail fd, v_matrix_reserve_info v ' ||
                ' WHERE fd.route_no = ''' || i_route_no || '''' ||
                '   AND fd.prod_id = v.prod_id ' ||
                '   AND fd.cust_pref_vendor = v.cust_pref_vendor ' ||
                '   AND NVL(v.mx_item_assign_flag, ''N'') = ''Y''' ||
                '   AND v.curr_mx_cases < fd.qty_order / v.spc' ||
                '   AND v.curr_resv_cases > 0';
                
        /*Where clause for Non-Demand (NXL) replenishment*/
        MX_SUB_NXL  VARCHAR2 (512) :=
                '  FROM v_matrix_reserve_info v ' ||
                ' WHERE NVL(v.curr_mx_cases, 0) + NVL(v.curr_repl_cases, 0) <= NVL(v.min_mx_cases, 0)                    
                    AND NVL (v.curr_resv_cases, 0) > 0
                    AND NVL(v.max_mx_cases, 0) > 0 
                    AND NVL(v.mx_item_assign_flag, ''N'') = ''Y''
                    AND v.area = NVL (''' || i_area || ''', v.area)                    
                    AND v.prod_id = NVL (''' || i_prod_id || ''', v.prod_id)
                    AND v.cust_pref_vendor = NVL (''' || i_cust_pref_vendor || ''', v.cust_pref_vendor)';
    
        CURSOR  c_route_mx_prod (p_routeNo VARCHAR2) IS
        SELECT  fd.prod_id, fd.cust_pref_vendor
          FROM  pm p, float_detail fd
         WHERE  fd.route_no = p_routeNo
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  p.mx_item_assign_flag = 'Y';

        l_pri_cd        VARCHAR2 (3);
        l_priority      INTEGER;
        rpl_qty         NUMBER;        
        l_qty           NUMBER := 0;
        acquired_qty    NUMBER := 0;
        deleted_qty     NUMBER := 0;
    BEGIN

        o_status := C_SUCCESS;
        
        -- Generate Non Demand repl (NXL) from reserve locations to Matrix.        
        IF (i_call_type NOT IN ('DXL', 'NXL')) THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Invalid Call Type. ' || i_call_type;
            RAISE e_fail;
        END IF; 
        DBMS_OUTPUT.PUT_LINE ('good call type ' || i_call_type);
    
        pl_text_Log.ins_msg('I', C_PROGRAM_CODE,
            'Generate Matrix Repl for call type = ' || i_call_type, NULL, NULL);
    
        /*Generate cursor query based on replenishment type*/
        SELECT  MX_MAIN_SQL ||
                DECODE (i_call_type,
                        'DXL', MX_MAIN_SQL3,
                               MX_MAIN_SQL2) ||
                DECODE (i_call_type,                
                        'NXL', MX_SUB_NXL,
                        'DXL', MX_SUB_DXL),
                DECODE (i_call_type,
                        'NXL', NDM_PRI_CD,
                        'DXL', DMD_PRI_CD)
          INTO  l_sql_stmt, l_pri_cd
          FROM  DUAL;
        
        /*Find the priority based on replenishment type*/
        BEGIN
            SELECT  priority
              INTO  l_priority
              FROM  matrix_task_priority
             WHERE matrix_task_type = i_call_type
               AND severity = 'NORMAL';
               
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_priority := 99;
        END;
      
        -----For Testing
        DBMS_OUTPUT.PUT_LINE ('sql is ');

        i := 1;
        LOOP
            DBMS_OUTPUT.PUT_LINE (LTRIM (SUBSTR (l_sql_stmt, i, 50)));
            IF ((i + 50) < LENGTH (l_sql_stmt)) THEN
                i := i + 50;
            ELSE
                EXIT;
            END IF;
        END LOOP;
        ------------------
        
        Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
            'SQL IS ' || l_sql_stmt, NULL, NULL);

        OPEN c_RPL FOR l_sql_stmt;
        LOOP
            FETCH c_RPL INTO r_mx_rpl;
            IF (c_RPL%NOTFOUND)
            THEN
                EXIT;
            END IF;

            rpl_qty := (r_mx_rpl.max_mx_cases - NVL(r_mx_rpl.curr_mx_cases, 0)- NVL(r_mx_rpl.curr_repl_cases, 0)) * r_mx_rpl.spc ;
            
            /*IF (i_call_type = 'DMD')
            THEN
                rpl_qty := rpl_qty - l_qty;
            END IF;*/

            Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Create Matrix Replen For Item ' || r_mx_rpl.prod_id ||
                ', Qty = ' || rpl_qty, NULL, NULL);

            IF (rpl_qty > 0) THEN                           
                /* Create replenishment task and update the inventory */ 
                Gen_Matrix_Case_Replen (i_route_batch_no, i_route_no, r_mx_rpl.prod_id,
                                        r_mx_rpl.cpv, rpl_qty, l_priority, --r_mx_rpl.ind_loc, 
                                        i_call_type, r_mx_rpl.spc, i_batch_no);
            END IF;
            
            Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Matrix Replen NXL Task completed For Item ' || r_mx_rpl.prod_id ||
                ', Qty = ' || rpl_qty, NULL, NULL);
        END LOOP;
        
        CLOSE c_RPL; 
    
        EXCEPTION
        WHEN e_fail
        THEN
            Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE;
        WHEN OTHERS
        THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_matrix_ndm_case_rpl.';
            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_msg_text,SQLCODE,SQLERRM);
            o_status := C_FAILURE;
    END create_matrix_ndm_case_rpl;


----------------------------------------------------------------------------------
-- Procedure (Private)
--   Gen_thorttle_Replen_option
--
-- Description
--   This procedure insert record into replenishment table             
--
-- Parameters
--
--  Input:
--      i_rb_no     Route Batch Number
--      i_route_no  Route Number
--      i_prod_id   Product ID
--      i_cpv       Cust Preferred Vendor
--      i_rpl_qty   Replenishment Quantity
--      i_priority  Priority
--      i_ind_loc   Induction Location
--      i_call_type Call type (NXL, DXL)          
--      i_spc       Quantity in a Case
--      i_order_id       The order being processed.
--      i_order_line_id  The order line id being processed.
--      i_stop_no        The stop number being processed.
--
--  Output:
--      N/A
--
-- Modification History
--
-- Date         User             Comment
-- --------     ---------        ------------------------------------------
-- 07/18/14     ayad5195         Initial Creation
----------------------------------------------------------------------------------

    PROCEDURE Gen_thorttle_Replen_option (i_prod_id         IN VARCHAR2,
                                          i_cpv             IN VARCHAR2,
                                          i_rpl_qty         IN NUMBER,
                                          o_remaining_qty  OUT NUMBER                                         
                                      )
    IS
        l_rpl_qty       NUMBER;
        l_remaining     NUMBER;        
        l_fname         VARCHAR2 (50)       := 'Gen_thorttle_Replen_option';
        l_status        NUMBER;       
        
       /*Cursor for reserve inventory available to allocate*/
       CURSOR  c_inv (p_prod_id VARCHAR2,
                      p_CPV    VARCHAR2) IS
        SELECT  i.logi_loc, i.plogi_loc, p.spc, p.descrip, p.hist_case_order, p.wsh_ship_movements, i.qoh, p.mx_throttle_flag
          FROM  pm p, zone z, lzone lz, loc l, inv i
         WHERE  i.prod_id = p_prod_id
           AND  i.cust_pref_vendor = p_CPV
           AND  p.prod_id = i.prod_id
           AND  p.cust_pref_vendor = i.cust_pref_vendor
           AND  i.status = 'AVL'
           AND  i.inv_uom IN (0, 2)
           AND  i.qoh > 0
           AND  NVL (i.qty_alloc, 0) = 0
           AND  l.logi_loc = i.plogi_loc
           AND  i.plogi_loc != i.logi_loc
           AND  lz.logi_loc = l.logi_loc
           AND  z.zone_id = lz.zone_id
           AND  z.zone_type = 'PUT'
           AND  z.induction_loc IS NULL
           AND  z.rule_id IN (0, 1, 2)
           AND  NVL(p.mx_eligible, 'N') = 'Y'
         ORDER  BY i.exp_date, i.qoh, i.logi_loc
           FOR  UPDATE OF i.qty_alloc NOWAIT;       
    BEGIN
        l_remaining := i_rpl_qty;
        Pl_Text_Log.ins_msg ('I', l_fname, 'In Gen_thorttle_Replen_option for Prod_id '||i_prod_id ||'   qty '||i_rpl_qty, NULL,NULL);
               
        FOR r_inv IN c_inv (i_prod_id, i_cpv)
        LOOP
            Pl_Text_Log.ins_msg ('I', l_fname, 'In Gen_thorttle_Replen_option IN Loop  repln qty '||r_inv.qoh, NULL,NULL);
            /* Whole pallet will replenish to Matrix */
            l_rpl_qty := r_inv.qoh;     
            
            INSERT INTO mx_throttle_replenlst_options 
                      (select_flag, prod_id, descrip, pallet_id, location, qoh_case, Throttle_flag, hist_order, wsh_ship_movements)
               VALUES (1, i_prod_id, r_inv.descrip, r_inv.logi_loc, r_inv.plogi_loc, TRUNC(l_rpl_qty/r_inv.spc), NVL(r_inv.mx_throttle_flag,'N') , r_inv.hist_case_order, r_inv.wsh_ship_movements);      
                                                 
                         
            l_remaining := l_remaining - l_rpl_qty;

            IF (l_remaining <= 0) THEN
                EXIT;
            END IF;
        END LOOP;
        o_remaining_qty := l_remaining;
        
    END Gen_thorttle_Replen_option; 
    
----------------------------------------------------------------------------------
-- Procedure: (Public)
--     create_throttle_rpl_options
--
-- Description:
--     This procedure create replenishment tasks for matrix cases. Called when user
--     generates replenishment task from form PN1SB for matrix items. It can also 
--     be called when the cron job runs to create replenishment for Matrix items.
--
-- Parameters:
--   Input:
--    i_call_type               Call Type (NXL, DXL)
--    i_area                    Area
--    i_putzone                 Put Zone
--    i_prod_id                 Product ID
--    i_cust_pref_vendor        Cust Prefered Vendor
--    i_route_batch_no          Route Batch Number
--    i_route_no                Route Number
--    i_qty_reqd                Required Quantity
--    i_uom                     Unit of Measure
--
--   Output:
--    o_status - return value
--          0  - Successful
--          1  - Error
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/16/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------

    PROCEDURE create_throttle_rpl_options (        
        i_area              IN  VARCHAR2    DEFAULT NULL,        
        i_prod_id           IN  VARCHAR2    DEFAULT NULL,
        i_cust_pref_vendor  IN  VARCHAR2    DEFAULT NULL,        
        i_batch_no          IN  NUMBER,
        i_item_type         IN  VARCHAR2    DEFAULT 'BOTH',
        o_status            OUT NUMBER)
    IS
        l_fname                  VARCHAR2 (50)       := 'create_throttle_rpl_options';
        l_msg_text               VARCHAR2 (512);
        l_sql_stmt               VARCHAR2 (2048);
        i                        NUMBER (6);
        e_fail                   EXCEPTION;
        l_hist_order             NUMBER;    
        
        TYPE    t_mx_record IS RECORD(prod_id                pm.prod_id%TYPE,
                                      cpv                    pm.cust_pref_vendor%TYPE,
                                      spc                    pm.spc%TYPE,
                                      split_trk              pm.split_trk%TYPE,
                                      ship_split_only        pm.auto_ship_flag%TYPE,                                  
                                      max_mx_cases           NUMBER,
                                      zone_id                pm.zone_id%TYPE,                                     
                                      min_mx_cases           NUMBER,
                                      curr_mx_cases          NUMBER,                                  
                                      curr_resv_cases        NUMBER,
                                      curr_repl_cases        NUMBER,  
                                      hist_case_order        NUMBER,        
                                      curr_qty_reqd          NUMBER
                                     );

        r_mx_rpl        t_mx_record;
        
        TYPE ref_RPL IS  REF CURSOR;
        c_RPL          ref_RPL;
        id_curRPL       NUMBER;
        l_result        NUMBER;
    
        /*Common Select clause for all replenishment types*/  
        MX_MAIN_SQL VARCHAR2 (512) :=                                                
                'SELECT v.prod_id, v.cust_pref_vendor, v.spc, v.split_trk,
                        v.ship_split_only, v.max_mx_cases,
                        v.zone_id, 
                        v.min_mx_cases, v.curr_mx_cases, 
                        v.curr_resv_cases, v.curr_repl_cases, v.hist_case_order ';
                        
        /*Quantity required is 0 for Non-Demand (NXL) Home slot to Matrix replenishment */              
        MX_MAIN_SQL2    VARCHAR2 (24) := ', 0 qty_reqd';   
      
        /*Where clause for Non-Demand (NXL) replenishment*/
        MX_SUB_NXL  VARCHAR2 (1012) :=
                '  FROM v_matrix_reserve_info v ' ||
                ' WHERE NVL(v.curr_mx_cases, 0) + NVL(v.curr_repl_cases, 0) < NVL(v.hist_case_order, 0)                    
                    AND NVL (v.curr_resv_cases, 0) > 0
                    AND NVL(v.hist_case_order, 0) > 0 
                    AND v.area = NVL (''' || i_area || ''', v.area)          
                    AND TRUNC(v.hist_case_date) = TRUNC(SYSDATE)                                    
                    AND v.prod_id = NVL (''' || i_prod_id || ''', v.prod_id)
                    AND v.cust_pref_vendor = NVL (''' || i_cust_pref_vendor || ''', v.cust_pref_vendor)';
                    
        MX_THROTTLE_ONLY VARCHAR2(512) :=
                 ' AND NVL(v.mx_throttle_flag, ''N'') = ''Y''';     

        MX_SYMBOTIC_ONLY VARCHAR2(512) :=
                 ' AND NVL(v.mx_item_assign_flag, ''N'') = ''Y''';  

        MX_ORDER_BY VARCHAR2(512) :=
                  ' ORDER BY NVL(v.mx_throttle_flag,''A''), v.hist_case_order DESC ';       
    
        rpl_qty                 NUMBER;        
        l_qty                   NUMBER := 0;
        acquired_qty            NUMBER := 0;
        deleted_qty             NUMBER := 0;
        l_mx_throttle_order_max NUMBER := 0;
        l_remaining_qty         NUMBER;
        l_symb_inv_exist        NUMBER;
    BEGIN

        o_status := C_SUCCESS;
       
        pl_text_Log.ins_msg('I', C_PROGRAM_CODE,
            'Generate throttle Repl option', NULL, NULL);
    
        /*Generate cursor query based on replenishment type*/
        SELECT  MX_MAIN_SQL || MX_MAIN_SQL2 || MX_SUB_NXL ||
                DECODE(i_item_type, 'THROTTLE', MX_THROTTLE_ONLY, 'SYMBOTIC', MX_SYMBOTIC_ONLY, NULL) ||
                MX_ORDER_BY 
          INTO  l_sql_stmt
          FROM  DUAL;
        
        -----For Testing
        DBMS_OUTPUT.PUT_LINE ('sql is ');

        i := 1;
        LOOP
            DBMS_OUTPUT.PUT_LINE (LTRIM (SUBSTR (l_sql_stmt, i, 50)));
            IF ((i + 50) < LENGTH (l_sql_stmt)) THEN
                i := i + 50;
            ELSE
                EXIT;
            END IF;
        END LOOP;
        ------------------
        
        Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
            'SQL IS ' || l_sql_stmt, NULL, NULL);

        BEGIN       
            SELECT TO_NUMBER(config_flag_val )
              INTO l_mx_throttle_order_max
              FROM sys_Config
             WHERE config_flag_name ='MX_THROTTLE_ORDER_MAX';
        EXCEPTION
            WHEN OTHERS THEN
                Pl_Text_Log.ins_msg ('W', C_PROGRAM_CODE, 'Unable to get the value for sys_Config MX_THROTTLE_ORDER_MAX' , SQLCODE, SQLERRM);
                RAISE;
        END;
    
        BEGIN
            --Get the inventory already exists in Symbotic to full fill the historical order
            SELECT SUM(DECODE(SIGN(hist_case_order-inv_qty), -1, hist_case_order, inv_qty)) 
             INTO l_symb_inv_exist
             FROM(
                    SELECT p.prod_id , p.hist_case_order, p.spc,
                           TRUNC((SELECT NVL(SUM(qoh - qty_alloc), 0) 
                                    FROM inv i , loc l 
                                   WHERE i.prod_id = p.prod_id 
                                     AND p.cust_pref_vendor = i.cust_pref_vendor
                                     AND I.Plogi_Loc = L.Logi_Loc
                                     AND l.slot_type IN ('MXF', 'MXC')) / p.spc) inv_Qty
                      FROM pm p
                     WHERE TRUNC(hist_case_date) = TRUNC(SYSDATE)
                  );
        EXCEPTION
            WHEN OTHERS THEN
                Pl_Text_Log.ins_msg ('W', C_PROGRAM_CODE, 'Unable to get the existing symbotic historical order inventory' , SQLCODE, SQLERRM);
                l_symb_inv_exist := 0;
        END;
    
        Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Debug l_mx_throttle_order_max ' || l_mx_throttle_order_max ||
                ', l_symb_inv_exist = ' || l_symb_inv_exist, NULL, NULL);
                
        --Reduce the max throttling order limit by already existing Symbotic inventory
        l_mx_throttle_order_max := l_mx_throttle_order_max - l_symb_inv_exist;
        
        OPEN c_RPL FOR l_sql_stmt;
        
        LOOP
            FETCH c_RPL INTO r_mx_rpl;
            
            --EXIT if cursor record completed OR max throttle order limit is generated
            IF (c_RPL%NOTFOUND) OR l_mx_throttle_order_max <= 0
            THEN
                EXIT;
            END IF;

            rpl_qty := (r_mx_rpl.hist_case_order - NVL(r_mx_rpl.curr_mx_cases, 0)- NVL(r_mx_rpl.curr_repl_cases, 0)) * r_mx_rpl.spc ;
            
            /*IF (i_call_type = 'DMD')
            THEN
                rpl_qty := rpl_qty - l_qty;
            END IF;*/

            Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Create Matrix Replen option For Item ' || r_mx_rpl.prod_id ||
                ', Qty=' || rpl_qty/r_mx_rpl.spc || ' curr_mx_cases=' || r_mx_rpl.curr_mx_cases  ||'  l_mx_throttle_order_max=' || l_mx_throttle_order_max || '  hist_case_order='||r_mx_rpl.hist_case_order, NULL, NULL);
            
                        
            IF (rpl_qty > 0) THEN                           
                /* Create replenishment option for user to select */                
                Gen_thorttle_Replen_option (r_mx_rpl.prod_id, r_mx_rpl.cpv, rpl_qty, l_remaining_qty);
                
                IF l_remaining_qty <= 0 THEN
                    --Reduce Max throttle order limit by item historical order
                    Pl_Text_Log.ins_msg ('FATAL', l_fname, 'A l_remaining_qty ='||l_remaining_qty, NULL, NULL);
                    l_mx_throttle_order_max := l_mx_throttle_order_max - r_mx_rpl.hist_case_order;
                ELSE
                    Pl_Text_Log.ins_msg ('FATAL', l_fname, 'B l_remaining_qty ='||l_remaining_qty, NULL, NULL);
                    l_mx_throttle_order_max := l_mx_throttle_order_max + TRUNC(l_remaining_qty/r_mx_rpl.spc) - r_mx_rpl.hist_case_order ;
                END IF;
            END IF;
            
            Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Matrix Replen NXL Task option created For Item ' || r_mx_rpl.prod_id ||
                ', Qty = ' || rpl_qty, NULL, NULL);
        END LOOP;
        
        CLOSE c_RPL; 
    
    EXCEPTION
        WHEN e_fail
        THEN
            Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE;
        WHEN OTHERS
        THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_throttle_rpl_options.';
            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_msg_text,SQLCODE,SQLERRM);
            o_status := C_FAILURE;
    END create_throttle_rpl_options;
    
----------------------------------------------------------------------------------
-- Procedure: (Private)
--     Acquire_MX_NDM_Replen
--
-- Description:
--     This procedure find all matrix non-demand task (NXL and NSP) which is in PIK 
--     status and change the type to demand replenishment and update the inventory. 
--
-- Parameters:
--   Input:
--    i_prod_id      Product ID
--    i_cpv          Cust Prefered Vendor
--
--   Output:
--    o_qty          No of quantity updated
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    11/04/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------  
    PROCEDURE Acquire_MX_NDM_Replen (
            i_prod_id  IN   VARCHAR2,
            i_cpv      IN   VARCHAR2,
            o_qty      OUT  NUMBER)
    IS
        CURSOR c_ndm_rpl IS
            SELECT  r.type, r.pallet_id, r.src_loc, r.dest_loc,
                    r.qty rpl_qty, r.user_id,
                    r.orig_pallet_id, r.prod_id
              FROM  pm p, replenlst r
             WHERE  r.prod_id = i_prod_id
               AND  r.cust_pref_vendor = i_cpv
               AND  p.prod_id = r.prod_id
               AND  p.cust_pref_vendor = r.cust_pref_vendor
               AND  ((r.type ='NXL' AND r.status = 'PIK') OR (r.type ='NSP' AND r.status IN ('PND', 'NEW', 'PIK') ))   
               FOR  UPDATE OF r.op_acquire_flag NOWAIT;
               
        l_fed_stg_loc   inv.plogi_loc%TYPE;    
    BEGIN
        pl_text_Log.ins_msg('I', gl_pkg_name, 'Enter Acquire_MX_NDM_Replen', NULL, NULL);
        o_qty := 0;
        
        FOR r_ndm_rpl IN c_ndm_rpl
        LOOP
            --Find the default matrix staging location
            l_fed_stg_loc := pl_matrix_common.f_get_mx_stg_loc(r_ndm_rpl.prod_id) ;
        
            pl_text_Log.ins_msg('I', gl_pkg_name, 'Acquire_MX_NDM_Replen: Update Replenlst', NULL, NULL);
        
            UPDATE  replenlst
               SET  op_acquire_flag = 'Y'
             WHERE  CURRENT OF c_ndm_rpl;
             
            o_qty := o_qty + r_ndm_rpl.rpl_qty;
                        
            pl_text_Log.ins_msg('I', gl_pkg_name, 'Acquire_MX_NDM_Replen: Update Inv 1', NULL, NULL);
            
            IF r_ndm_rpl.type = 'NXL' THEN
                pl_text_Log.ins_msg('I', gl_pkg_name, 'Acquire_MX_NDM_Replen: Update Inv NXL', NULL, NULL);
                
                UPDATE  inv
                   SET  plogi_loc = l_fed_stg_loc
                 WHERE  logi_loc = r_ndm_rpl.pallet_id
                   AND  plogi_loc = r_ndm_rpl.user_id;
                   
            ELSIF r_ndm_rpl.type = 'NSP' THEN
                pl_text_Log.ins_msg('I', gl_pkg_name, 'Acquire_MX_NDM_Replen: Update Inv NSP-1', NULL, NULL);
                
                UPDATE  inv
                   SET  qoh = qoh + qty_planned,
                        qty_planned = 0                     
                 WHERE  logi_loc = r_ndm_rpl.dest_loc
                   AND  plogi_loc = r_ndm_rpl.dest_loc;
                                   
                pl_text_Log.ins_msg('I', gl_pkg_name, 'Acquire_MX_NDM_Replen: Delete Inv NSP-2', NULL, NULL);
                
                DELETE inv
                 WHERE logi_loc = r_ndm_rpl.pallet_id   
                   AND  plogi_loc = r_ndm_rpl.user_id;
                   
                /*UPDATE    inv
                   SET  qoh = qoh - qty_alloc,
                        qty_alloc = 0
                 WHERE  logi_loc = r_ndm_rpl.pallet_id
                   AND  plogi_loc = r_ndm_rpl.user_id
                   AND  r_ndm_rpl.type = 'RLP';*/
            END IF;    
        END LOOP;
        pl_text_Log.ins_msg('I', gl_pkg_name, 'Exit Acquire_MX_NDM_Replen', NULL, NULL);
    END Acquire_MX_NDM_Replen;
    
    
----------------------------------------------------------------------------------
-- Procedure: (Private)
--     Delete_MX_NDM_Repl
--
-- Description:
--     This procedure find all matrix non-demand task (NXL and NSP) which is in NEW 
--     status and delete them. 
--
-- Parameters:
--   Input:
--    i_prod_id      Product ID
--    i_cpv          Cust Prefered Vendor
--
--   Output:
--    o_qty          No of quantity updated
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    11/04/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------  
    PROCEDURE Delete_MX_NDM_Repl ( i_prod_id  IN   VARCHAR2,
                                   i_cpv      IN   VARCHAR2,
                                   o_qty      OUT  NUMBER)
    IS
        CURSOR c_ndm_rpl IS
            SELECT  r.type, r.pallet_id, r.src_loc, r.dest_loc,
                (p.spc * r.qty) rpl_qty, r.user_id,
                r.orig_pallet_id
              FROM  pm p, replenlst r
             WHERE  r.prod_id = i_prod_id
               AND  r.cust_pref_vendor = i_cpv
               AND  p.prod_id = r.prod_id
               AND  p.cust_pref_vendor = r.cust_pref_vendor
               AND  ((r.type ='NXL' AND  r.status IN ('NEW', 'PRE')) OR (r.type ='NSP' AND  r.status IN ('PRE') ))        
               FOR  UPDATE OF r.op_acquire_flag NOWAIT;
    BEGIN
        pl_text_Log.ins_msg('I', gl_pkg_name, 'Enter Delete_MX_NDM_Repl', NULL, NULL);
        o_qty := 0;
        FOR r_ndm_rpl IN c_ndm_rpl
        LOOP
            pl_text_Log.ins_msg('I', gl_pkg_name, 'Delete_MX_NDM_Repl: Delete Replenlst', NULL, NULL);
            DELETE  replenlst
             WHERE  CURRENT OF c_ndm_rpl;
             
            IF (r_ndm_rpl.type = 'NXL')
            THEN
                o_qty := o_qty + r_ndm_rpl.rpl_qty;
                
                pl_text_Log.ins_msg('I', gl_pkg_name, 'Delete_MX_NDM_Repl: Update Inv', NULL, NULL);
                UPDATE  inv
                   SET  qty_alloc = 0,
                        plogi_loc = r_ndm_rpl.src_loc
                 WHERE  logi_loc = r_ndm_rpl.orig_pallet_id;
                 
                /*pl_text_Log.ins_msg('I', gl_pkg_name, 'Delete_MX_NDM_Repl: Delete Inv', NULL, NULL);
                
                DELETE  inv
                 WHERE  logi_loc = r_ndm_rpl.pallet_id;*/
            END IF;
        END LOOP;
        pl_text_Log.ins_msg('I', gl_pkg_name, 'Exit Delete_MX_NDM_Repl', NULL, NULL);
    END Delete_MX_NDM_Repl;
    

----------------------------------------------------------------------------------
-- Procedure: (Public)
--     create_matrix_dmd_rpl
--
-- Description:
--     This procedure create demand replenishment tasks for matrix cases for all the 
--     item related to input route number. Called with  order generation.
--
--     When creating a case to split home demand replenishment the case inventory is
--     taken from slots in this order:
--        1.  Available inventory in the structure--slot types MXC and MXF.  REPLENLST.TYPE is DSP.
--        2.  Available inventory in a staging location.  REPLENLST.TYPE is DMD.
--        3.  Available inventory in the main warehouse.  Two REPLENLST records created.
--            One to take the pallet in reserve to the default staging location.
--            REPLENLST.TYPE is DXL.  And one to take the required number of cases
--            from staging to the split home.  REPLENLST.TYPE is DMD.
--        4.  Available inventory in the outduct location.  REPLENLST.TYPE is DMD.
--        5.  Available inventory in a spur location.  REPLENLST.TYPE is DMD.
--        6.  Available inventory in the induction location.  REPLENLST.TYPE is DMD.
--
--
--
-- Parameters:
--   Input:
--    i_call_type               Type of DMD to create.
--                              Valid values are:
--                                 DSP - Split home DMD replenishment
--                                       NOTE: The logic in the procedure is
--                                       expecting a split order is not broken
--                                       across zones on a float which it will
--                                       not be as the float building logic
--                                       does not break a split order across zones.
-- 
--                                 DXL - Case DMD replenisment from the
--                                       main warehouse to the "default"
--                                       staging location.
--    i_prod_id                 Product ID
--    i_cust_pref_vendor        Cust Prefered Vendor
--    i_order_id                Order Id being processed.
--    i_order_line_id           order line id being processed.
--    i_route_batch_no          Route Batch Number,  Used to populate REPLENLST.ROUTE_BATCH_NO
--    i_route_no                Route Number
--    i_stop_no                 The stop number being processed.
--    o_qty_replenished         Qty replenished to the split home for a demand repl.
--    o_status                  Return value
--                                 0  - Successful
--                                 1  - Error (Oracle error)
--
-- Called By:
--    - alloc_inv.pc, function ProcessItemWithHome()
--
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/16/14 ayad5195 Initial Creation
--    01/26/15 bben0556 Added out parameter o_qty_replenished_in_splits
--                      and l_qty_replenished_in_splits.
--                      Added processing to return the qty replenished
--                      in o_qty_replenished_in_splits.
--
--                      Added the following parameters so a demand replenishment
--                      can be created at the item-order id level.
--                         - i_order_id 
--                         - i_order_line_id 
--
--                      When specifying at the item level these parameters
--                      need to be set (in addition to i_route_batch_no and
--                      i_route_no):
--                         - i_prod_id
--                         - i_cust_pref_vendor
--                         - i_order_id
--                         - i_order_line_id
--
--                      Added parameter i_call_type.
--                      Added logic to look at the i_call_type and create the
--                      requested DMD.
--
--    08/04/15 bben0556 Brian Bent
--                      Symbotic project
--                      DXL replenishment not always created with the end
--                      result we pick from the main warehouse reserve slot.
--                      Found we are looking at the qty of each individual
--                      float detail record instead of the float detail total.
--                      Changed cursor "c_dmd_case_rpl" to look at the float
--                      detail total.
--
--                      Changed
--      CURSOR c_dmd_case_rpl IS
--          SELECT v.prod_id, v.cust_pref_vendor cpv, v.spc, v.split_trk,
--                 v.ship_split_only, v.max_mx_cases,
--                 v.zone_id, v.min_mx_cases, v.curr_mx_cases, 
--                 v.curr_resv_cases, v.curr_repl_cases, fd.qty_order qty_reqd
--            FROM float_detail fd, v_matrix_reserve_info v 
--           WHERE fd.route_no =  i_route_no 
--             --
--             -- 1/26/15 At the item and order line, if specified
--             AND fd.prod_id           = NVL(i_prod_id, fd.prod_id)
--             AND fd.cust_pref_vendor  = NVL(i_cust_pref_vendor, fd.cust_pref_vendor)
--             AND fd.order_id          = NVL(i_order_id, fd.order_id)
--             AND fd.order_line_id     = NVL(i_order_line_id, fd.order_line_id)
--             --
--             AND fd.prod_id           = v.prod_id 
--             AND fd.cust_pref_vendor  = v.cust_pref_vendor 
--             AND fd.uom               = 2         -- to assure we only look at case orders.
--             AND v.curr_mx_cases      < fd.qty_order / v.spc
--             AND NVL(fd.qty_alloc, 0) < fd.qty_order             -- Only if not already allocated.
--             AND v.curr_resv_cases    > 0;
--
--                      to
--
--      CURSOR c_dmd_case_rpl IS
--          SELECT v.prod_id,
--                 v.cust_pref_vendor cpv,
--                 v.spc,
--                 v.split_trk,
--                 v.ship_split_only,
--                 v.max_mx_cases,
--                 v.zone_id,
--                 v.min_mx_cases,
--                 v.curr_mx_cases,
--                 v.curr_resv_cases,
--                 v.curr_repl_cases,
--                 SUM(fd.qty_order) sum_qty_reqd_as_splits
--            FROM float_detail fd,
--                 v_matrix_reserve_info v
--           WHERE fd.route_no = i_route_no
--             --
--             -- 1/26/15 At the item and order line, if specified
--             AND fd.prod_id           = NVL(i_prod_id, fd.prod_id)
--             AND fd.cust_pref_vendor  = NVL(i_cust_pref_vendor, fd.cust_pref_vendor)
--             AND fd.order_id          = NVL(i_order_id, fd.order_id)
--             AND fd.order_line_id     = NVL(i_order_line_id, fd.order_line_id)
--             --
--             AND fd.prod_id           = v.prod_id
--             AND fd.cust_pref_vendor  = v.cust_pref_vendor
--             AND fd.uom               = 2         -- to assure we only look at case orders.
--             AND NVL(fd.qty_alloc, 0) < fd.qty_order             -- Only if not already allocated.
--             AND v.curr_resv_cases    > 0
--          GROUP BY
--                 v.prod_id,
--                 v.cust_pref_vendor,
--                 v.spc,
--                 v.split_trk,
--                 v.ship_split_only,
--                 v.max_mx_cases,
--                 v.zone_id,
--                 v.min_mx_cases,
--                 v.curr_mx_cases,
--                 v.curr_resv_cases,
--                 v.curr_repl_cases
--           HAVING v.curr_mx_cases      < SUM(fd.qty_order / v.spc);
-- 
-- 
-- 
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    09/30/15 bben0556 Brian Bent
--                      Symbotic project
--
--                      Bug fix--user getting "No LM batch" error message
--                      on RF when attempting to perform a DXL or DSP 
--                      replenishment.
--
--                      FLOATS and FLOAT_DETAIL not created for DXL or DSP
--                      so forklift labor batch not created since the forklift
--                      labor batch is created from the FLOATS and FLOAT_DETAIL
--                      records.
--
--                      Add stop_no parameter.
--
--                      Pass the order_id, order_line_id and stop_no to 
--                      "gen_matrix_case_replen()"
--
--                      Pass the order_id, order_line_id and stop_no to 
--                      "Gen_SplitHome_Case_Replen()"
--
--    10/02/15 bben0556 Brian Bent
--                      Symbotic project
--
--                      Bug fix--unncessary DXL replensishments created because
--                      AVL inventory at the staging, outduct and induction location
--                      was not being considered as available to pick from.
--                      Changed cursor "c_dmd_case_rpl" to consider locations with
--                      slot_type in ('MXT', 'MXO',  MXI') as pickable inventory.
--
--    01/24/16 bben0556 Brian Bent
--                      Changed cursor "c_dmd_case_rpl" to consider locations with
--                      slot_type MXP as pickable inventory.
--
--                      Added conditions to be sure we only look at regular selection
--                      batches.
--                         - floats.pallet_pull = 'N'
--                         - float_detail.merge_alloc_flag IN ('X', 'Y')  (the primary selector)
--
--    05/31/16 bben0556 Brian Bent
--                      Project:
--
--                      The changes I made on 03/17/16 introduced a bug in
--                      version 30.4.1--too many DSP's are getting created. 
--                      I found the bug when doing additional testing on
--                      Sunday morning 5/22/16.  OpCo 007 got the bugging
--                      version on Saturday 5/21/16.
--                      On Sunday afternon we installed at OpCo 007 the version
--                      OpCo 001 has (30.4) has which does not have the bug.
--
--                      I had changed cursor "c_dmd_split_rpl" on 03/17/16 to
--                      select by item and cpv instead of by float_no,
--                      float_detail.seq_no.  That was a mistake.  Changed it
--                      back to select by float_no, float_detail.seq_no.
--
--    06/17/15 bben0556 Brian Bent
--                      Going against the change made on 10/02/15 changed
--                      cursor "c_dmd_case_rpl" to not consider inventory
--                      in MXI slots as pickable inventory.
--                      MXI slots should not control if a demand replenishment
--                      is needed.   We can pick from a MXI slot but only if
--                      there is no other inventory.  We will create a demand
--                      from the main warehouse to staging before we pick from
--                      MXI slots.
--
----------------------------------------------------------------------------------

PROCEDURE create_matrix_dmd_rpl
  (i_call_type                   IN  VARCHAR2                        DEFAULT NULL,
   i_prod_id                     IN  VARCHAR2                        DEFAULT NULL,
   i_cust_pref_vendor            IN  VARCHAR2                        DEFAULT NULL,
   i_order_id                    IN  float_detail.order_id%TYPE      DEFAULT NULL,
   i_order_line_id               IN  float_detail.order_line_id%TYPE DEFAULT NULL,
   i_route_batch_no              IN  NUMBER                          DEFAULT NULL,
   i_route_no                    IN  VARCHAR2                        DEFAULT NULL,                
   i_stop_no                     IN  ordm.stop_no%TYPE               DEFAULT NULL,
   o_qty_replenished_in_splits   OUT NUMBER,
   o_status                      OUT NUMBER)
IS
   l_fname                      VARCHAR2 (50)       := 'create_matrix_dmd_rpl';
   l_msg_text                   VARCHAR2 (512);
   l_sql_stmt                   VARCHAR2 (2048);
   l_qty_replenished_in_splits  NUMBER;  -- Qty replenished to the split home.  
                                         -- This is needed by the alloc_inv.pc,
                                         -- function AllocFromHome().
   i                            NUMBER (6);
   e_fail                       EXCEPTION; 

   TYPE t_mx_record IS RECORD
   (
      prod_id                pm.prod_id%TYPE,
      cpv                    pm.cust_pref_vendor%TYPE,
      spc                    pm.spc%TYPE,
      split_trk              pm.split_trk%TYPE,
      ship_split_only        pm.auto_ship_flag%TYPE,                                  
      max_mx_cases           NUMBER,
      zone_id                pm.zone_id%TYPE,                                     
      min_mx_cases           NUMBER,
      curr_mx_cases          NUMBER,                                  
      curr_resv_cases        NUMBER,
      curr_repl_cases        NUMBER,                                  
      curr_qty_reqd          NUMBER
   );

   r_mx_rpl        t_mx_record;
   id_curRPL       NUMBER;
   l_result        NUMBER;

   --
   -- This cursor selects the float records for a case pick of a matrix item and the
   -- item does not have sufficient qoh in the matrix to cover the qty ordered.
   -- DXL's need to be created for these.
   -- 06/17/2016  Brian Bent  Took out MXI in the "HAVING" because inventory in MXI
   --                         slots should not control if a demand replenishment
   --                         is needed.   We can pick from a MXI slot but only if
   --                         there is no other inventory.  We will create a demand
   --                         from the main warehouse to staging before we pick from
   --                         MXI slots.
   --
   CURSOR c_dmd_case_rpl
   IS
      SELECT v.prod_id,
             v.cust_pref_vendor cpv,
             v.spc,
             v.split_trk,
             v.ship_split_only,
             v.max_mx_cases,
             v.zone_id,
             v.min_mx_cases,
             v.curr_mx_cases,
             v.curr_resv_cases,
             v.curr_repl_cases,
             SUM(fd.qty_order) sum_qty_reqd_as_splits
       FROM float_detail fd,
            v_matrix_reserve_info v
      WHERE fd.route_no = i_route_no
        --
        -- 1/26/15 At the item and order line, if specified
        AND fd.prod_id           = NVL(i_prod_id, fd.prod_id)
        AND fd.cust_pref_vendor  = NVL(i_cust_pref_vendor, fd.cust_pref_vendor)
        AND fd.order_id          = NVL(i_order_id, fd.order_id)
        AND fd.order_line_id     = NVL(i_order_line_id, fd.order_line_id)
        --
        AND fd.prod_id           = v.prod_id
        AND fd.cust_pref_vendor  = v.cust_pref_vendor
        AND fd.uom               = 2               -- To assure we only look at case orders.
        AND NVL(fd.qty_alloc, 0) < fd.qty_order    -- Only if not already allocated.
        AND NVL(v.mx_item_assign_flag, 'N') = 'Y'
        AND v.curr_resv_cases    > 0
      GROUP BY
              v.prod_id,
              v.cust_pref_vendor,
              v.spc,
              v.split_trk,
              v.ship_split_only,
              v.max_mx_cases,
              v.zone_id,
              v.min_mx_cases,
              v.curr_mx_cases,
              v.curr_resv_cases,
              v.curr_repl_cases
     HAVING v.curr_mx_cases + (SELECT NVL(SUM((inv.qoh - inv.qty_alloc) / v.spc), 0)
                                 FROM inv, loc
                                WHERE inv.prod_id          = v.prod_id
                                  AND inv.cust_pref_vendor = v.cust_pref_vendor
                                  AND inv.plogi_loc        = loc.logi_loc
                                  AND inv.status           = 'AVL'
                                  AND inv.inv_uom          IN (0, 2)
                                  AND loc.slot_type        IN ('MXT', 'MXO', 'MXP')
                                  AND loc.perm             = 'N')   -- failsafe
                  < SUM(fd.qty_order / v.spc);



   --
   -- This cursor selects the float records for a split pick of a matrix item and the
   -- item does not have sufficient qoh in the split home slot to cover the qty ordered.
   -- DSP's need to be created for these.
   --
   -- This query is expecting a split order is not broken across zones on a float which it will not
   -- be as the float building logic does not break a split order across zones.
   --
   CURSOR c_dmd_split_rpl(cp_float_no    IN float_detail.float_no%TYPE,
                          cp_seq_no      IN float_detail.seq_no%TYPE)
   IS
      SELECT v.prod_id,
             v.cust_pref_vendor     cpv,
             v.spc,
             v.split_trk,
             v.ship_split_only,
             v.max_mx_cases,
             v.zone_id,
             v.min_mx_cases,
             v.curr_mx_cases,          -- AVL Cases in the matrix, includes induction loc, staging loc, outduct and spurs
             v.split_home_qoh,         -- QOH in the split home in splits.
             v.curr_repl_cases,
             fd.qty_order           qty_reqd,
             v.curr_mx_cases_mxi,
             v.curr_mx_cases_mxo,
             v.curr_mx_cases_mxs,
             v.curr_mx_cases_mxt,
             v.curr_mx_cases_mxp
        FROM float_detail fd,
             v_matrix_splithome_info v
       WHERE 1=1
         AND fd.float_no           = cp_float_no
         AND fd.seq_no             = cp_seq_no
         AND fd.prod_id            = v.prod_id
         AND fd.cust_pref_vendor   = v.cust_pref_vendor
         AND fd.uom                = 1                      -- Only split orders.
         AND NVL(fd.qty_alloc, 0)  < fd.qty_order           -- Only if not already allocated.
         AND v.split_home_qoh      < fd.qty_order ;         -- Only if the split home qoh is < float detail qty ordered.
                                                            -- v.curr_resv_split_qty plit_home_qoh has the current qoh in the split home.
      -- AND v.curr_mx_cases > 0;


   --
   -- This cursor selects the float detail records for a split pick (float_detail.uom = 1)
   -- of a matrix item based on the input parameters.  For each record a check will be made of
   -- the split home qoh against the order qty.
   --
   -- This query is expecting a split order is not broken across zones on a float which it will not
   -- be as the float building logic does not break a split order across zones.
   --
   CURSOR c_dmd_split_prod
   IS
      SELECT fd.prod_id,
             fd.cust_pref_vendor  cpv,
             fd.uom,
             fd.qty_order         qty_reqd,
             fd.qty_order,
             fd.qty_alloc,
             fd.order_id,
             fd.order_line_id,
             fd.float_no,
             fd.seq_no           float_detail_seq_no,
             p.spc
        FROM pm p,
             float_detail fd,
             floats f
       WHERE fd.route_no           = i_route_no
         AND f.float_no            = fd.float_no
         AND f.pallet_pull         = 'N'            -- Only regular selection.
         AND fd.merge_alloc_flag    IN ('X', 'Y')   -- Only the float detail records for the primary selector.
          --
          -- 1/26/15 At the item and order line
         AND fd.prod_id           = i_prod_id
         AND fd.cust_pref_vendor  = i_cust_pref_vendor
         AND fd.order_id          = i_order_id
         AND fd.order_line_id     = i_order_line_id
         --
         AND p.prod_id             = fd.prod_id
         AND p.cust_pref_vendor    = fd.cust_pref_vendor
         AND p.mx_item_assign_flag = 'Y'               
         AND NVL(fd.qty_alloc, 0)  < fd.qty_order      -- Only if not already allocated.
         AND fd.uom = 1;                               -- Only the split order
       
   CURSOR cFD
   IS
      SELECT fd.prod_id,
             fd.cust_pref_vendor cpv
        FROM pm p,
             float_detail fd
       WHERE fd.route_no           = i_route_no
         AND p.prod_id             = fd.prod_id
         AND p.cust_pref_vendor    = fd.cust_pref_vendor
         AND NVL(fd.qty_alloc,0)   < fd.qty_order         -- Only if not already allocated.
         AND p.mx_item_assign_flag = 'Y' ;
           
   l_pri_cd          VARCHAR2(3);
   l_priority        INTEGER;
   rpl_qty           NUMBER;        
   l_qty             NUMBER := 0;
   acquired_qty      NUMBER := 0;
   deleted_qty       NUMBER := 0;
   l_batch_no        NUMBER;
   l_def_staging_loc inv.plogi_loc%TYPE;
   l_ret_val         NUMBER; 
BEGIN
   o_status := C_SUCCESS;        
   o_qty_replenished_in_splits := 0;
       
   pl_text_Log.ins_msg('I', C_PROGRAM_CODE,
            'Generate demand Matrix Repl for route number = ' || i_route_no, NULL, NULL);    

   --
   -- Cleanup any existing NDM's for the items on the route being processed.
   --
   FOR r_rmp IN cFD 
   LOOP
      Acquire_MX_NDM_Replen(r_rmp.prod_id,
                            r_rmp.cpv,
                            acquired_qty);
                                    
      Delete_MX_NDM_Repl(r_rmp.prod_id,
                         r_rmp.cpv,
                         deleted_qty);
   END LOOP;
       
   l_batch_no := repl_cond_seq.NEXTVAL;

   IF (i_call_type IS NULL OR i_call_type = 'DSP')
   THEN
      -------------------------- Matrix Demand Split Replenishment DSP -----------------------------------------------

      --
      -- Process each float detail record that is a matrix item and uom = 1
      --
      FOR r_spl_qty IN c_dmd_split_prod
      LOOP                    
         --
         -- Create task to move Matrix inventory to split home, if it is short in split home  
         --
         -- FOR r_mx_spl_rpl IN c_dmd_split_rpl(r_spl_qty.prod_id, r_spl_qty.cpv)   -- 6/6/2016 Brian Bent.  Mistake to do this.  Use float_no and
         --                                                                         --                       float_detail.seq_no
         FOR r_mx_spl_rpl IN c_dmd_split_rpl(r_spl_qty.float_no, r_spl_qty.float_detail_seq_no)
         LOOP            

            --
            -- Log message to know what is going on.
            --
            pl_log.ins_msg(pl_log.ct_info_msg, l_fname,
                'i_call_type['         || i_call_type                   || ']'
                || '  Item['           || r_spl_qty.prod_id             || ']'
                || '  CPV['            || r_spl_qty.cpv                 || ']'
                || '  SPC['            || TO_CHAR(r_spl_qty.spc)        || ']'
                || '  float_no['       || TO_CHAR(r_spl_qty.float_no)   || ']'
                || '  order_id['       || r_spl_qty.order_id            || ']'
                || '  order_line_id['  || TO_CHAR(r_spl_qty.order_line_id)  || ']'
                || '  uom['            || TO_CHAR(r_spl_qty.uom)        || ']'
                || '  qty_reqd['       || TO_CHAR(r_spl_qty.qty_reqd)   || ']'
                || '  qty_order['      || TO_CHAR(r_spl_qty.qty_order)  || ']'
                || '  qty_alloc['      || TO_CHAR(r_spl_qty.qty_alloc)  || ']'
                || '  split_home_qoh(in splits)['         || TO_CHAR(r_mx_spl_rpl.split_home_qoh) || ']'
                || '  curr_mx_cases(qoh in matrix locations(rule 5,in cases)[' || TO_CHAR(r_mx_spl_rpl.curr_mx_cases)    || ']'
                || '  Split order and there is not enough qoh in the split home to cover the qty ordered.'
                || '  Create a DSP replenishment.  If the matrix does not have sufficient qty to cover'
                || ' the splits ordered and there are LP''s in main warehouse reserve then create a DXL'
                || ' from main warehouse reserve to the default staging location then a DMD from the'
                || ' default staging location to the split home.',
                NULL, NULL, ct_app_func, gl_pkg_name);


            IF (r_mx_spl_rpl.curr_mx_cases > 0)
            THEN
               --
               -- The item has available cases in the matrix structure.
               --

               -- Find the priority based on replenishment type and Severity
               l_priority := pl_matrix_common.mx_rpl_task_priority('DSP','NORMAL');                
                    
               rpl_qty := r_mx_spl_rpl.qty_reqd - r_mx_spl_rpl.split_home_qoh;

                    
               Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                        'Create Demand Split Home (DSP) Replen For Item ' || r_mx_spl_rpl.prod_id ||
                        ', Qty = ' || rpl_qty, NULL, NULL);

               IF (rpl_qty > 0) THEN
                  -- Create replenishment task and update the inventory
                  BEGIN
                     --
                     -- "Gen_SplitHome_Case_Replen" only creates a DSP from available inventory in the structure--MFC and MXF slots.
                     -- For a DSP the split home qoh would be increased.
                     --
                     Gen_SplitHome_Case_Replen
                                      (i_rb_no                     => i_route_batch_no,
                                       i_route_no                  => i_route_no,
                                       i_prod_id                   => r_mx_spl_rpl.prod_id,
                                       i_cpv                       => r_mx_spl_rpl.cpv,
                                       i_rpl_qty                   => rpl_qty,
                                       i_priority                  => l_priority,
                                       i_call_type                 => 'DSP',
                                       i_spc                       => r_mx_spl_rpl.spc,
                                       i_batch_no                  => l_batch_no,
                                       i_order_id                  => i_order_id,
                                       i_order_line_id             => i_order_line_id,
                                       i_stop_no                   => i_stop_no,
                                       o_qty_replenished_in_splits => l_qty_replenished_in_splits);

                     pl_log.ins_msg(pl_log.ct_info_msg, l_fname,
                         'After call to "Gen_SplitHome_Case_Replen"  l_qty_replenished_in_splits[' || TO_CHAR(l_qty_replenished_in_splits) || ']',
                         NULL, NULL, ct_app_func, gl_pkg_name);
--xxxxxxxxxxx

                     o_qty_replenished_in_splits := o_qty_replenished_in_splits + l_qty_replenished_in_splits;
                  EXCEPTION
                     WHEN OTHERS THEN
                        IF (i_prod_id IS NULL) THEN
                           Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,'Gen_SplitHome_Case_Replen failed for prod_id '||r_mx_spl_rpl.prod_id,SQLCODE,SQLERRM);
                        ELSE
                           RAISE;
                        END IF; 
                  END;    
               END IF; 
            END IF;     
         END LOOP;  -- end FOR r_mx_spl_rpl IN c_dmd_split_rpl(r_spl_qty.float_no, r_spl_qty.float_detail_seq_no)

         --
         -- If split home quantity still short (which means we did not have enough qty in the
         -- structure to cover the splits ordered) then create demand replenishment task(s)
         -- to get the required qty in the split home as follows:
         --    - Available inventory in MXP slots.  REPLENLST.TYPE is DMD.
         --    - Available inventory in a staging location.  REPLENLST.TYPE is DMD.
         --    - Available inventory in the main warehouse.  Two REPLENLST records created.
         --      One to take the pallet in reserve to the default staging location.
         --      REPLENLST.TYPE is DXL.  And one to take the required number of cases
         --      from staging to the split home.  REPLENLST.TYPE is DMD.
         --    - Available inventory in the outduct location.  REPLENLST.TYPE is DMD.
         --    - Available inventory in a spur location.  REPLENLST.TYPE is DMD.
         --    - Available inventory in the induction location.  REPLENLST.TYPE is DMD.
         --
         FOR r_mx_spl_rpl2 IN c_dmd_split_rpl(r_spl_qty.float_no, r_spl_qty.float_detail_seq_no)
         LOOP    
            rpl_qty := r_mx_spl_rpl2.qty_reqd - r_mx_spl_rpl2.split_home_qoh; 
            l_priority := pl_matrix_common.mx_rpl_task_priority('DXL','URGENT');

           --
           -- 06/2/2016  Brian Bent  My poor mans way to loop through the location
           -- types in creating a demand replenishment to the split home.
           -- There is a EXIT in the loop once the necessary replenishments
           -- are created.
           -- Note the WHSE in the select.
           --
            FOR r_replen_from_where IN
               (          SELECT 'MXP'  slot_type, 1 order_by FROM DUAL
                UNION ALL SELECT 'MXT'  slot_type, 2 order_by FROM DUAL
                UNION ALL SELECT 'WHSE' slot_type, 3 order_by FROM DUAL
                UNION ALL SELECT 'MXO'  slot_type, 4 order_by FROM DUAL
                UNION ALL SELECT 'MXS'  slot_type, 5 order_by FROM DUAL
                UNION ALL SELECT 'MXI'  slot_type, 6 order_by FROM DUAL
                ORDER BY 2)
            LOOP
               IF (rpl_qty <= 0) THEN
                  EXIT;    -- leave for loop.  Necessary DMD replenishment(s) to split home created.
               ELSE
                  --
                  -- The split home quantity still short.
                  --
                  -- A little different processing when we need to replenishment from
                  -- main warehouse reserve.
                  --
                  IF (r_replen_from_where.slot_type = 'WHSE') THEN
                     --
                     -- Create task to move inventory from warehouse to matrix staging
                     -- location (DXL) and create split home demand task (DMD) from
                     -- staging location to split home.
                     --
                     -- Find the priority based on replenishment type and Severity
                     l_priority := pl_matrix_common.mx_rpl_task_priority('DXL','URGENT');
                        
                     --
                     -- Create replenishment task to move inventory from warehouse to matrix default staging location
                     --
                     l_def_staging_loc := pl_matrix_common.f_get_mx_stg_loc(r_mx_spl_rpl2.prod_id);

                     Gen_Matrix_Case_Replen
                                  (i_route_batch_no,
                                   i_route_no,
                                   r_mx_spl_rpl2.prod_id,
                                   r_mx_spl_rpl2.cpv,
                                   rpl_qty,
                                   l_priority,
                                   --r_mx_spl_rpl2.ind_loc, 
                                   'DXL',
                                   r_mx_spl_rpl2.spc,
                                   l_batch_no,
                                   l_def_staging_loc,
                                   i_order_id,
                                   i_order_line_id,
                                   i_stop_no);
                        
                     -- Find the priority based on replenishment type and Severity
                     l_priority := pl_matrix_common.mx_rpl_task_priority('DSP','NORMAL');    
                        
                     -- Create demand replenishment to move inventory from Matrix default staging location to split home
                     Gen_DMD_SplitHome_Replen
                                    (i_rb_no                     => i_route_batch_no,
                                     i_route_no                  => i_route_no,
                                     i_prod_id                   => r_mx_spl_rpl2.prod_id,
                                     i_cpv                       => r_mx_spl_rpl2.cpv,
                                     i_rpl_qty                   => rpl_qty,
                                     i_priority                  => l_priority, 
                                     i_spc                       => r_mx_spl_rpl2.spc,
                                     i_batch_no                  => l_batch_no,
                                     i_slot_type                 => 'MXT',
                                     i_order_id                  => i_order_id,
                                     i_order_line_id             => i_order_line_id,
                                     i_stop_no                   => i_stop_no,
                                     o_qty_replenished_in_splits => l_qty_replenished_in_splits);                        

                     rpl_qty := rpl_qty - l_qty_replenished_in_splits;
                     o_qty_replenished_in_splits := o_qty_replenished_in_splits + l_qty_replenished_in_splits;
                  ELSE
                     --
                     -- Create DMD to split home.
                     --
                     Gen_DMD_SplitHome_Replen
                                    (i_rb_no                     => i_route_batch_no,
                                     i_route_no                  => i_route_no,
                                     i_prod_id                   => r_mx_spl_rpl2.prod_id,
                                     i_cpv                       => r_mx_spl_rpl2.cpv,
                                     i_rpl_qty                   => rpl_qty,
                                     i_priority                  => l_priority, 
                                     i_spc                       => r_mx_spl_rpl2.spc,
                                     i_batch_no                  => l_batch_no,
                                     i_slot_type                 => r_replen_from_where.slot_type,
                                     i_order_id                  => i_order_id,
                                     i_order_line_id             => i_order_line_id,
                                     i_stop_no                   => i_stop_no,
                                     o_qty_replenished_in_splits => l_qty_replenished_in_splits);                        
                     rpl_qty := rpl_qty - l_qty_replenished_in_splits;
                     o_qty_replenished_in_splits := o_qty_replenished_in_splits + l_qty_replenished_in_splits;
                  END IF;
               END IF;
            END LOOP; -- end FOR r_replen_from_where
         END LOOP;    -- end FOR r_mx_spl_rpl2 IN c_dmd_split_rpl(r_spl_qty.float_no, r_spl_qty.float_detail_seq_no)
      END LOOP;       -- end FOR r_spl_qty IN c_dmd_split_prod
   END IF;            -- end (i_call_type IS NULL OR i_call_type = 'DSP')

   pl_log.ins_msg(pl_log.ct_info_msg, l_fname,
                  'o_qty_replenished_in_splits['
                  || TO_CHAR(o_qty_replenished_in_splits) || ']',
                  NULL, NULL,
                  ct_app_func, gl_pkg_name);

        
        
   -------------------------- Matrix Demand Case Replenishment DXL -----------------------------------------------

   -- Find the priority based on replenishment type and Severity
   l_priority := pl_matrix_common.mx_rpl_task_priority('DXL','NORMAL');
        
   IF (i_call_type IS NULL OR i_call_type = 'DXL')
   THEN
      FOR r_mx_dmd_rpl IN c_dmd_case_rpl
      LOOP            

         rpl_qty := r_mx_dmd_rpl.sum_qty_reqd_as_splits ;
            
         /*IF (i_call_type = 'DMD')
         THEN
            rpl_qty := rpl_qty - l_qty;
         END IF;*/

         Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Create Case Matrix Replen DXL For Item ' || r_mx_dmd_rpl.prod_id ||
                ', Qty = ' || rpl_qty, NULL, NULL);
            
         l_def_staging_loc := pl_matrix_common.f_get_mx_stg_loc(r_mx_dmd_rpl.prod_id);
            
         IF (rpl_qty > 0) THEN                           
            -- Create replenishment task and update the inventory
            Gen_Matrix_Case_Replen
                                  (i_route_batch_no,
                                   i_route_no,
                                   r_mx_dmd_rpl.prod_id,
                                   r_mx_dmd_rpl.cpv,
                                   rpl_qty,
                                   l_priority,  
                                   'DXL',
                                   r_mx_dmd_rpl.spc,
                                   l_batch_no,
                                   l_def_staging_loc,
                                   i_order_id,
                                   i_order_line_id,
                                   i_stop_no);
         END IF;
            
         Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Matrix Replen DXL Task completed For Item ' || r_mx_dmd_rpl.prod_id ||
                ', Qty = ' || rpl_qty, NULL, NULL);
      END LOOP;     
   END IF;  -- end IF (i_call_type IS NULL OR i_call_type = 'DXL')
     
   --
   -- Sending SYS05 Message FOR DSP Tasks to Symbotic
   --
   l_ret_val := send_SYS05_to_matrix
                             (i_batch_no      => l_batch_no,
                              i_replen_type   => 'DSP',
                              i_replen_status => 'PND');
        
   IF l_ret_val = C_FAILURE THEN
      l_msg_text := '  pl_matrix_repl.create_matrix_dmd_rpl: MESSAGE= Failed to send message SYS05 to matrix for batch_no '||l_batch_no;
       RAISE e_fail;
   END IF;
        
EXCEPTION
   WHEN e_fail THEN
      Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
      o_status := C_FAILURE;
   WHEN OTHERS THEN
      l_msg_text := 'Prog Code: ' || l_fname
             || ' Error in executing create_matrix_dmd_rpl.';
      Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_msg_text,SQLCODE,SQLERRM);
      o_status := C_FAILURE;
END create_matrix_dmd_rpl;
   
   
----------------------------------------------------------------------------------
-- Function: (Public)
--     send_SYS05_to_matrix
--
-- Description:
--     This procedure send SYS05 (release pallet to SPUR) message to Matrix.
--
-- Parameters:
--   Input:
--    i_batch_no                Batch Number
--    i_replen_type             Replenishment Type
--
--   Output:
--      status - return value
--          0  - Successful
--          1  - Error
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    11/05/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------
    FUNCTION send_SYS05_to_matrix(
        i_batch_no          IN  NUMBER ,
        i_replen_type       IN  VARCHAR2    DEFAULT NULL,
        i_replen_status     IN  VARCHAR2    DEFAULT NULL)
    RETURN NUMBER IS
        CURSOR c_repln IS
            SELECT p.case_cube, 
                   r.type,
                   p.spc,
                   r.qty,
                   r.task_id,
                   r.prod_id,
                   r.pallet_id,
                   r.exp_date,
                   r.rec_id,
                   r.dest_loc,
                   r.case_no,
                   p.descrip,
                   p.pack,
                   p.prod_size,
                   p.brand,
                   DECODE(p.mx_food_type, 'NON-FOOD', 'FOOD', p.mx_food_type) mx_food_type
              FROM pm p,
                   replenlst r            
             WHERE p.prod_id = r.prod_id
               AND r.type = NVL(i_replen_type, r.type)
               AND r.status = NVL(i_replen_status, r.status)
               AND r.batch_no = i_batch_no
              ORDER BY p.mx_food_type ;        
               
        l_fname             VARCHAR2 (50)       := 'send_SYS05_to_matrix';
        l_batch_case_cube   NUMBER(7, 4) := 0;
        l_sys_msg_id        NUMBER;
        l_ret_val           NUMBER;
        l_rec_cnt           NUMBER := 0;
        l_sequence_number   NUMBER;
        l_message           VARCHAR2 (512);
        l_case_qty          NUMBER;
        l_case_barcode      VARCHAR2(20);
        l_print_stream      CLOB;
        l_mx_batch_no       NUMBER;
        l_mx_max_case_cube  NUMBER(7, 4);
        e_fail              EXCEPTION;
        o_status            NUMBER;
        l_first_time        NUMBER := 1;
        l_prev_mx_food_type pm.mx_food_type%TYPE;
        l_exact_pallet_imp  VARCHAR2(4);
    BEGIN
        o_status := C_SUCCESS;  
        pl_text_Log.ins_msg('I', C_PROGRAM_CODE,
            'Send SYS05 message to Matrix for Btach number = ' || i_batch_no ||'  i_replen_type = '||i_replen_type||'   i_replen_status = '||i_replen_status , NULL, NULL); 
            
        l_mx_batch_no := mx_batch_no_seq.NEXTVAL;
        l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;      
        
        BEGIN
            l_mx_max_case_cube := NVL(pl_matrix_common.get_sys_config_val('MX_MAX_BATCH_CASE_CUBE'), 40);
        EXCEPTION
            WHEN OTHERS THEN
                 pl_text_Log.ins_msg('I', C_PROGRAM_CODE,
                        'Failed to get the value for SYSPAR MX_MAX_BATCH_CASE_CUBE' , SQLCODE, SQLERRM); 
    
                l_mx_max_case_cube := 40;
        END;
        
        FOR rec IN c_repln
        LOOP
            
            IF l_first_time = 1 THEN
                l_prev_mx_food_type := rec.mx_food_type;
                l_first_time := 0;
            END IF;
            
            pl_text_Log.ins_msg('I', C_PROGRAM_CODE,
                        'Information  : l_prev_mx_food_type:'||l_prev_mx_food_type ||'  rec.mx_food_type :'||rec.mx_food_type ||'  l_rec_cnt:'||l_rec_cnt  , NULL, NULL); 
                        
        
            /*Create separate batch for FOOD/NON-FOOD and CAUSTIC item*/ 
            IF l_prev_mx_food_type != rec.mx_food_type AND l_rec_cnt != 0 THEN
                l_prev_mx_food_type := rec.mx_food_type;
                
                l_batch_case_cube := 0;
                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                        i_interface_ref_doc => 'SYS05',
                                                        i_label_type => 'MSKU',   --LPN
                                                        i_parent_pallet_id => NULL,
                                                        i_rec_ind => 'H',    ---H OR D      
                                                        i_trans_type => rec.type,                                                           
                                                        i_rec_count => l_rec_cnt,
                                                        i_batch_id =>l_mx_batch_no,
                                                        i_order_gen_time => TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'),
                                                        i_priority => 2  
                                                       ); 
                IF l_ret_val = 1 THEN
                    l_message := '  pl_matrix_common.populate_matrix_out: MESSAGE= Failed to insert header record into matrix_out for sys_msg_id '||l_sys_msg_id;
                    RAISE e_fail;
                END IF;   
                
                COMMIT;
                
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
            
                IF l_ret_val = 1 THEN
                    l_message := '  pl_matrix_common.send_message_to_matrix: MESSAGE= Failed to send message to Symbotic for sys_msg_id '||l_sys_msg_id;
                    RAISE e_fail;
                END IF;
                
                l_mx_batch_no := mx_batch_no_seq.NEXTVAL;
                l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                l_rec_cnt := 0;
                
            END IF;
            
            l_batch_case_cube := l_batch_case_cube + TRUNC(rec.qty / rec.spc) * rec.case_cube;
            
            UPDATE replenlst
               SET mx_batch_no = l_mx_batch_no
             WHERE task_id = rec.task_id ;
             
            BEGIN
                SELECT mx_exact_pallet_imp
                  INTO l_exact_pallet_imp
                  FROM mx_replen_type
                 WHERE type = rec.type
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS THEN
                    Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Not able to find mx_exact_pallet_imp from table mx_replen_type for type ['||rec.type || ']', SQLCODE, SQLERRM);
                    l_exact_pallet_imp := 'LOW';
            END;
            
            l_case_qty := TRUNC(rec.qty/rec.spc);
            
            ---Insert detail record in matrix_out for a pallet
            l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                              i_interface_ref_doc => 'SYS05',
                                                              i_label_type => 'MSKU',   --LPN
                                                              i_parent_pallet_id => NULL,
                                                              i_rec_ind => 'D',    ---H OR D  
                                                              i_pallet_id => rec.pallet_id,
                                                              i_prod_id => rec.prod_id,
                                                              i_case_qty => l_case_qty,
                                                              i_exp_date => rec.exp_date,
                                                              i_erm_id => rec.rec_id,
                                                              i_batch_id => l_mx_batch_no,
                                                              i_trans_type => i_replen_type,
                                                              i_task_id => rec.task_id,
                                                              i_dest_loc => rec.dest_loc,
                                                              i_exact_pallet_imp => l_exact_pallet_imp                                                        
                                                             ); 
                                                             
            IF l_ret_val = C_FAILURE THEN
                l_message := '  pl_matrix_repl.send_SYS05_to_matrix: MESSAGE= Failed to insert detail record into matrix_out for pallet_id '||rec.pallet_id;
                RAISE e_fail;
            END IF;
            
            --find the sequence number of the above inserted record in matrix_out
            BEGIN
                SELECT sequence_number 
                  INTO  l_sequence_number
                  FROM (  SELECT sequence_number
                            FROM matrix_out 
                           WHERE pallet_id = rec.pallet_id
                             AND sys_msg_id =l_sys_msg_id
                             AND interface_ref_doc = 'SYS05'
                             AND trans_type = 'DSP'
                             AND prod_id = rec.prod_id
                           ORDER BY sequence_number DESC)
                 WHERE rownum = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    l_message := '  pl_matrix_repl.send_SYS05_to_matrix: MESSAGE= Failed to get the sequence number from matrix_out for pallet_id '||rec.pallet_id;
                    RAISE e_fail;
            END;
            
            --Populate case number and Label in table matrix_out_label 
            BEGIN
                FOR i IN 1..l_case_qty
                LOOP
                    l_case_barcode := TRIM(rec.case_no) || LPAD(i, 3, '0');
                    
                    l_ret_val := pl_matrix_common.insert_repl_sys05_label(i_caseBarCode      => l_case_barcode,
                                                                          i_destLoc          => rec.dest_loc,
                                                                          i_pallet_id        => rec.pallet_id,
                                                                          i_prod_id          => rec.prod_id,
                                                                          i_descrip          => rec.descrip,
                                                                          i_pack             => rec.pack,
                                                                          i_prod_size        => rec.prod_size,
                                                                          i_brand            => rec.brand,
                                                                          i_type             => rec.type,
                                                                          i_sequence_number  => l_sequence_number);
                    
                    IF l_ret_val = C_FAILURE THEN
                        l_message := '  pl_matrix_repl.send_SYS05_to_matrix: MESSAGE= Failed to insert in matrix_out_label for sequence number '||l_sequence_number ||' and barcode '||l_case_barcode;
                        RAISE e_fail;
                    END IF;
                END LOOP;           
            END;
          
            l_rec_cnt := l_rec_cnt + 1;
            
            --When batch_case_cube > matrix MAX cube (SYSPAR) write header record in matrix_out and then start new matrix batch     
            IF l_batch_case_cube > l_mx_max_case_cube THEN
                l_batch_case_cube := 0;
                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                        i_interface_ref_doc => 'SYS05',
                                                        i_label_type => 'MSKU',   --LPN
                                                        i_parent_pallet_id => NULL,
                                                        i_rec_ind => 'H',    ---H OR D      
                                                        i_trans_type => i_replen_type,                                                           
                                                        i_rec_count => l_rec_cnt,
                                                        i_batch_id =>l_mx_batch_no,
                                                        i_order_gen_time => TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'),
                                                        i_priority => 2  
                                                       ); 
                IF l_ret_val = 1 THEN
                    l_message := '  pl_matrix_common.populate_matrix_out: MESSAGE= Failed to insert header record into matrix_out for sys_msg_id '||l_sys_msg_id;
                    RAISE e_fail;
                END IF;   
                
                COMMIT;
                
                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
            
                IF l_ret_val = 1 THEN
                    l_message := '  pl_matrix_common.send_message_to_matrix: MESSAGE= Failed to send message to Symbotic for sys_msg_id '||l_sys_msg_id;
                    RAISE e_fail;
                END IF;
                
                l_mx_batch_no := mx_batch_no_seq.NEXTVAL;
                l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                l_rec_cnt := 0;
            END IF;         
        END LOOP;
        
        IF l_rec_cnt != 0 THEN
            l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                              i_interface_ref_doc => 'SYS05',
                                                              i_label_type => 'MSKU',   --LPN
                                                              i_parent_pallet_id => NULL,
                                                              i_rec_ind => 'H',    ---H OR D  
                                                              i_trans_type => i_replen_type,                                                         
                                                              i_rec_count => l_rec_cnt,
                                                              i_batch_id =>l_mx_batch_no ,
                                                              i_order_gen_time => TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'),
                                                              i_priority => 2   
                                                             ); 
            IF l_ret_val = 1 THEN
                l_message := '  pl_matrix_common.populate_matrix_out: MESSAGE= Failed to insert header record into matrix_out for sys_msg_id '||l_sys_msg_id;
                RAISE e_fail;
            END IF;                
            
            COMMIT;
            
            l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
            
            IF l_ret_val = 1 THEN
                l_message := '  PN1MX-COMMIT_REPL: pl_matrix_common.send_message_to_matrix: MESSAGE= Failed to send message to Symbotic for sys_msg_id '||l_sys_msg_id;
                RAISE e_fail;
            END IF;            
            
        END IF;
        RETURN o_status;
    EXCEPTION
        WHEN e_fail THEN
            Pl_Text_Log.ins_msg ('FATAL', l_fname, l_message, NULL, NULL);
            o_status := C_FAILURE;
            RETURN o_status;
        WHEN OTHERS THEN
            l_message := 'Prog Code: ' || l_fname
                || ' Error in executing send_SYS05_to_matrix.';
            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_message,SQLCODE,SQLERRM);
            o_status := C_FAILURE;  
            RETURN o_status;
    END send_SYS05_to_matrix;

----------------------------------------------------------------------------------
-- Procedure: (Public)
--     create_split_home_rpl
--
-- Description:
--     This procedure create replenishment tasks for main warehouse split from Matrix. 
--     Called when user generates replenishment task from form PN1SB for matrix items.  
--     It can also be called when the cron job runs to create replenishment for Matrix items.
--
-- Parameters:
--   Input:
--    i_call_type               Call Type (NSP, DSP)
--    i_area                    Area
--    i_putzone                 Put Zone
--    i_prod_id                 Product ID
--    i_cust_pref_vendor        Cust Prefered Vendor
--    i_route_batch_no          Route Batch Number
--    i_route_no                Route Number
--    i_qty_reqd                Required Quantity
--    i_uom                     Unit of Measure
--
--   Output:
--    o_status - return value
--          0  - Successful
--          1  - Error
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/21/14 ayad5195 Initial Creation
--    01/26/16 bben0556 Added variable l_qty_replenished_in_splits and
--                      put in call to procedure Gen_SplitHome_Case_Replen().
--                      It will not get used in this particular procedure.
--                      It was added because Gen_SplitHome_Case_Replen() was
--                      changed as part of split home demand replenishment
--                      processing.
--
----------------------------------------------------------------------------------

    PROCEDURE  create_split_home_rpl(
        i_call_type         IN  VARCHAR2    DEFAULT NULL,
        i_area              IN  VARCHAR2    DEFAULT NULL,
        i_putzone           IN  VARCHAR2    DEFAULT NULL,
        i_prod_id           IN  VARCHAR2    DEFAULT NULL,
        i_cust_pref_vendor  IN  VARCHAR2    DEFAULT NULL,
        i_route_batch_no    IN  NUMBER      DEFAULT NULL,
        i_route_no          IN  VARCHAR2    DEFAULT NULL,
        i_qty_reqd          IN  NUMBER      DEFAULT NULL,
        i_uom               IN  NUMBER      DEFAULT 2,
        i_batch_no          IN  NUMBER,
        o_status            OUT     NUMBER)
    IS        
        l_fname                  VARCHAR2 (50)       := 'create_split_home_rpl';
        l_msg_text               VARCHAR2 (512);
        l_sql_stmt               VARCHAR2 (2048);
        i                        NUMBER (6);
        l_qty_replenished_in_splits  NUMBER;
        e_fail                   EXCEPTION;

        TYPE t_splhome_record IS RECORD
        (
           prod_id                      pm.prod_id%TYPE,
           cpv                          pm.cust_pref_vendor%TYPE,
           spc                          pm.spc%TYPE,
           split_trk                    pm.split_trk%TYPE,
           ship_split_only              pm.auto_ship_flag%TYPE,                                  
           max_mx_cases                 NUMBER,
           zone_id                      pm.zone_id%TYPE,                                           
           min_mx_cases                 NUMBER,
           curr_mx_cases                NUMBER,  
           curr_repl_cases              NUMBER,
           split_home_qoh_qty_planned   NUMBER,
           case_qty_for_split_rpl       pm.case_qty_for_split_rpl%TYPE,
           curr_qty_reqd                NUMBER
        );

        r_splhome_rpl        t_splhome_record;          
        
        TYPE ref_RPL IS  REF CURSOR;
        c_RPL          ref_RPL;
        id_curRPL       NUMBER;
        l_result        NUMBER;
    
        /*Common Select clause for all replenishment types*/
        MX_MAIN_SQL VARCHAR2 (512) :=                                      
                'SELECT v.prod_id, v.cust_pref_vendor, v.spc, v.split_trk,
                        v.ship_split_only, v.max_mx_cases,
                        v.zone_id, 
                        v.min_mx_cases, v.curr_mx_cases, 
                        v.curr_repl_cases, v.split_home_qoh_qty_planned, v.case_qty_for_split_rpl ';
                        
        /*Quantity required is 0 for Non-Demand (NSP) Matrix to split home replenishment*/              
        MX_MAIN_SQL2    VARCHAR2 (24) := ', 0 qty_reqd';   
        /*Quantity required is order quantity for Demand (DSP) Matrix to home slot replenishment*/
        MX_MAIN_SQL3    VARCHAR2 (26) := ', fd.qty_order qty_reqd';         
    
        /* Where clause for Demand (DSP) replenishment*/
        MX_SUB_DSP  VARCHAR2 (512) :=
                '  FROM float_detail fd, v_matrix_splithome_info v ' ||
                ' WHERE fd.route_no = ''' || i_route_no || '''' ||
                '   AND fd.prod_id = v.prod_id ' ||
                '   AND fd.cust_pref_vendor = v.cust_pref_vendor ' ||
                '   AND v.curr_mx_cases < fd.qty_order / v.spc' ||
                '   AND v.curr_mx_cases > 0';
                
        /* Where clause for Non-Demand (NSP) replenishment*/
        MX_SUB_NSP  VARCHAR2 (512) :=
                '  FROM v_matrix_splithome_info v ' ||
                ' WHERE CEIL(v.split_home_qoh_qty_planned /v.spc) < v.case_qty_for_split_rpl                                  
                    AND NVL (v.curr_mx_cases, 0) > 0
                    AND v.area = NVL (''' || i_area || ''', v.area)                    
                    AND v.prod_id = NVL (''' || i_prod_id || ''', v.prod_id)
                    AND v.cust_pref_vendor = NVL (''' || i_cust_pref_vendor || ''', v.cust_pref_vendor)';
                    
        MX_SUB_SHP  VARCHAR2 (512) :=
                ' FROM v_matrix_splithome_info v 
                  WHERE v.prod_id = ''' || i_prod_id || '''
                    AND v.cust_pref_vendor = ''' || i_cust_pref_vendor || '''
                    AND v.curr_mx_cases < ' || i_qty_reqd || '
                    AND v.curr_mx_cases > 0';
/*
        CURSOR  c_route_mx_prod (p_routeNo VARCHAR2) IS
        SELECT  fd.prod_id, fd.cust_pref_vendor
          FROM  pm p, float_detail fd
         WHERE  fd.route_no = p_routeNo
           AND  p.prod_id = fd.prod_id
           AND  p.cust_pref_vendor = fd.cust_pref_vendor
           AND  p.miniload_storage_ind = 'B';*/

        l_pri_cd        VARCHAR2 (3);
        l_priority      INTEGER;
        rpl_qty         NUMBER;        
        l_qty           NUMBER := 0;
        acquired_qty    NUMBER := 0;
        deleted_qty     NUMBER := 0;
    BEGIN

    o_status := C_SUCCESS;

         --
         -- Log a message if the replenishment is for the 
         -- Matrix not having enough qty for an order.
         --
         /*IF (i_call_type = 'SHP') THEN
            pl_log.ins_msg('INFO', l_fname,
                'i_call_type[' || i_call_type || ']'
                || '  Create case replenishment from main'
                || ' warehouse to the miniloader for item ['
                || i_prod_id || ']'
                || ' CPV[' || i_cust_pref_vendor || ']'
                || ' for ' ||  TO_CHAR(i_qty_reqd)
                || ' cases.',
                NULL, NULL, ct_app_func, gl_pkg_name);
         END IF;*/
    
        -- Generate NDM repl from Split Home (NSP) from Matrix to Split home.        
        IF (i_call_type NOT IN ('NSP', 'DSP')) THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Invalid Call Type. ' || i_call_type;
            RAISE e_fail;
        END IF; 
        DBMS_OUTPUT.PUT_LINE ('good call type ' || i_call_type);
    
        pl_text_Log.ins_msg('I', C_PROGRAM_CODE,
            'Generate Split Repl for call type = ' || i_call_type, NULL, NULL);
        
        /*Generate the cursor SQL based on replenishment type*/
        SELECT  MX_MAIN_SQL ||
                DECODE (i_call_type,
                        'DSP', MX_MAIN_SQL3,
                               MX_MAIN_SQL2) ||
                DECODE (i_call_type,                
                        'NSP', MX_SUB_NSP,
                        'DSP', MX_SUB_DSP),
                DECODE (i_call_type,
                        'NSP', NDM_PRI_CD,
                        'DSP', DMD_PRI_CD)
          INTO  l_sql_stmt, l_pri_cd
          FROM  DUAL;
         
        /*Find the priority based on replenishment type*/
        BEGIN
            SELECT  priority
              INTO  l_priority
              FROM  matrix_task_priority
             WHERE matrix_task_type = i_call_type
               AND severity = 'NORMAL';
               
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_priority := 99;
        END;
            
        /*IF (i_call_type = 'DMD')
        THEN
            FOR r_rmp IN c_route_mx_prod (i_route_no)
            LOOP
                Acquire_MX_NDM_Replen (
                    r_rmp.prod_id,
                    r_rmp.cust_pref_vendor,
                    acquired_qty);
                DeleteNDMRepl (
                    r_rmp.prod_id,
                    r_rmp.cust_pref_vendor,
                    deleted_qty);
            END LOOP;
        END IF;*/

        ----------------For Debugging 
        DBMS_OUTPUT.PUT_LINE ('sql is ');

        i := 1;
        LOOP
            DBMS_OUTPUT.PUT_LINE (LTRIM (SUBSTR (l_sql_stmt, i, 50)));
            IF ((i + 50) < LENGTH (l_sql_stmt)) THEN
                i := i + 50;
            ELSE
                EXIT;
            END IF;
        END LOOP;
        --------------------------
        
        Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
            'SQL IS ' || l_sql_stmt, NULL, NULL);

        OPEN c_RPL FOR l_sql_stmt;
        LOOP
            FETCH c_RPL INTO r_splhome_rpl;
            IF (c_RPL%NOTFOUND)
            THEN
                EXIT;
            END IF;

            rpl_qty := (r_splhome_rpl.case_qty_for_split_rpl - CEIL(r_splhome_rpl.split_home_qoh_qty_planned/r_splhome_rpl.spc)) * r_splhome_rpl.spc - NVL(r_splhome_rpl.curr_repl_cases, 0)  ; 
            
            /*IF (i_call_type = 'DMD')
            THEN
                rpl_qty := rpl_qty - l_qty;
            END IF;*/

            Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                'Create Split Home (NSP) Replen For Item ' || r_splhome_rpl.prod_id ||
                ', Qty = ' || rpl_qty, NULL, NULL);

            IF (rpl_qty > 0) THEN
                /*Create replenishment task and update the inventory */
                BEGIN

                    Gen_SplitHome_Case_Replen
                                      (i_rb_no                     => i_route_batch_no,
                                       i_route_no                  => i_route_no,
                                       i_prod_id                   => r_splhome_rpl.prod_id,
                                       i_cpv                       => r_splhome_rpl.cpv,
                                       i_rpl_qty                   => rpl_qty,
                                       i_priority                  => l_priority,
                                       i_call_type                 => i_call_type,
                                       i_spc                       => r_splhome_rpl.spc,
                                       i_batch_no                  => i_batch_no,
                                       i_order_id                  => NULL,
                                       i_order_line_id             => NULL,
                                       i_stop_no                   => NULL,
                                       o_qty_replenished_in_splits => l_qty_replenished_in_splits);

                EXCEPTION
                    WHEN OTHERS THEN
                        IF i_prod_id IS NULL THEN
                            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,'Gen_SplitHome_Case_Replen failed for prod_id '||r_splhome_rpl.prod_id,SQLCODE,SQLERRM);
                        ELSE
                            RAISE;
                        END IF; 
                END;    
            END IF;
        END LOOP;
        
        CLOSE c_RPL; 
    
        EXCEPTION
        WHEN e_fail 
        THEN
            Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE;
        WHEN OTHERS
        THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_split_home_rpl.';
            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_msg_text,SQLCODE,SQLERRM);
            o_status := C_FAILURE;
    END create_split_home_rpl;
    
    
----------------------------------------------------------------------------------
-- Procedure: (Public)
--     create_assign_matrix_rpl
--
-- Description:
--     This procedure create replenishment tasks for assign to Matrix (MXL)from home slot. 
--     Called when user generates replenishment task from form XXXXX for matrix items.  
--
-- Parameters:
--   Input:
--    i_prod_id                 Product ID
--    i_cust_pref_vendor        Cust Prefered Vendor
--    i_case_home_loc           Case Home location
--
--   Output:
--    o_status - return value
--          0  - Successful
--          1  - Error
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/24/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------

    PROCEDURE  create_assign_matrix_rpl(        
        i_prod_id           IN  VARCHAR2,
        i_cust_pref_vendor  IN  VARCHAR2 DEFAULT NULL,
        i_split_home_loc    IN  VARCHAR2,               
        o_status            OUT NUMBER)
    IS
        l_fname                  VARCHAR2 (50)       := 'create_assign_matrix_rpl';
        l_msg_text               VARCHAR2 (512);
        l_sql_stmt               VARCHAR2 (2048);
        i                        NUMBER (6);
        e_fail                   EXCEPTION;        
        
        /*Cursor for reserve inventory available to allocate*/
        CURSOR  c_inv IS
        SELECT  l.pik_path, i.logi_loc, i.plogi_loc, i.qoh, i.exp_date,
                i.parent_pallet_id, i.rec_id, i.lot_id, i.mfg_date, i.rec_date,
                i.qty_planned, i.inv_date, i.min_qty, i.abc, p.spc, i.inv_uom,
                l.slot_type, i.cust_pref_vendor
          FROM  pm p, zone z, lzone lz, loc l, inv i
         WHERE  i.prod_id = i_prod_id
           AND  i.cust_pref_vendor = NVL(i_cust_pref_vendor, i.cust_pref_vendor)
           AND  p.prod_id = i.prod_id
           AND  p.cust_pref_vendor = i.cust_pref_vendor
           --AND  i.plogi_loc = i_case_home_loc
           AND  i.logi_loc = i.plogi_loc
           --AND  i.logi_loc = i_pallet_id
           AND  i.status = 'AVL'
           AND  i.inv_uom IN (0, 2)
           --AND  qoh > 0
           AND  NVL (qty_alloc, 0) = 0
           AND  l.logi_loc = i.plogi_loc   
           AND  i.plogi_loc = i.logi_loc           
           AND  lz.logi_loc = l.logi_loc
           AND  z.zone_id = lz.zone_id
           AND  z.zone_type = 'PUT'
           AND  z.induction_loc IS NULL
           AND  z.rule_id IN (0, 1, 2)
           AND  p.mx_item_assign_flag = 'Y'
           FOR  UPDATE OF i.qty_alloc NOWAIT;  
           
        l_process_cnt   NUMBER := 0;
        l_result        NUMBER;        
        l_priority      INTEGER;
        rpl_qty         NUMBER;        
        l_qty           NUMBER := 0;
        acquired_qty    NUMBER := 0;
        deleted_qty     NUMBER := 0;
        l_config_ind_loc replenlst.dest_loc%TYPE;
        l_case_qty      NUMBER;
        l_split_qty     NUMBER;
        l_repl_qty      NUMBER;     
        l_pallet_id     NUMBER;
        l_ti_hi_qty     NUMBER;
        l_batch_no      NUMBER;
        l_count_commit  NUMBER;      
        l_deep_ind      slot_type.deep_ind%TYPE;
        g_tabTask       pl_swms_execute_sql.tabTask;
        l_cnt           NUMBER := 0;
        l_symb_loc      loc.logi_loc%TYPE;
    BEGIN
        o_status := C_SUCCESS;
 
        /*Find the priority based on replenishment type*/
        BEGIN
            SELECT  priority
              INTO  l_priority
              FROM  matrix_task_priority
             WHERE matrix_task_type = 'MXL'
               AND severity = 'NORMAL';
               
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_priority := 99;
        END;       
        
        l_config_ind_loc := pl_matrix_common.f_get_mx_dest_loc(i_prod_id);    
        
        IF  TRIM(l_config_ind_loc) IS NULL THEN     
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Unable to get SYS_CONFIG matrix destination location for prod_id '||i_prod_id;
            
            RAISE e_fail;   
        END IF;
        
        
        BEGIN
            SELECT ti * hi * spc
              INTO l_ti_hi_qty
              FROM pm
             WHERE prod_id = i_prod_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_msg_text := 'Prog Code: ' || l_fname
                || ' Not able to find ti, hi for Prod ID ' || i_prod_id;
                RAISE e_fail;
        END;
        
        l_batch_no := repl_cond_seq.NEXTVAL;
        
        --For each home location
        FOR r_inv in c_inv 
        LOOP
            l_cnt := l_cnt + 1;
            IF r_inv.qoh > 0 THEN
                l_process_cnt := l_process_cnt + 1;
                
                l_case_qty := FLOOR(r_inv.qoh / r_inv.spc) * r_inv.spc;
                l_split_qty := r_inv.qoh - l_case_qty;
                
                BEGIN
                    SELECT deep_ind
                      INTO l_deep_ind
                      FROM slot_type 
                     WHERE slot_type = r_inv.slot_type;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_deep_ind := 'N';
                END;
                
                --Create multiple inventory based on ti, hi and create replenishment task for the same
                WHILE (l_case_qty > 0)
                LOOP
                    IF l_deep_ind = 'Y' THEN
                        IF l_case_qty <= l_ti_hi_qty THEN
                            l_repl_qty := l_case_qty;
                            l_case_qty := 0;
                        ELSE
                            l_repl_qty := l_ti_hi_qty;
                            l_case_qty := l_case_qty - l_repl_qty;               
                        END IF;
                    ELSE
                        l_repl_qty := l_case_qty;
                        l_case_qty := 0;
                    END IF;
                    
                    
                    Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                        'Create Assign to Matrix(MXL) Replen For Item ' || i_prod_id ||
                        ', Qty = ' || rpl_qty, NULL, NULL);     

                     l_pallet_id := pallet_id_seq.NEXTVAL;   
                     
                     Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,' TEST 1 New Pallet_id '||l_pallet_id  || '  r_inv.plogi_loc :'||r_inv.plogi_loc,NULL,NULL);
                        
                     
                     INSERT INTO inv (PROD_ID, REC_ID, MFG_DATE, REC_DATE, EXP_DATE, INV_DATE, LOGI_LOC, PLOGI_LOC, 
                                      QOH, QTY_ALLOC, QTY_PLANNED, MIN_QTY, CUBE, LST_CYCLE_DATE, LST_CYCLE_REASON, 
                                      ABC, ABC_GEN_DATE, STATUS, LOT_ID, WEIGHT, TEMPERATURE, EXP_IND, CUST_PREF_VENDOR,
                                      CASE_TYPE_TMU, PALLET_HEIGHT, ADD_DATE, ADD_USER, UPD_DATE, UPD_USER, PARENT_PALLET_ID,
                                      DMG_IND,INV_UOM) 
                               SELECT PROD_ID, REC_ID, MFG_DATE, REC_DATE, EXP_DATE, INV_DATE, l_pallet_id, PLOGI_LOC, 
                                      l_repl_qty, l_repl_qty, 0, MIN_QTY, CUBE, LST_CYCLE_DATE, LST_CYCLE_REASON, 
                                      ABC, ABC_GEN_DATE, STATUS, LOT_ID, WEIGHT, TEMPERATURE, EXP_IND, CUST_PREF_VENDOR,
                                      CASE_TYPE_TMU, PALLET_HEIGHT, ADD_DATE, ADD_USER, UPD_DATE, UPD_USER, PARENT_PALLET_ID,
                                      DMG_IND,INV_UOM
                                 FROM inv
                                WHERE logi_loc = r_inv.plogi_loc; 
                    
                    Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,' TEST 2 New Pallet_id '||l_pallet_id,NULL,NULL);
                    /*Create replenishment task and update the inventory */ 
                    INSERT  INTO replenlst (
                            task_id, prod_id, cust_pref_vendor, uom, qty, type, 
                            status, src_loc, pallet_id, 
                            dest_loc, gen_uid, gen_date, exp_date, route_no, route_batch_no, priority, 
                            parent_pallet_id, rec_id, lot_id, mfg_date, s_pikpath, 
                            orig_pallet_id, case_no, print_lpn, batch_no, mx_batch_no)
                    VALUES (repl_id_seq.NEXTVAL, i_prod_id, r_inv.cust_pref_vendor, 2, l_repl_qty, 'MXL',
                            'PRE', r_inv.plogi_loc, l_pallet_id , 
                            l_config_ind_loc, REPLACE (USER, 'OPS$'), SYSDATE, r_inv.exp_date, NULL, NULL, l_priority,
                            r_inv.parent_pallet_id, r_inv.rec_id, r_inv.lot_id, r_inv.mfg_date, r_inv.pik_path,
                            DECODE (r_inv.plogi_loc, r_inv.logi_loc, NULL, DECODE (r_inv.slot_type, 'MXS', NULL, r_inv.logi_loc)),
                            ordd_seq.NEXTVAL, pl_matrix_common.print_lpn_flag('MXL'), l_batch_no, mx_batch_no_seq.NEXTVAL);   
                            
                            Pl_Text_Log.ins_msg('I',C_PROGRAM_CODE,' TEST 3 New Pallet_id '||l_pallet_id ||   'qty  :'||l_repl_qty,NULL,NULL);
                    UPDATE  inv             
                       SET  qoh = qoh - l_repl_qty
                     WHERE  CURRENT OF c_inv;               
                            
                END LOOP;
                
                Pl_Text_Log.ins_msg('I',C_PROGRAM_CODE,' Creating TRANS UAS for assignment to symbotic for location :'||r_inv.plogi_loc ,NULL,NULL);
                
                /* Un-Assign in Trans table for home location */
                INSERT INTO trans (trans_id, trans_type, trans_date, Prod_id,
                                   user_id,dest_loc, pallet_id, upload_time, cust_pref_vendor)
                            SELECT trans_id_seq.NEXTVAL, 'UAS', SYSDATE, i_prod_id,
                                   USER, r_inv.plogi_loc, r_inv.plogi_loc, SYSDATE, r_inv.cust_pref_vendor
                              FROM dual;
          
            Pl_Text_Log.ins_msg('I',C_PROGRAM_CODE,' Creating TRANS IAS for assignment to symbotic for location :'||l_symb_loc ||'    l_cnt: '|| l_cnt ,NULL,NULL);
                IF l_cnt = 1 THEN
                    BEGIN
                        SELECT loc.logi_loc
                          INTO l_symb_loc
                          FROM loc,
                               mx_food_type mx,
                               pm
                         WHERE mx.mx_food_type   = pm.mx_food_type
                           AND loc.slot_type     = mx.slot_type
                           AND pm.prod_id        = i_prod_id;
                      EXCEPTION
                        WHEN OTHERS THEN
                            l_symb_loc := 'LX01D1';
                    END;
                    
                    /* Assign into Trans table for Symbotic Location */
                    INSERT INTO trans (trans_id, trans_type, trans_date, Prod_id,
                                       user_id,dest_loc, pallet_id, upload_time,cust_pref_vendor)
                               SELECT trans_id_seq.NEXTVAL, 'IAS', SYSDATE, i_prod_id,
                                      USER, l_symb_loc, l_symb_loc, SYSDATE, r_inv.cust_pref_vendor
                                FROM dual;
                END IF;
                        
                IF l_split_qty > 0 AND i_split_home_loc IS NOT NULL THEN
                    Pl_Text_Log.ins_msg('I',C_PROGRAM_CODE,' Creating TRANS IAS for assignment to symbotic for split home location :'||i_split_home_loc ||'    l_cnt: '|| l_cnt ,NULL,NULL);
                    
                    /* Assign into Trans table for split home Location */
                    INSERT INTO trans (trans_id, trans_type, trans_date, Prod_id,
                                       user_id,dest_loc, pallet_id, upload_time,cust_pref_vendor)
                               SELECT trans_id_seq.NEXTVAL, 'IAS', SYSDATE, i_prod_id,
                                      USER, i_split_home_loc, i_split_home_loc, SYSDATE, r_inv.cust_pref_vendor
                                FROM dual;
                                
                    create_split_transfer_rpl(i_prod_id, i_cust_pref_vendor, r_inv.plogi_loc, i_split_home_loc, l_split_qty , l_batch_no, o_status);
                ELSE
                    IF l_split_qty  = 0 THEN
                        DELETE inv 
                         WHERE prod_id = i_prod_id 
                           AND logi_loc = r_inv.plogi_loc;
                    END IF;
                END IF;
            END IF; 
            
            --Delete home location inventory if qoh =0
            IF r_inv.qoh = 0 THEN
                DELETE inv 
                 WHERE prod_id = i_prod_id 
                   AND logi_loc = r_inv.plogi_loc;
            END IF;
            
            --Unslotted case home location
            UPDATE loc
               SET prod_id = NULL,
                   cust_pref_vendor = NULL,
                   rank = NULL,
                   uom = NULL
             WHERE logi_loc = r_inv.plogi_loc;
             
            
      
        END LOOP;
        
        IF o_status = 0 THEN
            create_matrix_ndm_case_rpl (i_call_type => 'NXL', 
                                        i_prod_id => i_prod_id, 
                                        i_cust_pref_vendor => i_cust_pref_vendor, 
                                        i_batch_no=> l_batch_no, 
                                        o_status => o_status);
        END IF; 
        
        --Commit task from PRE to NEW
        IF  o_status = 0 THEN
            FOR cur IN ( SELECT task_id FROM replenlst WHERE batch_no = l_batch_no AND status = 'PRE')
            LOOP
                g_tabTask(cur.task_id) := cur.task_id;
            END LOOP;
            
            pl_swms_execute_sql.commit_ndm_repl (g_tabTask, g_tabTask.count, l_count_commit);
            
            IF (l_count_commit != g_tabTask.count) THEN
                l_msg_text := 'Prog Code: ' || l_fname
                || ' Not all the assignment tasks were committed for prod_id ' || i_prod_id;
                RAISE e_fail;
            END IF;
        END IF;
        
/*        IF l_process_cnt = 0 THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Not able to find requested pallet for replenishment.';
            RAISE e_fail;      
        END IF;     
 */   
    EXCEPTION    
        WHEN e_fail
        THEN
            Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE;  
        WHEN OTHERS
        THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_assign_matrix_rpl.';
            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_msg_text,SQLCODE,SQLERRM);
            o_status := C_FAILURE;
    END create_assign_matrix_rpl;   



----------------------------------------------------------------------------------
-- Procedure: (Public)
--     create_unassign_matrix_rpl
--
-- Description:
--     This procedure create replenishment tasks for Unassign from Matrix to home location (UNA). 
--     Called when user generates replenishment task from form XXXXX for matrix items.  
--
-- Parameters:
--   Input:
--    i_prod_id                 Product ID
--    i_cust_pref_vendor        Cust Prefered Vendor
--    i_case_home_loc           Case Home location
--
--   Output:
--    o_status - return value
--          0  - Successful
--          1  - Error
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/28/14 ayad5195 Initial Creation
--    08/12/15 ayad5195 Comment out 3 validations.  See the comments 
--                      in the code below dated 08/12/15.
--
----------------------------------------------------------------------------------
    PROCEDURE  create_unassign_matrix_rpl(        
        i_prod_id           IN  VARCHAR2,
        i_cust_pref_vendor  IN  VARCHAR2 DEFAULT NULL,
        i_case_home_loc     IN  VARCHAR2,      
        o_status            OUT NUMBER)
    IS
        l_fname             VARCHAR2 (50)       := 'create_unassign_matrix_rpl';
        l_msg_text          VARCHAR2 (512);
        l_sql_stmt          VARCHAR2 (2048);
        i                   NUMBER (6);
        e_fail              EXCEPTION;
        l_dest_loc          replenlst.dest_loc%TYPE;
        l_process_cnt       NUMBER := 0;
        l_result            NUMBER;        
        l_priority          INTEGER;
        rpl_qty             NUMBER;        
        l_qty               NUMBER := 0;        
        l_num_of_locations  NUMBER;
        l_suggest_loc       pl_putaway_utilities.t_phys_loc;
        l_pallet_qty        NUMBER;
        l_def_spur_loc      replenlst.src_loc%TYPE;
        l_def_unassign_loc  replenlst.src_loc%TYPE;
        l_batch_no          NUMBER;
        l_count_commit      NUMBER;      
        l_ret_val           NUMBER;
        l_sys_msg_id        NUMBER;
        l_mo_case_qty       NUMBER; 
        l_sequence_number   NUMBER;
        l_case_barcode      VARCHAR2(20);
        l_print_stream      CLOB;
        g_tabTask           pl_swms_execute_sql.tabTask;
        l_exact_pallet_imp  VARCHAr2(4);
        
        /*Cursor for Matrix inventory available to allocate*/
        CURSOR  c_inv IS
        SELECT  l.pik_path, i.logi_loc, plogi_loc, qoh, exp_date,
                i.parent_pallet_id, i.rec_id, i.lot_id, i.mfg_date, i.rec_date,
                i.qty_planned, i.inv_date, i.min_qty, i.abc, p.spc, i.inv_uom,
                l.slot_type, z.induction_loc, i.cust_pref_vendor
          FROM  pm p, zone z, lzone lz, loc l, inv i
         WHERE  i.prod_id = i_prod_id
           AND  i.cust_pref_vendor = NVL(i_cust_pref_vendor, i.cust_pref_vendor)
           AND  p.prod_id = i.prod_id
           AND  p.cust_pref_vendor = i.cust_pref_vendor         
          --AND  i.status = 'AVL'
           AND  i.inv_uom IN (0, 2)
           AND  i.qoh > 0
           AND  NVL (i.qty_alloc, 0) = 0
           AND  NVL (i.qty_planned, 0) = 0
           AND  l.logi_loc = i.plogi_loc           
           AND  lz.logi_loc = l.logi_loc
           AND  z.zone_id = lz.zone_id
           AND  z.zone_type = 'PUT'
           AND  l.slot_type IN ('MXF', 'MXC')
           AND  z.rule_id = 5
           AND  p.mx_item_assign_flag = 'Y'   
        ORDER BY i.qoh, i.exp_date, i.qoh, i.logi_loc         
           FOR  UPDATE OF i.qty_alloc NOWAIT;             

    BEGIN

        o_status := C_SUCCESS;
        
        IF i_case_home_loc IS NULL THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Case home location to un-assign an item can not be null ';
            RAISE e_fail;           
        END IF;
        



        /****************
        **
        ** 8/12/2015  Abhishek Yadav
        ** Comment out the following three validations.  These are done in
        ** the unassign form and not needed here.
        **
        IF is_putawaylst_exists(i_prod_id) = TRUE THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Record exists in putawaylst for Prod ID ' || i_prod_id;
            RAISE e_fail;           
        END IF;
        
        IF is_replenlst_exists(i_prod_id) = TRUE THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Record exists in replenlst for Prod ID ' || i_prod_id;
            RAISE e_fail;           
        END IF;
        
        IF is_float_detail_exists(i_prod_id) = TRUE THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Record exists in float_detail for Prod ID ' || i_prod_id;
            RAISE e_fail;           
        END IF;     
        ****************/

  
        /*Find the priority based on replenishment type*/
        BEGIN
            SELECT  priority
              INTO  l_priority
              FROM  matrix_task_priority
             WHERE matrix_task_type = 'UNA'
               AND severity = 'NORMAL';
               
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_priority := 99;
        END;
        
        pl_text_Log.ins_msg('I', C_PROGRAM_CODE, 'After Select Priority', NULL, NULL);        
        
        l_def_spur_loc := pl_matrix_common.get_sys_config_val('MX_DEFAULT_SPUR_LOCATION');
        /*BEGIN
            SELECT config_flag_val
              INTO l_def_spur_loc
              FROM sys_config
             WHERE config_flag_name = 'MX_DEFAULT_SPUR_LOCATION';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_def_spur_loc := 'SP9999';
        END;*/
        IF l_def_spur_loc IS NULL THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Sys Config value is not exists for default spur location flag MX_DEFAULT_SPUR_LOCATION ';
            RAISE e_fail; 
        END IF;
        
        BEGIN
            SELECT logi_loc  
              INTO l_def_unassign_loc
              FROM loc
             WHERE slot_type = 'MXO'
               AND rownum = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_msg_text := 'Prog Code: ' || l_fname
                || ' Default unassign location not found in loc for slot_type MXO';
            RAISE e_fail; 
        END;
        --Get the total number of inventory to location get the reserv
        l_num_of_locations := 0;        
        FOR r_inv in c_inv 
        LOOP
            l_num_of_locations := l_num_of_locations + 1;
        END LOOP;
        
        pl_text_Log.ins_msg('I', C_PROGRAM_CODE, 'Total number of inventory to unassign :'|| l_num_of_locations, NULL, NULL);
        
        l_batch_no := repl_cond_seq.NEXTVAL;
        
        
        FOR r_inv in c_inv 
        LOOP
            l_process_cnt := l_process_cnt + 1;
            
            --If more than one inventory get the reserve location in table type l_suggest_loc
            /*IF l_process_cnt = 2 OR i_case_home_loc is NULL THEN  
                --Get the maximum quantity of a pallet for prod_id
                SELECT ti * hi * spc 
                  INTO l_pallet_qty
                  FROM pm
                 WHERE prod_id = i_prod_id;               
                 
                --Get the suggested reserve location for Unassign 
                pl_putaway_utilities.p_find_xfr_slots(NULL, i_case_home_loc, NVL(l_pallet_qty, r_inv.qoh), l_num_of_locations,
                                                      l_suggest_loc, l_result);
            END IF;*/
            
            --For 1st Inventory use input home location as destination and thereafter use reserve locations 
            --If reserve location not found then use then use default reserve location
            --IF l_process_cnt = 1 AND i_case_home_loc IS NOT NULL THEN
            
            --All pallets should go to home location
            l_dest_loc := i_case_home_loc;
            
            IF l_process_cnt = 1 THEN
                /* Assign in Trans table for home location*/
                INSERT INTO trans (trans_id, trans_type, trans_date, Prod_id,
                                   user_id,dest_loc, pallet_id, upload_time, cust_pref_vendor)
                            SELECT trans_id_seq.NEXTVAL, 'IAS', SYSDATE, i_prod_id,
                                   USER, i_case_home_loc, i_case_home_loc, SYSDATE, r_inv.cust_pref_vendor
                              FROM dual;
          
                /* Un-assign into Trans table for Symbotic Location */
                INSERT INTO trans (trans_id, trans_type, trans_date, Prod_id,
                                   user_id,dest_loc, pallet_id, upload_time,cust_pref_vendor)
                           SELECT trans_id_seq.NEXTVAL, 'UAS', SYSDATE, i_prod_id,
                                  USER, r_inv.plogi_loc, r_inv.plogi_loc, SYSDATE, r_inv.cust_pref_vendor
                            FROM dual;
            END IF;
            
            /*ELSE      
                IF l_num_of_locations <= 0 AND l_result != 0 THEN
                    l_dest_loc := l_def_unassign_loc;
                  
                ELSE
                    IF l_suggest_loc.EXISTS(l_process_cnt - 1) THEN
                        l_dest_loc := l_suggest_loc(l_process_cnt - 1);
                    ELSE
                        l_dest_loc := l_def_unassign_loc;                       
                    END IF;
                END IF; 
            END IF;    */        
         
            Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                                 'Create Unassign to Matrix(UNA) Replen For Item ' || i_prod_id ||
                                 ', Qty = ' || r_inv.qoh, NULL, NULL);      
                        
            /*Create replenishment task and update the inventory */ 
            INSERT  INTO replenlst (
                    task_id, prod_id, cust_pref_vendor, uom, qty, type, 
                    status, src_loc, pallet_id, 
                    dest_loc, gen_uid, gen_date, exp_date, route_no, route_batch_no, priority, 
                    parent_pallet_id, rec_id, lot_id, mfg_date, s_pikpath, 
                    orig_pallet_id, case_no, print_lpn, batch_no, mx_batch_no)
            VALUES (repl_id_seq.NEXTVAL, i_prod_id, r_inv.cust_pref_vendor, 2, r_inv.qoh, 'UNA',
                    'PRE', l_def_spur_loc, r_inv.logi_loc , 
                    l_dest_loc, REPLACE (USER, 'OPS$'), SYSDATE, r_inv.exp_date, NULL, NULL, l_priority,
                    r_inv.parent_pallet_id, r_inv.rec_id, r_inv.lot_id, r_inv.mfg_date, r_inv.pik_path,
                    DECODE (r_inv.plogi_loc, r_inv.logi_loc, NULL, DECODE (r_inv.slot_type, 'MXS', NULL, r_inv.logi_loc)),
                    ordd_seq.NEXTVAL, pl_matrix_common.print_lpn_flag('UNA'), l_batch_no, mx_batch_no_seq.NEXTVAL);   
                        
            UPDATE  inv
               SET  qty_alloc = r_inv.qoh
             WHERE  CURRENT OF c_inv;       
            
            --IF l_process_cnt = 1 THEN
                UPDATE  inv
                   SET  qty_planned = NVL(qty_planned, 0) + r_inv.qoh
                 WHERE  logi_loc =  i_case_home_loc;                    
            --END IF; 
        END LOOP;
        
        IF l_process_cnt = 0 THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Inventory is not available in Matrix to Unassign for prod_id '|| i_prod_id;
            --RAISE e_fail;      
        END IF;     
        
        --Commit task from PRE to NEW
        IF  l_process_cnt > 0 THEN
            FOR rec IN ( SELECT task_id FROM replenlst WHERE batch_no = l_batch_no AND status = 'PRE')
            LOOP
                g_tabTask(rec.task_id) := rec.task_id;
            END LOOP;
            
            pl_swms_execute_sql.commit_ndm_repl (g_tabTask, g_tabTask.count, l_count_commit);
            
            IF (l_count_commit != g_tabTask.count) THEN
                l_msg_text := 'Prog Code: ' || l_fname
                || ' Not all the Unassign tasks were committed for prod_id ' || i_prod_id;
                RAISE e_fail;
            END IF;
            
            UPDATE replenlst
               SET status = 'PND'
             WHERE batch_no = l_batch_no;               
            
            BEGIN
                SELECT mx_exact_pallet_imp
                  INTO l_exact_pallet_imp
                  FROM mx_replen_type
                 WHERE type = 'UNA'
                   AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS THEN
                    Pl_Text_Log.ins_msg ('FATAL', l_fname, 'Not able to find mx_exact_pallet_imp from table mx_replen_type for type UNA ', SQLCODE, SQLERRM);
                    l_exact_pallet_imp := 'LOW';
            END;
            
            FOR rec IN ( SELECT r.type, p.spc, r.qty, r.task_id, r.prod_id, r.pallet_id, r.exp_date, r.rec_id, 
                                r.mx_batch_no, r.dest_loc, r.case_no, p.descrip, p.pack, p.prod_size, p.brand
                           FROM pm p, replenlst r             
                          WHERE p.prod_id = r.prod_id 
                            AND r.batch_no = l_batch_no )
            LOOP
                IF rec.type = 'UNA' THEN
                  l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;
                  l_mo_case_qty := TRUNC(rec.qty/rec.spc);
                  
                  l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                    i_interface_ref_doc => 'SYS05',
                                                                    i_label_type => 'LPN',   --LPN
                                                                    i_parent_pallet_id => NULL,
                                                                    i_rec_ind => 'S',    ---H OR D  
                                                                    i_pallet_id => rec.pallet_id,
                                                                    i_prod_id => rec.prod_id,
                                                                    i_case_qty => l_mo_case_qty,
                                                                    i_exp_date => rec.exp_date,
                                                                    i_erm_id => rec.rec_id,
                                                                    i_batch_id => rec.mx_batch_no,
                                                                    i_trans_type => 'UNA',
                                                                    i_task_id => rec.task_id,
                                                                    i_dest_loc => rec.dest_loc,
                                                                    i_exact_pallet_imp => l_exact_pallet_imp,
                                                                    i_order_gen_time => TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'),
                                                                    i_priority => 2   
                                                                   ); 
                  IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname
                                    || ' Unable to insert record (UNA)into matrix_out table for pallet_id ' || rec.pallet_id;
                    RAISE e_fail;
                  END IF;
                  
                  --Get the sequence number for last inserted record
                  BEGIN
                      SELECT sequence_number 
                        INTO  l_sequence_number
                        FROM (  SELECT sequence_number
                                            FROM matrix_out 
                                           WHERE pallet_id = rec.pallet_id
                                             AND interface_ref_doc = 'SYS05'
                                             AND trans_type = 'UNA'
                                           ORDER BY sequence_number DESC)
                                 WHERE rownum = 1;
                  EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        l_msg_text := 'Prog Code: ' || l_fname
                                    || ' Failed to get the sequence number from matrix_out for pallet_id ' || rec.pallet_id;                        
                        RAISE e_fail;
                  END;
            
                  --Populate case number and Label in table matrix_out_label 
                  BEGIN
                      FOR i IN 1..l_mo_case_qty
                      LOOP
                        l_case_barcode := TRIM(rec.case_no) || LPAD(i, 3, '0');
                        
                        l_ret_val := pl_matrix_common.insert_repl_sys05_label(i_caseBarCode      => l_case_barcode,
                                                                              i_destLoc          => rec.dest_loc,
                                                                              i_pallet_id        => rec.pallet_id,
                                                                              i_prod_id          => rec.prod_id,
                                                                              i_descrip          => rec.descrip,
                                                                              i_pack             => rec.pack,
                                                                              i_prod_size        => rec.prod_size,
                                                                              i_brand            => rec.brand,
                                                                              i_type             => 'UNA',
                                                                              i_sequence_number  => l_sequence_number);
                    
                        IF l_ret_val = C_FAILURE THEN
                            l_msg_text := 'Prog Code: ' || l_fname
                                    || ' Failed to insert in matrix_out_label for sequence number ' || l_sequence_number ||' and barcode '||l_case_barcode;  
                            RAISE e_fail;
                        END IF;                             
                      END LOOP;                  
                  END;
          
                  COMMIT;
                  
                  l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);
                  
                  IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname
                                    || ' Unable to send the message SYS05 for replenishment type (UNA) for sys_msg_id ' || l_sys_msg_id;
                    RAISE e_fail;
                  END IF;
                                    
                END IF;  
            END LOOP; 
        END IF;     
    EXCEPTION    
        WHEN e_fail
        THEN
            Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE;  
        WHEN OTHERS
        THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_unassign_matrix_rpl.';
            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_msg_text,SQLCODE,SQLERRM);
            o_status := C_FAILURE;
    END create_unassign_matrix_rpl;  
 

----------------------------------------------------------------------------------
-- Function: (Public)
--     is_putawaylst_exists
--
-- Description:
--     This function return TRUE or FALSE base on record present in table putawaylst for the input prod_id
--
-- Parameters:
--   Input:
--    i_prod_id                 Product ID
--
--   Return:
--    TRUE/FALSE (Boolean)
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/28/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------

    FUNCTION  is_putawaylst_exists(i_prod_id IN  VARCHAR2) RETURN BOOLEAN
    IS
        l_cnt     NUMBER;
       
    BEGIN
        SELECT COUNT(*)
          INTO l_cnt 
          FROM putawaylst
         WHERE prod_id = i_prod_id;
         
        IF l_cnt > 0 THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END is_putawaylst_exists;
 
 ----------------------------------------------------------------------------------
-- Function: (Public)
--     is_replenlst_exists
--
-- Description:
--     This function return TRUE or FALSE base on record present in table replenlst for the input prod_id
--
-- Parameters:
--   Input:
--    i_prod_id                 Product ID
--
--   Return:
--    TRUE/FALSE (Boolean)
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/28/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------

    FUNCTION  is_replenlst_exists(i_prod_id IN  VARCHAR2) RETURN BOOLEAN
    IS
        l_cnt     NUMBER;
       
    BEGIN
        SELECT COUNT(*)
          INTO l_cnt 
          FROM replenlst
         WHERE prod_id = i_prod_id;
         
        IF l_cnt > 0 THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END is_replenlst_exists;
 
  ----------------------------------------------------------------------------------
-- Function: (Public)
--     is_float_detail_exists
--
-- Description:
--     This function return TRUE or FALSE base on record present in table float_detail for the input prod_id
--
-- Parameters:
--   Input:
--    i_prod_id                 Product ID
--
--   Return:
--    TRUE/FALSE (Boolean)
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/28/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------

    FUNCTION  is_float_detail_exists(i_prod_id IN  VARCHAR2) RETURN BOOLEAN
    IS
        l_cnt     NUMBER;
       
    BEGIN
        SELECT COUNT(*)
          INTO l_cnt 
          FROM float_detail
         WHERE prod_id = i_prod_id;
         
        IF l_cnt > 0 THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END is_float_detail_exists;

----------------------------------------------------------------------------------
-- Procedure: (Public)
--     create_split_transfer_rpl
--
-- Description:
--     This procedure create non-demand replenishment tasks (NDM) to move split to split home location
--     which is left after assigning the cases to Matrix from home location 
--     Called when user generates replenishment task from form XXXXX for matrix items.  
--
-- Parameters:
--   Input:
--    i_prod_id                 Product ID
--    i_cust_pref_vendor        Cust Prefered Vendor
--    i_case_home_loc           Case Home location
--    i_qty                     Quantity to mx_item_assign_flag
--
--   Output:
--    o_status - return value
--          0  - Successful
--          1  - Error
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     User     Comments
--    -------- -------- -----------------------------------------
--    07/30/14 ayad5195 Initial Creation
--
----------------------------------------------------------------------------------

    PROCEDURE create_split_transfer_rpl(       
        i_prod_id           IN  VARCHAR2,
        i_cust_pref_vendor  IN  VARCHAR2 DEFAULT NULL, 
        i_case_home_loc     IN  VARCHAR2 DEFAULT NULL,
        i_split_home_loc    IN  VARCHAR2 DEFAULT NULL,
        i_qty               IN  NUMBER   DEFAULT NULL,
        i_batch_no          IN  NUMBER,
        o_status            OUT NUMBER)
    IS
        l_fname             VARCHAR2 (50)       := 'create_split_transfer_rpl';
        l_msg_text          VARCHAR2 (512);
        e_fail              EXCEPTION;        
        l_process_cnt       NUMBER := 0;                
        l_priority          INTEGER;            
        rpl_qty             NUMBER;
        
        /*Get the new split home location for item*/
        CURSOR c_split_home_loc IS
        SELECT i.plogi_loc                            
          FROM pm p,
               loc l,
               inv i
         WHERE l.perm = 'Y'
           AND l.prod_id IS NOT NULL
           AND i.prod_id = i_prod_id
           AND i.plogi_loc = NVL(i_split_home_loc, i.plogi_loc)
           AND i.plogi_loc = l.logi_loc          
           AND p.prod_id = l.prod_id
           AND p.cust_pref_vendor = l.cust_pref_vendor        
           AND l.uom = 1
           AND p.mx_item_assign_flag = 'Y'
           AND EXISTS (SELECT 1
                         FROM inv i2
                        WHERE i2.prod_id = l.prod_id
                          AND i2.logi_loc = i2.plogi_loc
                          AND i2.status = 'AVL'
                          AND i2.inv_uom IN (0, 2)
                          AND i2.qoh - i2.qty_alloc > 0);   

        /*Get the split inventory that needs to move to split home*/                  
        CURSOR  c_inv IS
        SELECT  l.pik_path, i.logi_loc, i.plogi_loc, i.qoh, i.qty_alloc, exp_date,
                i.parent_pallet_id, i.rec_id, i.lot_id, i.mfg_date, i.rec_date,
                i.qty_planned, i.inv_date, i.min_qty, i.abc, p.spc, i.inv_uom,
                l.slot_type, i.cust_pref_vendor
          FROM  pm p, zone z, lzone lz, loc l, inv i
         WHERE  i.prod_id = i_prod_id
           AND  i.cust_pref_vendor = NVL(i_cust_pref_vendor, i.cust_pref_vendor)
           AND  p.prod_id = i.prod_id
           AND  p.cust_pref_vendor = i.cust_pref_vendor                      
           AND  i.status = 'AVL'
           AND  i.inv_uom IN (0, 2)
           AND  i.qoh - NVL(i.qty_alloc, 0) > 0           
           AND  l.logi_loc = i.plogi_loc    
           AND  i.plogi_loc = NVL(i_case_home_loc, i.plogi_loc)
           AND  i.plogi_loc = i.logi_loc    
           AND  l.perm = 'Y'
           --AND  l.prod_id IS NULL
           AND  lz.logi_loc = l.logi_loc
           AND  z.zone_id = lz.zone_id
           AND  z.zone_type = 'PUT'
           AND  z.induction_loc IS NULL
           AND  z.rule_id IN (0, 1, 2)
           AND  p.mx_item_assign_flag = 'Y'
           FOR  UPDATE OF i.qty_alloc NOWAIT;  

    BEGIN
        o_status := C_SUCCESS;
 
        /*Find the priority based on replenishment type*/
        BEGIN
            SELECT  priority_value
              INTO  l_priority
              FROM  priority_code
             WHERE  priority_code = NDM_PRI_CD
               AND  unpack_code = 'N';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_priority := 99;
        END;        
        
        FOR r_sph IN c_split_home_loc
        LOOP
            Pl_Text_Log.ins_msg ('I', C_PROGRAM_CODE,
                                 'Create Unassign to Matrix(UNA) Replen For Item ' || i_prod_id ||
                                 ', Qty = ' || rpl_qty, NULL, NULL);
            
            FOR r_inv IN c_inv
            LOOP
                l_process_cnt := l_process_cnt + 1;
                
                rpl_qty := NVL(i_qty, r_inv.qoh - NVL(r_inv.qty_alloc, 0));
                
                /*Create replenishment task and update the inventory */ 
                INSERT  INTO replenlst (
                        task_id, prod_id, cust_pref_vendor, uom, qty, type, 
                        status, src_loc, pallet_id, 
                        dest_loc, gen_uid, gen_date, exp_date, route_no, route_batch_no, priority, 
                        parent_pallet_id, rec_id, lot_id, mfg_date, s_pikpath, 
                        orig_pallet_id, case_no, print_lpn, batch_no, mx_batch_no)
                VALUES (repl_id_seq.NEXTVAL, i_prod_id, r_inv.cust_pref_vendor, 2, rpl_qty, 'NDM',
                        'PRE', r_inv.plogi_loc, r_inv.logi_loc , 
                        r_sph.plogi_loc, REPLACE (USER, 'OPS$'), SYSDATE, r_inv.exp_date, NULL, NULL, l_priority,
                        r_inv.parent_pallet_id, r_inv.rec_id, r_inv.lot_id, r_inv.mfg_date, r_inv.pik_path,
                        DECODE (r_inv.plogi_loc, r_inv.logi_loc, NULL, DECODE (r_inv.slot_type, 'MXS', NULL, r_inv.logi_loc)),
                        ordd_seq.NEXTVAL, 'N', i_batch_no, mx_batch_no_seq.NEXTVAL);   
                        
                UPDATE  inv
                   SET  qty_alloc = NVL(qty_alloc, 0) + rpl_qty
                 WHERE  CURRENT OF c_inv;       
            END LOOP;
        END LOOP;            

        /* If no inventory available to move then return error*/ 
        IF l_process_cnt = 0 THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Inventory is not available to move to split home for prod_id '|| i_prod_id;
            RAISE e_fail;      
        END IF;     
    
    EXCEPTION    
        WHEN e_fail
        THEN
            Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE;  
        WHEN OTHERS
        THEN
            l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_unassign_matrix_rpl.';
            Pl_Text_Log.ins_msg('FATAL',C_PROGRAM_CODE,l_msg_text,SQLCODE,SQLERRM);
            o_status := C_FAILURE;      
        
    END create_split_transfer_rpl;
    
END pl_matrix_repl;
/
-- CREATE OR REPLACE PUBLIC SYNONYM pl_ml_repl FOR swms.pl_ml_repl
-- /
-- GRANT EXECUTE ON swms.pl_ml_repl TO swms_user
-- /
SHOW ERRORS
