CREATE OR REPLACE PACKAGE swms.pl_wh_move
AUTHID CURRENT_USER
AS
-- sccs_id=%Z% %W% %G% %I%
-----------------------------------------------------------------------------
-- Package Name:
--   
--
-- Description:
--    Package used for a warehouse move.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    07/15/08 prpbcb   DN: 12401
--                      Project:  562935-Warehouse Move MiniLoad Enhancement
--                      Created.
--
--    09/19/08 prpbcb   DN: 12414
--                      Project: 562935-Warehouse Move MiniLoad Enhancement
--                      Move procedure p_wh_move from pl_miniload_prossing.sql
--                      to pl_wh_move.sql.
--
--    11/08/09 prpbcb   DN: 12598  (original DN 12512 is closed)
--                      Project:
--                 CRQ8828-Miniload Functionality in Warehouse Move Process
--
--                      08/2/7/2010  Several files were changed for the Houston
--                                   warehouse move but I never checked them
--                                   in.  Checking in pl_wh_move.sql because we
--                                   need it for 11g and I want to copy over
--                                   to 11g a checked-in version.
--
--                      Added AUTHID CURRENT_USER so the new warehouse
--                      users (whrcv__ and whfrk__) see the WHMOVE schema
--                      and not the SWMS schema when pre-receiving into the
--                      new warehouse before a warehouse move.
--
--                      Added procedure update_whmove_ml_item_zone().
--                      It is called by database trigger
--                      trg_insupddel_whmv_mlitem_arow when an item is
--                      inserted or updated or deleted in table
--                      WHMV_MINILOAD_ITEM.
--                      This procedure will:
--                         - "slot" the item to the miniloader in table
--                            WHMOVE.PM by updating the zone_id and
--                            split_zone_id (if a splittable item) to the
--                            miniloader put zone when a record is
--                            inserted or updated in table WHMV_MINILOAD_ITEM.
--                            For a warehouse move if an item is moving to the
--                            miniloader then both cases and splits will go to
--                            the miniloader.
--                         - "unslot" the item from the miniloader in table
--                            WHMOVE.PM by updating the zone_id and
--                            split_zone_id to null when a record is
--                            deleted from table WHMV_MINILOAD_ITEM.
--                      Table WHMV_MINILOAD_ITEM is used to store the items
--                      moving to the miniloader during a warehouse move.
--                      Items can be inserted and deleted during the
--                      pre-move period.  At the time of the move items in
--                      this table will be directed to the miniload
--                      induction location.
--
--                      Added procedure safe_to_delete_whmv_ml_item().
--                      This procedure will determine if it is save to
--                      delete a record from table WHMV_MINILOAD_ITEM.
--
--                      Added function is_new_warehouse_user().
--                      This function returns TRUE if the user is a
--                      new warehouse user otherwise FALSE is returned. 
--
--                      Added function is_new_warehouse_loc().
--                      This function returns TRUE if the location is a
--                      new warehouse user otherwise FALSE is returned. 
--                      The check is made by looking at the first character
--                      of the location and comparing it to what is in
--
--                      Added function has_inventory_in_ml().
--
--                      Added procedures to send the planned orders to the
--                      miniloader for an item.  Ideally they should be in
--                      pl_planned_order.sql.  They were added to
--                      pl_wh_move at this time because it they are needed
--                      for the Houston warehouse move and it is easier to
--                      install pl_wh_move at Houston.  Later I will add the
--                      procedures to pl_planned_order.sql.
--                      The procedures are:
--                         - send_planned_orders_for_item
--                         - send_planned_orders
--                     Once the procedures are in pl_planned_order.sql
--                     we can remove them from pl_wh_move.sql but we will
--                     need to change trigger trig_whmove_insupd_pm_brow.sql
--                     to call pl_planned_order.send_planned_orders_for_item
--                     instead of
--                     pl_wh_move.send_planned_orders_for_item.
--
--                     08/24/2010
--                     In procedure p_wh_move() changed
--                        and   logi_loc = i_from_loc;
--                     to
--                        and   logi_loc = i_from_loc || 'C';
--                     in the where clause of the insert statement for condition
--                          if (l_case > 0 and l_split > 0) then
--                             ...
--                     Did this to match what is in the database for
--                     packge pl_wh_move at OpCo 67 Houston.  I do not know why
--                     this file did not match the database.  It is possible
--                     the change was made in pl_wh_move.sql at OpCo 67 during
--                     the February 2010 move and never was changed on rs239b.
--
--    08/27/10 prpbcb  Activity: SWMS12.0.0_0078_CRQ18634
--                     Project:
--                         CRQ18634-11g Cannot do proforma correction
--                     Copy from rs239b.
--                     A change was made in form rp1sd.fmb to call
--                     pl_wh_move.is_new_warehouse_user so weed need
--                     the latest pl_wh_move which was checked in on
--                     rs239b today.  I never checked it in on rs239b
--                     after it was changed for the Houston warehouse
--                     move back in Febrary 2010.
--
--    06/20/11 prpbcb  Remedy Problem: 3209
--                     Clearcase Activty:
--                         PBI3209-Identifying_new_warehouse user
--
--                     Changed these functions to be pass through
--                     functions calling the corresponding function
--                     in pl_wh_move_utilities.
--                        - Function get_syspar_warehouse_move_type
--                        - Runction is_new_warehouse_user
--                     Right now these functions exist in two
--                     packages.  At some point the objects calling
--                     the pl_wh_move functions will get changed
--                     to directly use the functions in pl_wh_move_utilities.
--
--    **************************************************************
--    ***** 03/26/12 prpbcb  Dual maintain changes from rs239b *****
--          All changes put under the CRQ29875 project.         
--    03/26/12 prpbcb  DN 12613
--                     8i Project:
--              CRQ29875-Print_new_warehouse_aisle_on_receiving label
--
--                     11g Project:
--              CRQ29875-Print_new_warehouse_aisle_on_receiving label
--
--    12/09/11 prpbcb   DN:
--                      Project:
--                      San Antonio move changes
--                      Added global variable "g_exec_swms_inv_trig_control".
--                      It is used to control if trigger
--                      "swms.trg_ins_swms_inv" is to run through its code.
--                      If g_exec_swms_inv_trig_control is set to 'N' then
--                      trigger "trg_ins_swms_inv" does nothing.
--                      This is for a a workaround to get inventory moved
--                      from reserve in the new warehouse to the home slot in
--                      the new warehouse.
--
--    11/30/11 prpbcb   DN 12613
--                      8i Project:
--              CRQ29875-Print_new_warehouse_aisle_on_receiving label
--
--                      11g Project:
--              CRQ29875-Print_new_warehouse_aisle_on_receiving label
--
--                      Print the new warehouse aisle to stage the pallet in
--                      on the bottom right of the receiving LP when
--                      warehouse move is active.  The item will need to have
--                      the old home slot and the new home slot setup in the
--                      WHMVELOC_HIST table.  Having the staging aisle on
--                      the receiving label keeps from having to print the
--                      small move label when moving reserve pallets.
--
--                      Added functions:
--                         - get_new_whse_staging_location()
--                         - get_new_whse_staging_aisle()
--    ***** 03/26/12 prpbcb End Dual maintain changes from rs239b *****
--    *****************************************************************
--
--
-----------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------

g_exec_swms_inv_trig_control  VARCHAR2(1) := 'Y';


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    get_syspar_warehouse_move_type
--
-- Description:
--    This function returns the value of syspar "WAREHOUSE_MOVE_TYPE"
--    FROM THE SWMS SCHEMA.  The setting in the swms schema is the
--    driving value.  We do not check what the setting is in the
--    whmove schema.
---------------------------------------------------------------------------
FUNCTION get_syspar_warehouse_move_type
RETURN sys_config.config_flag_val%TYPE;


---------------------------------------------------------------------------
-- Function:
--    get_temp_new_wh_loc
--
-- Description:
--    This function returns the temporary new warehouse location when
--    passed the actual location in the new warehouse.
--
--    Table WHMVELOC_AREA_XREF is to determine the temporary new 
--    warehouse location.
---------------------------------------------------------------------------
FUNCTION get_temp_new_wh_loc(i_actual_new_wh_loc  IN loc.logi_loc%TYPE)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    has_inventory_in_ml
--
-- Description:
--    This function returns TRUE if their is inventory in the miniloader
--    for an item othersize FALSE is returned.  An item is considered to
--    have inventory in the miniloader if there is an inventory record
--    with a slot type of MLS.
---------------------------------------------------------------------------
FUNCTION has_inventory_in_ml(i_prod_id           IN inv.prod_id%TYPE,
                             i_cust_pref_vendor  IN inv.cust_pref_vendor%TYPE)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- PROCEDURE
--    p_wh_move
--
-- Description:
--     This procedure is called from wh_move.pc when an opco moves
--     to a new warehouse miniload location from old warehouse.
---------------------------------------------------------------------------
PROCEDURE p_wh_move(i_from_loc  IN  loc.logi_loc%TYPE,
                    i_to_loc    IN  loc.logi_loc%TYPE,
                    i_pick_yn   IN  loc.perm%TYPE,
                    i_pallet_id IN  inv.logi_loc%TYPE,
                    o_status    OUT NUMBER);


---------------------------------------------------------------------------
-- Procedure:
--    whmove_slot_item_to_ml
--
-- Description:
--    This procedure "slots" or "unslots" and item to the miniloader in the
--    new warehouse by updating the WHMOVE.PM zone_id and split_zone_id.
--    This is done to allow pre-receiving into the miniloader in the
--    new warehouse.  It is called by database trigger
--    trg_insupddel_whmv_mlitem_arow when an item is inserted or updated or
--    deleted in table WHMV_MINILOAD_ITEM.
--
--    ********************************************************************
--    This procedure should only be used during the pre-receiving period.
--    ********************************************************************
--
--    This procedure will:
--       - "slot" the item to the miniloader in table
--          WHMOVE.PM by updating the zone_id and
--          split_zone_id (if a splittable item) to the
--          miniloader put zone when a record is
--          inserted or updated in table WHMV_MINILOAD_ITEM.
--          For a warehouse move if an item is moving to the
--          miniloader then both cases and splits will go to
--          the miniloader.
--       - "unslot" the item from the miniloader in table
--          WHMOVE.PM by updating the zone_id and
--          split_zone_id to null when a record is
--          deleted from table WHMV_MINILOAD_ITEM.
--
--    Table WHMV_MINILOAD_ITEM is used to store the items
--    moving to the miniloader during a warehouse move.
--    Items can be inserted and deleted during the
--    pre-move period.  At the time of the move items in
--    this table will be directed to the miniload
--    induction location.
---------------------------------------------------------------------------
PROCEDURE whmove_slot_item_to_ml
            (i_action           IN VARCHAR2,
             i_induction_loc    IN whmv_miniload_item.induction_loc%TYPE,
             i_prod_id          IN whmv_miniload_item.prod_id%TYPE,
             i_cust_pref_vendor IN whmv_miniload_item.cust_pref_vendor%TYPE);


---------------------------------------------------------------------------
-- Procedure:
--    safe_to_delete_whmv_ml_item
--
-- Description:
--    This procedure will determine if it is save to delete a record from
--    table WHMV_MINILOAD_ITEM.  If there is inventory in the minloader in
--    the new warehouse then the record cannot be deleted.  The OpCo needs
--    to get the inventory out of the miniloader then the record can be
--    deleted.
--
--    Table WHMV_MINILOAD_ITEM is used to store the items moving to the
--    miniloader during a warehouse move.  Items can be inserted and deleted
--    during the pre-move period.  At the time of the move items in this table
--    will be directed to the miniload induction location.
---------------------------------------------------------------------------
PROCEDURE safe_to_delete_whmv_ml_item
          (i_prod_id             IN  whmv_miniload_item.prod_id%TYPE,
           i_cust_pref_vendor    IN  whmv_miniload_item.cust_pref_vendor%TYPE,
           o_safe_to_delete_bln  OUT BOOLEAN,
           o_message             OUT VARCHAR2);


---------------------------------------------------------------------------
-- Function:
--    is_new_warehouse_user
--
-- Description:
--    This procedure returns TRUE if the user is a new warehouse user
--     otherwise FALSE is returned. 
---------------------------------------------------------------------------
FUNCTION is_new_warehouse_user(i_user_id  IN usr.user_id%TYPE)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Function:
--    is_new_warehouse_loc
--
-- Description:
--    This function returns TRUE if the location in the SWMS schema is
--    a new warehouse user otherwise FALSE is returned. 
--
-- *******************************************************************
-- *******************************************************************
-- Only use this function during the pre-receiving period.
-- The location needs to be the location as stored in the SWMS schema.
-- *******************************************************************
-- *******************************************************************
---------------------------------------------------------------------------
FUNCTION is_new_warehouse_loc(i_loc  IN loc.logi_loc%TYPE)
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Procedure:
--    send_planned_orders_for_item
--
-- Description:
--
--    This procedure sends the planned orders to the miniloaders for a
--    specified item for a specified date.
---------------------------------------------------------------------------
PROCEDURE send_planned_orders_for_item
            (i_prod_id          IN planned_order_dtl.prod_id%TYPE,
             i_cust_pref_vendor IN planned_order_dtl.cust_pref_vendor%TYPE,
             i_order_date       IN DATE,
             o_status           IN OUT PLS_INTEGER);


---------------------------------------------------------------------------
-- Function:
--    get_new_whse_staging_location
--
-- Description:
--    This function returns the location in the new warehouse to stage
--    the pallet by when moving reserve pallets from the old warehouse
--    during the move process.
--
--    The staging location will either be the new warehouse home slot
--    (i_new_whse_home_slot) or will be the back location of the new
--    warehouse home slot.
--
-- Parameters:
--    i_new_whse_home_slot  - The home slot in the new warehouse.
--                            This needs to be the actual home slot and
--                            not with the temp area.
---------------------------------------------------------------------------
FUNCTION get_new_whse_staging_location(i_new_whse_home_slot IN VARCHAR2)
RETURN VARCHAR2;


---------------------------------------------------------------------------
-- Function:
--    get_new_whse_staging_aisle
--
-- Description:
--    This function returns the aisle in the new warehouse to stage
--    the pallet by when moving reserve pallets from the old warehouse
--    during the move process.
--
--    The staging aisle will either be the aisle of new warehouse home slot
--    or will be the aisle of the back location of the new
--    warehouse home slot.
--
--    Function get_new_whse_staging_location() is called which returns
--    the staging location.  A substr is make on this to return the aisle.
--
-- Parameters:
--    i_new_whse_home_slot  - The home slot in the new warehouse.
--                            This needs to be the actual home slot and
---------------------------------------------------------------------------
FUNCTION get_new_whse_staging_aisle(i_new_whse_home_slot IN VARCHAR2)
RETURN VARCHAR2;


END pl_wh_move;
/

show errors

CREATE OR REPLACE PACKAGE BODY swms.pl_wh_move
AS
-- sccs_id=%Z% %W% %G% %I%

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_wh_move';   -- Package name.
                                              -- Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function VARCHAR2(10) := 'INVENTORY';


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Function:
--    get_syspar_warehouse_move_type
--
-- Description:
--    This function returns the value of syspar "WAREHOUSE_MOVE_TYPE"
--    FROM THE SWMS SCHEMA.  The setting in the swms schema is the
--    driving value.  We do not check what the setting is in the
--    whmove schema.
--    
-- Parameters:
--    None
--
-- Return Values:
--    Setting for syspar WAREHOUSE_MOVE_TYPE.
--    If the syspar does not exist then null is returned.
--
-- Called by:
--      Form mw1sa.fmb
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/15/08 prpbcb   Created.
--    07/26/11 prpbcb   Changed to be a pass through calling the
--                      corresponding function in pl_wh_move_utilities.sql
---------------------------------------------------------------------------
FUNCTION get_syspar_warehouse_move_type
RETURN sys_config.config_flag_val%TYPE
IS
   l_config_flag_val    sys_config.config_flag_val%TYPE;
   l_object_name        VARCHAR2(61);
BEGIN
   l_config_flag_val := pl_wh_move_utilities.get_syspar_warehouse_move_type;

   RETURN l_config_flag_val;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := gl_pkg_name || '.get_syspar_warehouse_move_type';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, 'Error',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END get_syspar_warehouse_move_type;


---------------------------------------------------------------------------
-- Function:
--    get_temp_new_wh_loc
--
-- Description:
--    This function returns the temporary new warehouse location when
--    passed the actual location in the new warehouse.
--
--    If the location is already the temporary location then the
--    location parameter is returned unchanged.
--    If the no new location s found then the
--    location parameter is returned unchanged.
--
--    Table WHMVELOC_AREA_XREF is to determine the temporary new 
--    warehouse location;
--
--    Example:
--       The record in table WHMVELOC_AREA_XREF is:
--          Column                      Value
--          -------------------------   -----
--          TMP_NEW_WH_AREA               Z
--          ORIG_OLD_WH_AREA              F
--          PUTBACK_WH_AREA               F
--          TMP_FR_OLD_TO_NEW_PASS        0
--          TMP_FR_OLD_TO_NEW_FAIL        M
--       The actual location in the new warehouse is FA11A1.
--       This function will return ZA11A1 when called with FA11A1.
--       This function will return ZA11A1 when called with ZA11A1.
--
-- Parameters:
--    i_actual_loc - The actual location in the new warehouue.
--  
-- Return Values:
--    The temporary new warehouse location.
--
-- Called By:
--    Database trigger trg_insupd_ml_mesg_whmove.
--    
-- Exceptions Raised:
--    pl_exc.e_data_error      - The area for i_actual_loc was not in
--                               WHMVELOC_AREA_XREF.
--    pl_exc.e_database_error  - Got an oracle error.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/21/08 prpbcb   Created for the warehouse move changes moving to
--                      a new warehouse with a miniloader.
--                    
--    07/28/08 prpbcb   Created to return i_actual_new_wh_loc if unable
--                      to convert to the temp warehouse location.
--                      This means exception e_no_location will not get
--                      raised.
--    07/26/11 prpbcb   Changed to be a pass through calling the
--                      corresponding function in pl_wh_move_utilities.sql
---------------------------------------------------------------------------
FUNCTION get_temp_new_wh_loc(i_actual_new_wh_loc  IN loc.logi_loc%TYPE)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(61);

   l_temp_new_wh_loc   loc.logi_loc%TYPE; -- The temporary location
BEGIN
   l_temp_new_wh_loc := pl_wh_move_utilities.get_temp_new_wh_loc(i_actual_new_wh_loc);

   RETURN l_temp_new_wh_loc;
   
EXCEPTION
   WHEN OTHERS THEN
      l_object_name := 'get_temp_new_wh_loc';
      l_message := l_object_name || ' i_actual_new_wh_loc[' 
                  || i_actual_new_wh_loc || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' ||  SQLERRM);
END get_temp_new_wh_loc;


---------------------------------------------------------------------------
-- Function:
--    has_inventory_in_ml
--
-- Description:
--    This function returns TRUE if their is inventory in the miniloader
--    for an item othersize FALSE is returned.  An item is considered to
--    have inventory in the miniloader if there is an inventory record
--    with a slot type of MLS.
--
-- Parameters:
--    i_prod_id          - The item to check.
--    i_cust_pref_vendor - The CPV to check.
--
-- Return Values:
--    TRUE  - The item has inventory in the miniloader.
--    FALSE - The item does not have inventory in the miniloader.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - pl_wh_move.safe_to_delete_whmv_ml_item
--    - whmove.trig_whmove_insupd_pm_brow datbase trigger
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/13/09 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION has_inventory_in_ml(i_prod_id           IN inv.prod_id%TYPE,
                             i_cust_pref_vendor  IN inv.cust_pref_vendor%TYPE)
RETURN BOOLEAN
IS
   l_object_name   VARCHAR2(30);     -- Function name, used in error messages.
   l_message       VARCHAR2(256);    -- Message buffer

   l_dummy         VARCHAR2(1);      -- Work area
   l_return_value  BOOLEAN;

   --
   -- This cursor checks if the item has inventory in the miniloader.
   --
   CURSOR c_ml_inv(cp_prod_id           inv.prod_id%TYPE,
                   cp_cust_pref_vendor  inv.cust_pref_vendor%TYPE) IS
   SELECT 'x'
     FROM swms.inv i, swms.loc l
    WHERE i.prod_id          = cp_prod_id
      AND i.cust_pref_vendor = cp_cust_pref_vendor
      AND l.logi_loc         = i.plogi_loc
      AND l.slot_type        = 'MLS';
BEGIN
   OPEN c_ml_inv(i_prod_id, i_cust_pref_vendor);
   FETCH c_ml_inv INTO l_dummy;
   IF (c_ml_inv%FOUND) THEN
      l_return_value := TRUE;
   ELSE
      l_return_value := FALSE;
   END IF;

   CLOSE c_ml_inv;

   RETURN(l_return_value);
   
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := 'has_inventory_in_ml';
      l_message := 'Failed to determine if item[' || i_prod_id || ']'
           || '  CPV[' || i_cust_pref_vendor || ']'
           || ' has inventory in the miniloader';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || l_message);
END has_inventory_in_ml;


---------------------------------------------------------------------------
-- PROCEDURE
--    p_wh_move
--
-- Description:
--     This procedure is called from wh_move.pc when an opco moves
--     to a new warehouse miniload location from old warehouse.
--     The procedure
--          1. If home slot, Unslots the old home location
--          2. Creates inventory for the miniload induction location. 
--          3. Send expected receipt for miniload.
---------------------------------------------------------------------------
PROCEDURE p_wh_move(i_from_loc   IN  loc.logi_loc%TYPE,
                    i_to_loc     IN  loc.logi_loc%TYPE,
                    i_pick_yn    IN  loc.perm%TYPE,
                    i_pallet_id  IN  inv.logi_loc%TYPE,
                    o_status     OUT NUMBER) 
IS

	  l_zone_id   zone.zone_id%type;
	  l_prod_id      pm.prod_id%type;
	  l_qoh       inv.qoh%type;
	  l_qty_planned  inv.qty_planned%type;
	  l_qty_alloc    inv.qty_alloc%type;
	  l_temp_area    varchar2(1);
	  l_cpv          loc.cust_pref_vendor%type;
	  l_rank         loc.rank%type;
	  l_uom          loc.uom%type;
	  l_case	 inv.qoh%type;
	  l_split	 inv.qoh%type;
	  l_ship_split_only pm.auto_ship_flag%type;
	  l_exp_date     inv.exp_date%type;
	  l_wh_type      varchar2(1);
	  l_ti		 pm.ti%type;
	  l_hi		 pm.ti%type;
	  l_gweight	 pm.g_weight%type;
	  l_pallet_type  pm.pallet_type%type;
	  r_exp_rcv pl_miniload_processing.t_exp_receipt_info;
	  l_split_loc    inv.logi_loc%TYPE;
   	  l_status    NUMBER := 0;         -- Status of package call
          lv_msg_text       VARCHAR2 (1500);
          lv_fname          VARCHAR2 (50)   := 'P_WH_MOVE';

	  error_update EXCEPTION;
    method_not_supported EXCEPTION;
	  --
	  cursor get_zone is
	  select z.zone_id
	  from swms.lzone lz,swms.zone z
	  where lz.zone_id = z.zone_id
	  and   z.zone_type = 'PUT'
	  and   lz.logi_loc = l_temp_area||substr(i_to_loc,2);
	  --
	  cursor get_qty is
	  select l.prod_id, trunc(qoh/spc)*spc, mod(qoh,spc), qoh, l.cust_pref_vendor,
		 l.rank,l.uom, pm.auto_ship_flag, i.exp_date
	  from swms.inv i,swms.loc l, pm 
	  where l.logi_loc = i_from_loc
	  and   i.prod_id = l.prod_id
	  and   i.plogi_loc = l.logi_loc
	  and   l.perm='Y'
	  and   i.plogi_loc = i.logi_loc
	  and   l.prod_id = pm.prod_id;
	  --
	  cursor get_qty_resv is
	  select i.prod_id, trunc(qoh/spc)*spc, mod(qoh,spc), qoh, pm.cust_pref_vendor,
		 i.inv_uom, pm.auto_ship_flag, i.exp_date
	  from swms.inv i, pm 
	  where i.plogi_loc = i_from_loc
	  and   i.logi_loc = rtrim(i_pallet_id)
	  and   i.prod_id = pm.prod_id;


	  cursor cross_ref is
	  select tmp_new_wh_area
	  from whmveloc_area_xref
	  where putback_wh_area = substr(i_to_loc,1,1);
	
   begin
	   o_status := 0;
	   lv_msg_text := 'From slot=(' || i_from_loc ||') to_slot=('||i_to_loc||') perm=('||i_pick_yn||') Pallet=('||i_pallet_id||')';
	   Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);

	   open cross_ref;
	   fetch cross_ref into l_temp_area;
	   if cross_ref%notfound then
               DBMS_OUTPUT.PUT_LINE('Error, cross_ref no record found');
		raise error_update;
	   end if;
           close cross_ref;

	If (i_pick_yn = 'Y') then
	   open get_qty;
	   fetch get_qty into l_prod_id, l_case, l_split, l_qoh,
				l_cpv, l_rank, l_uom, l_ship_split_only, l_exp_date;
	   if get_qty%NOTFOUND then
              DBMS_OUTPUT.PUT_LINE('Error, get_qty no record found');
		raise error_update;
	   end if;

	   close get_qty;
	
	   update swms.loc
	     set prod_id = null,
         	cust_pref_vendor = null,
         	uom = null, rank = null
   	   where logi_loc = i_from_loc;

            IF (SQL%ROWCOUNT = 0)
            THEN
                DBMS_OUTPUT.PUT_LINE('Error, no swms.loc record updated');
		raise error_update;
	    END IF;

	  if (l_uom <> 0) then

	   	update swms.inv
	     	set logi_loc = i_from_loc || 'C',
	            plogi_loc = l_temp_area || substr(i_to_loc,2)
	  	where prod_id = l_prod_id
	   	and   plogi_loc = i_from_loc
	   	and   logi_loc = plogi_loc;

	        IF (SQL%ROWCOUNT = 0)
                THEN
                   DBMS_OUTPUT.PUT_LINE('Error, no swms.loc record updated when l_uom <> 0');
		     raise error_update;
	        END IF;
           else 
		if l_case > 0 then
	   		update swms.inv
	     		set logi_loc = i_from_loc || 'C',
	             	    plogi_loc = l_temp_area || substr(i_to_loc,2),
		  	    inv_uom = 2	,
			    qoh = decode (l_split, 0, qoh, qoh -l_split)
	  		where prod_id = l_prod_id
	   		and   plogi_loc = i_from_loc
	   		and   logi_loc = plogi_loc;
	        	IF (SQL%ROWCOUNT = 0)
                	THEN
                            DBMS_OUTPUT.PUT_LINE('Error, no inv record found when appending C to logi_loc');
		     		raise error_update;
	        	END IF;
		else
	   		update swms.inv
	     		set logi_loc = i_from_loc,
	             	    plogi_loc = l_temp_area || substr(i_to_loc,2),
		  	    inv_uom = 1	
	  		where prod_id = l_prod_id
	   		and   plogi_loc = i_from_loc
	   		and   logi_loc = plogi_loc;
	        	IF (SQL%ROWCOUNT = 0)
                	THEN
                            DBMS_OUTPUT.PUT_LINE('Error, no inv record found when not appending C to logi_loc');
		     		raise error_update;
	        	END IF;
		end if;
		if (l_case > 0 and l_split > 0) then
			insert into swms.inv (PROD_ID, REC_ID, MFG_DATE, REC_DATE, EXP_DATE,
 					INV_DATE, LOGI_LOC, PLOGI_LOC, QOH, QTY_ALLOC,
					 QTY_PLANNED, MIN_QTY, ABC, STATUS, CUST_PREF_VENDOR,
 					INV_UOM)
			select PROD_ID, REC_ID, MFG_DATE, REC_DATE, EXP_DATE,
					INV_DATE, LOGI_LOC||'S', PLOGI_LOC, l_split, 0,
				0, MIN_QTY, ABC, STATUS, CUST_PREF_VENDOR,1
			from swms.inv
			where plogi_loc = l_temp_area || substr(i_to_loc,2)
			and   prod_id = l_prod_id
			and   logi_loc = i_from_loc || 'C';
	        	IF (SQL%ROWCOUNT = 0)
                	THEN
                            DBMS_OUTPUT.PUT_LINE('Error, no swms.inv inserted');
		     		raise error_update;
	        	END IF;

		end if;
	   end if;

	   begin
	   	select config_flag_val
	   	into l_wh_type
	   	from swms.sys_config
	   	where config_flag_name ='WAREHOUSE_MOVE_TYPE';
	   	exception
	      		when others then
	        		l_wh_type := 'N';
	   end;
	
	   if l_wh_type <> 'P' then
         $if swms.platform.SWMS_PLATFORM_LINUX $then
            raise method_not_supported;
         $else
            insert into whmove.inv (PROD_ID, REC_ID, MFG_DATE, REC_DATE, EXP_DATE,
 					INV_DATE, LOGI_LOC, PLOGI_LOC, QOH, QTY_ALLOC,
					 QTY_PLANNED, MIN_QTY, ABC, STATUS, CUST_PREF_VENDOR,
 					INV_UOM)
               select PROD_ID, REC_ID, MFG_DATE, REC_DATE, EXP_DATE,
                  INV_DATE, LOGI_LOC, i_to_loc, QOH, QTY_ALLOC,
                  QTY_PLANNED, MIN_QTY, ABC, STATUS, CUST_PREF_VENDOR,INV_UOM
               from swms.inv
               where plogi_loc = l_temp_area || substr(i_to_loc,2)
               and   prod_id = l_prod_id
               and   (logi_loc = i_from_loc or logi_loc = i_from_loc||'C');
            IF (SQL%ROWCOUNT = 0)
                  THEN
                           DBMS_OUTPUT.PUT_LINE('Error, no whmove.inv record'
                              || ' inserted.'
                              || ' l_temp_area[' || l_temp_area || ']'
                              || ' i_to_loc[' || i_to_loc || ']'
                              || ' l_prod_id[' || l_prod_id || ']');
               raise error_update;
            END IF;
         $end
	   end if;

	   open get_zone;
	   fetch get_zone into l_zone_id;
	   if get_zone%NOTFOUND then
              DBMS_OUTPUT.PUT_LINE('get_zone found no record');
	      l_zone_id := 'MFPT1';
	   end if;
	   close get_zone;
DBMS_OUTPUT.PUT_LINE('AAAA');
	   --
	   begin
	     	select ti,hi,pallet,g_weight
	     	into l_ti, l_hi, l_pallet_type, l_gweight
	     	from whmv_miniload_item
	     	where prod_id = l_prod_id;
	
	   		update swms.pm
	    	    	set ti = nvl(l_ti,ti),
	        		hi = nvl(l_hi,hi),
	        		zone_id = l_zone_id,
	        		pallet_type = nvl(l_pallet_type,pallet_type),
	        		g_weight = nvl(l_gweight,g_weight)
	   		where prod_id = l_prod_id;
	        	IF (SQL%ROWCOUNT = 0)
                	THEN
                           DBMS_OUTPUT.PUT_LINE('Error, AAAA no swms.inv record updated');
		     		raise error_update;
	        	END IF;
	     	exception
			when others then
				null;
	   end;
	   --
	   update swms.putawaylst
	     set dest_loc = l_temp_area || substr(i_to_loc,2)
	     where dest_loc = i_from_loc;
	   update swms.replenlst
	     set src_loc = l_temp_area || substr(i_to_loc,2)
	     where src_loc = i_from_loc;
	   update swms.replenlst
	     set dest_loc = l_temp_area || substr(i_to_loc,2)
	     where dest_loc = i_from_loc;
	   update swms.cc
	     set phys_loc = l_temp_area || substr(i_to_loc,2),
	         logi_loc = l_temp_area || substr(i_to_loc,2)
	     where phys_loc = i_from_loc
	     and   phys_loc = logi_loc;
	   update swms.cc_exception_list
	     set phys_loc = l_temp_area || substr(i_to_loc,2),
	         logi_loc = l_temp_area || substr(i_to_loc,2)
	     where phys_loc = i_from_loc
     	     and   logi_loc = phys_loc;
	ELSE
          BEGIN
	  	select i.prod_id, trunc(qoh/spc)*spc, mod(qoh,spc), qoh, pm.cust_pref_vendor,
		 	i.inv_uom, pm.auto_ship_flag, i.exp_date
	  	into l_prod_id, l_case, l_split, l_qoh,
			l_cpv,  l_uom, l_ship_split_only, l_exp_date
	  	from swms.inv i, pm 
	  	where i.plogi_loc = l_temp_area||substr(i_to_loc,2)
	  	and   i.logi_loc = rtrim(i_pallet_id)
	  	and   i.prod_id = pm.prod_id;
	   		lv_msg_text := 'prod='||l_prod_id||' lcase='||to_char(l_case)|| ' l_split='||to_char(l_split) || ' qoh='||to_char(l_qoh);
	   		Pl_Text_Log.ins_msg ('INFO', lv_fname, lv_msg_text, NULL, NULL);
          	EXCEPTION
            		WHEN OTHERS THEN
	    			lv_msg_text := 'prod not found';
	   			Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, SQLCODE, SQLERRM);
				raise error_update;
	  END;

	END IF;
    

      DBMS_OUTPUT.PUT_LINE('BBBBB');
      --
      --  Create the expected receipt.
      --
      If (i_pick_yn = 'Y') then
      	r_exp_rcv.v_expected_receipt_id  := i_from_loc || 'C';
      else
      	r_exp_rcv.v_expected_receipt_id  := i_pallet_id;
      end if;
	
      r_exp_rcv.v_prod_id              := l_prod_id;
      r_exp_rcv.v_cust_pref_vendor     := l_cpv;

	
      if l_ship_split_only = 'Y' then
	 l_uom := 1;
      end if;

      if l_uom <> 0 then
      	r_exp_rcv.n_uom                		:= l_uom;
      	r_exp_rcv.n_qty_expected        	:= l_qoh;
      else
        if l_case > 0 then
      		r_exp_rcv.n_uom        		:= 2;
      		r_exp_rcv.n_qty_expected        := l_case;
	else 
      		r_exp_rcv.n_uom        		:= 1;
      		r_exp_rcv.n_qty_expected        := l_split;
	end if;
      end if;

      r_exp_rcv.v_inv_date             := l_exp_date;

      --
      -- Procedure p_send_exp_receipt needs the quantity in splits.
      --  uom needs to be 1 or 2.
      --

      pl_miniload_processing.p_send_exp_receipt(r_exp_rcv, l_status);

      if l_status = 0 then
	 if (l_uom = 0 and l_split > 0 and l_case > 0) then

		SELECT i_from_loc||'S' into l_split_loc from dual;

      		r_exp_rcv.v_expected_receipt_id  := l_split_loc;
      	 	r_exp_rcv.n_uom                := 1;
      	 	r_exp_rcv.n_qty_expected       := l_split;
      		pl_miniload_processing.p_send_exp_receipt(r_exp_rcv, l_status);
         end if;
      end if;
      if l_status <> 0 then
         DBMS_OUTPUT.PUT_LINE('Error, p_send_exp_receipt status is ' || TO_CHAR(l_status));
         raise error_update;
      end if;
      
   EXCEPTION
      when error_update then
         o_status := 1;	
      when method_not_supported then
         DBMS_OUTPUT.PUT_LINE('PL_WH_MOVE package not supported for LINUX');
         o_status := 1;	
 
END p_wh_move;  


---------------------------------------------------------------------------
-- Procedure:
--    whmove_slot_item_to_ml
--
--    ********************************************************************
--    This procedure should only be used during the pre-receiving period.
--    ********************************************************************
--
-- Description:
--
--    This procedure "slots" or "unslots" and item to the miniloader in the
--    new warehouse by updating the WHMOVE.PM zone_id and split_zone_id.
--    This is done to allow pre-receiving into the miniloader in the
--    new warehouse.  It is called by database trigger
--    trg_insupddel_whmv_mlitem_arow when an item is inserted or updated or
--    deleted in table WHMV_MINILOAD_ITEM.
--
--    There is a database trigger on the WHMOVE.PM table that will update
--    the miniload_storage_ind based on the values of zone_id and
--    split_zone_id.  This trigger will send a new SKU or delete SKU to the
--    miniloader as appropriate.
--
--    This procedure will:
--       - "slot" the item to the miniloader in table
--          WHMOVE.PM by updating the zone_id and
--          split_zone_id (if a splittable item) to the
--          miniloader put zone when a record is
--          inserted or updated in table WHMV_MINILOAD_ITEM.
--          For a warehouse move if an item is moving to the
--          miniloader then both cases and splits will go to
--          the miniloader.
--       - "unslot" the item from the miniloader in table
--          WHMOVE.PM by updating the zone_id and
--          split_zone_id to null when a record is
--          deleted from table WHMV_MINILOAD_ITEM.
--
--    Table WHMV_MINILOAD_ITEM is used to store the items
--    moving to the miniloader during a warehouse move.
--    Items can be inserted and deleted during the
--    pre-move period.  At the time of the move items in
--    this table will be directed to the miniload
--    induction location.
--
-- Parameters:
--    i_action            - Either 'SLOT' or 'UNSLOT'.
--                          If 'SLOT' then update WHMOVE.PM zone_id and
--                          split_zone_id (if a splittable item) to the
--                          induction location put zone.
--                          If 'UNSLOT' then update WHMOVE.PM zone_id
--                          and split_zone_id to null.
--    i_induction_loc     - The miniloader induction location.
--                          The is the actual location and not the
--                          temporary location.
--    i_prod_id           - The item to pre-receive into the miniloader.
--    i_cust_pref_vendor  - The CPV to pre-receive into the miniloader.
--
-- Called by:
--      Database trigger trg_insupddel_whmv_mlitem_arow
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/09/09 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE whmove_slot_item_to_ml
            (i_action           IN VARCHAR2,
             i_induction_loc    IN whmv_miniload_item.induction_loc%TYPE,
             i_prod_id          IN whmv_miniload_item.prod_id%TYPE,
             i_cust_pref_vendor IN whmv_miniload_item.cust_pref_vendor%TYPE)
IS
   l_object_name     VARCHAR2(30) := 'whmove_slot_item_to_ml';   -- Procedure
                                             -- name.  Used in error messages.
   l_message         VARCHAR2(512);  -- Message buffer.
   l_parameter_list_message  VARCHAR2(256);  -- Message buffer of the
                                     -- parameter list.
                                     -- Used in error messages.

   e_bad_parameter        EXCEPTION;  -- Invalid parameter.
   e_no_pm_record_updated EXCEPTION;  -- No WHMOVE.PM record was updated.
   e_parameter_null       EXCEPTION;  -- A required parameter is null.

BEGIN
   --
   -- Build the parameter list message.  It gets assigned everytime this
   -- procedure is called but is only used in error messages.  Doing it here
   -- saves repeating it in the different error messages.
   -- It will slow processing a very very small amount and since the warehouse
   -- move is a one time event we will not worry about the extra
   -- execution time.
   --
   l_parameter_list_message := l_object_name
         || '(i_action['          || i_action           || ']'
         || 'i_induction_loc['    || i_induction_loc    || ']'
         || 'i_prod_id['          || i_prod_id          || ']'
         || 'i_cust_pref_vendor[' || i_cust_pref_vendor || '])';

   --
   -- Check for a null parameter.
   --
   IF (   i_action           IS NULL
       OR i_induction_loc    IS NULL
       OR i_prod_id          IS NULL
       OR i_cust_pref_vendor IS NULL) THEN
      RAISE e_parameter_null;
   END IF;

   --
   -- Slot or unslot the item depending on the action.
   --
   IF (i_action = 'SLOT') THEN
      UPDATE whmove.pm pm
         SET (pm.zone_id, pm.split_zone_id) =
             (SELECT z.zone_id,
                     DECODE(pm.split_trk, 'Y', z.zone_id, NULL)
                FROM swms.zone z,
                     v_whmove_newloc v_newloc
               WHERE z.induction_loc      = v_newloc.tmp_logi_loc
                 AND v_newloc.logi_loc    = i_induction_loc
                 AND z.rule_id            = 3)   -- Sanity check
      WHERE pm.prod_id          = i_prod_id
        AND pm.cust_pref_vendor = i_cust_pref_vendor
        AND EXISTS
             (SELECT 'x'
                FROM swms.zone z2,
                     v_whmove_newloc v_newloc2
               WHERE z2.induction_loc      = v_newloc2.tmp_logi_loc
                 AND v_newloc2.logi_loc    = i_induction_loc
                 AND z2.rule_id            = 3);   -- Sanity check

      IF (SQL%NOTFOUND) THEN
         --
         -- No record was updated.  This is a fatal error.
         --
         l_message := 'TABLE=whmove.pm  ACTION=UPDATE'
              || '  KEY=[' || i_prod_id || ']'
              || '[' || i_cust_pref_vendor || ']'
              || '[' || i_induction_loc || ']'
              || '(i_prod_id,i_cust_pref_vendor,i_induction_loc)'
              || '  i_action[' || i_action || ']'
              || '  MESSAGE="No record updated setting zone id and'
              || ' miniload storage indicator using i_induction_loc'
              || ' and swms.zone table.'
              || '  Check item, induction loc."';
         RAISE e_no_pm_record_updated;
      END IF;

   ELSIF (i_action = 'UNSLOT') THEN
      UPDATE whmove.pm pm
         SET pm.zone_id              = NULL,
             pm.split_zone_id        = NULL
      WHERE pm.prod_id          = i_prod_id
        AND pm.cust_pref_vendor = i_cust_pref_vendor;

      IF (SQL%NOTFOUND) THEN
         --
         -- No record was updated.  This is a fatal error.
         --
         l_message := 'TABLE=whmove.pm  ACTION=UPDATE'
              || '  KEY=[' || i_prod_id || ']'
              || '[' || i_cust_pref_vendor || ']'
              || '(i_prod_id,i_cust_pref_vendor)'
              || '  i_action[' || i_action || ']'
              || '  MESSAGE="No record updated setting zone id,'
              || ' split_zone_id to null and miniload storage indicator to N.'
              || '  Check the item."';
         RAISE e_no_pm_record_updated;
      END IF;
   ELSE
      --
      -- i_action has an unhandled value.
      --
      RAISE e_bad_parameter;
   END IF;

EXCEPTION
   WHEN e_parameter_null THEN
      l_message := l_parameter_list_message
                   || '  A parameter is null.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN e_bad_parameter THEN
      l_message := l_parameter_list_message
                   || '  i_action has an handled value.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN e_no_pm_record_updated THEN
       -- l_message already built.
       pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                      NULL, NULL,
                      pl_rcv_open_po_types.ct_application_function,
                      gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_message := l_parameter_list_message;

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END whmove_slot_item_to_ml;


---------------------------------------------------------------------------
-- Procedure:
--    safe_to_delete_whmv_ml_item
--
-- Description:
--    This procedure will determine if it is save to delete a record from
--    table WHMV_MINILOAD_ITEM.  If there is inventory in the miniloader in
--    the new warehouse then the record cannot be deleted.  The OpCo needs
--    to get the inventory out of the miniloader then the record can be
--    deleted.
--
--    Table WHMV_MINILOAD_ITEM is used to store the items moving to the
--    miniloader during a warehouse move.  Items can be inserted and deleted
--    during the pre-move period.  At the time of the move items in this table
--    will be directed to the miniload induction location.
--    
-- Parameters:
--    i_prod_id           - The item to delete.
--    i_cust_pref_vendor  - The CPV to delete.
--    o_safe_to_delete_item_bln - OK or not OK to delete the record.
--              Values:
--                 TRUE  - The record can be deletd.
--                 FALSE - The record cannot be deleted.
--
--    o_message            - Message stating why the record cannot be
--                           deleted.  If o_safe_to_delete_item_bln is TRUE
--                           then this will be set to null.
--
-- Called by:
--      Form mw1sd.fmb
--      Database trigger trg_insupddel_whmv_mlitem_arow
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/09/09 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE safe_to_delete_whmv_ml_item
          (i_prod_id             IN  whmv_miniload_item.prod_id%TYPE,
           i_cust_pref_vendor    IN  whmv_miniload_item.cust_pref_vendor%TYPE,
           o_safe_to_delete_bln  OUT BOOLEAN,
           o_message             OUT VARCHAR2)
IS
   l_object_name  VARCHAR2(30);   -- Procedure name.  Used in error messages.

   l_qty          PLS_INTEGER;    -- Qty of the item in the miniloader in
                                  -- the new warehouse.
BEGIN
   --
   -- Initialization
   --
   o_safe_to_delete_bln := TRUE;
   o_message            := NULL;

   --
   -- If there is inventory in the minloader in the new warehouse then
   -- the record cannot be deleted.  The OpCo needs to get the inventory
   -- out of the miniloader then the record can be deleted.
   --
   IF (has_inventory_in_ml(i_prod_id, i_cust_pref_vendor) = TRUE) THEN
      o_safe_to_delete_bln := FALSE;
      o_message := 'Item ' || i_prod_id
            || ' has inventory in the new warehouse miniloader.'
            || '  Remove the miniloader inventory before deleting the item.';
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := 'safe_to_delete_whmv_ml_item';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, 'Error',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END safe_to_delete_whmv_ml_item;


----------------------------------------------------------------------------
-- Procedure:
--    slot_items_to_ml
--                                                                              
-- Description:                    
--    This script slots the items in table WHMV_MINILOAD_ITEM to the
--    miniloader.  It does this by updating the pm.zone_id and
--    pm.split_zone_id.  It does not send a NEW SKU message to the
--    miniloader.  A separate script needs to do this.
--
--    Used in a warehouse move where the new warehouse has
--    a miniloader and items are moving into it.
--
--    ********************************************
--    ********************************************
--    Run this at the start of the move weekend.
--    ********************************************
--    ********************************************
--
-- Parameters:
--   None
--    
-- Called by:
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:                                                        
--    Date      Designer Comments                                               
--    -------- -------- ----------------------------------------------------
--    11/09/09 prpbcb   Created from a script used during the Chicage move.
----------------------------------------------------------------------------
PROCEDURE slot_items_to_ml
IS
   l_rec_count  PLS_INTEGER;
BEGIN
   UPDATE swms.pm
      SET (pm.zone_id, pm.split_zone_id) =
            (SELECT z.zone_id, DECODE(pm.split_trk, 'Y', z.zone_id, NULL)
               FROM swms.zone z,
                    v_whmove_newloc v_newloc,
                    whmv_miniload_item mli
              WHERE mli.prod_id          = pm.prod_id
                AND mli.cust_pref_vendor = pm.cust_pref_vendor
                AND z.induction_loc      = v_newloc.tmp_logi_loc
                AND v_newloc.logi_loc    = mli.induction_loc
                AND z.rule_id            = 3)   -- Sanity check
    WHERE EXISTS
            (SELECT 'x'
               FROM swms.zone z2,
                    v_whmove_newloc v_newloc,
                    whmv_miniload_item mli2
              WHERE mli2.prod_id          = pm.prod_id
                AND mli2.cust_pref_vendor = pm.cust_pref_vendor
                AND z2.induction_loc      = v_newloc.tmp_logi_loc
                AND v_newloc.logi_loc     = mli2.induction_loc
                AND z2.rule_id            = 3);   -- Sanity check

   l_rec_count := SQL%ROWCOUNT;


   DBMS_OUTPUT.PUT_LINE('WH move slot item to ML.'
                 || '  Number of PM records updated: ' || l_rec_count);
END slot_items_to_ml;


---------------------------------------------------------------------------
-- Function:
--    is_new_warehouse_user
--
-- Description:
--    This procedure returns TRUE if the user is a new warehouse user
--     otherwise FALSE is returned. 
--
-- Parameters:
--    i_user_id    - User to check.
--
-- Return Values:
--    TRUE  - The user is a new warehouse user.
--    FALSE - The user is not new warehouse user.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    -  Trigger trg_insupd_swms_trans
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/10/09 prpbcb   Created
--    07/26/11 prpbcb   Changed to be a pass through calling the
--                      corresponding function in pl_wh_move_utilities.sql
---------------------------------------------------------------------------
FUNCTION is_new_warehouse_user(i_user_id  IN usr.user_id%TYPE)
RETURN BOOLEAN
IS
   l_object_name   VARCHAR2(61);
   l_message       VARCHAR2(256);    -- Message buffer

   l_return_value  BOOLEAN;
BEGIN
   l_return_value := pl_wh_move_utilities.is_new_warehouse_user(i_user_id);

   RETURN(l_return_value);
   
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := 'is_new_warehouse_user';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                 'ERROR: Failed to determine if new warehouse user.',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END is_new_warehouse_user;


---------------------------------------------------------------------------
-- Function:
--    is_new_warehouse_loc
--
-- Description:
--    This function returns TRUE if the location in the SWMS schema is
--    a new warehouse user otherwise FALSE is returned. 
--
-- *******************************************************************
-- *******************************************************************
-- Only use this function during the pre-receiving period.
-- The location needs to be the location as stored in the SWMS schema.
-- *******************************************************************
-- *******************************************************************
--
-- Parameters:
--    i_loc    - The location to check.  It needs to be from the
--               location as stored in the SWMS schema.
--
-- Return Values:
--    TRUE  - The location is a new warehouse user.
--    FALSE - The location is not a new warehouse user.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    -  Trigger trg_insupd_swms_trans
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/10/09 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION is_new_warehouse_loc(i_loc  IN loc.logi_loc%TYPE)
RETURN BOOLEAN
IS
   l_object_name   VARCHAR2(30);     -- Function name, used in error messages.
   l_message       VARCHAR2(256);    -- Message buffer

   l_dummy         VARCHAR2(1);      -- Work area
   l_return_value  BOOLEAN;

   --
   -- This cursor will check if the location is in the new warehouse.
   --
   CURSOR c_where_is_loc(cp_loc  loc.logi_loc%TYPE) IS
      SELECT 'x'
        FROM whmveloc_area_xref
       WHERE tmp_new_wh_area = SUBSTR(cp_loc, 1, 1);

BEGIN
   OPEN c_where_is_loc(i_loc);
   FETCH c_where_is_loc INTO l_dummy;
   IF (c_where_is_loc%FOUND) THEN
      l_return_value := TRUE;
   ELSE
      l_return_value := FALSE;
   END IF;

   CLOSE c_where_is_loc;

   RETURN(l_return_value);
   
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := 'is_new_warehouse_loc';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
           'ERROR: Failed to determine if location is in the new warehouse.',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END is_new_warehouse_loc;

--xxxxxxxxxxxxx
--xxxxxxxxxxxxx

---------------------------------------------------------------------------
-- Procedure:
--    send_planned_orders
--
-- Description:
--
--    This procedure sends the planned orders to the miniloader for the
--    specified criteria.  The planned orders are in tables
--    PLANNED_ORDER_HDR and PLANNED_ORDER_DTL.
--
--    The planned orders can be sent for:
--       - An item for a specified date
--       - An item.
--       - An order.
--       - All orders for a specified date.
--
--    This procedure is local to this package and is intended to be
--    called by the public procedures.
--
--    If a procedure call returns a failure status then a log message is
--    written and processing will stop.  The failure status will be
--    returned in o_status.  It will be possible for partial orders to
--    be sent to the miniloader depending when the failure occurs.  This
--    will not cause any problems as the miniloader will reject the order
--    since it will not be complete.
--
-- Parameters:
--    i_send_for_what     - What to send.
--    i_prod_id           - The item to send the order for.
--    i_cust_pref_vendor  - The CPV to send the order for.
--    i_order_id          - The order to send.
--    i_order_date        - Send orders with this date.
--    o_status            - If 0 then no error occurred otherwise
--                          an error occured.
--
-- Called by:
--    - send_orders_for_item
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/15/09 prpbcb   Created.
--                      It is intended to be called when an item is slotted
--                      to the miniloader to send the orders that came down
--                      in the ML queue before the item was slotted.
--
--                      Ideally it should be in pl_planned_order.sql.
--                      It was added to pl_wh_move at this time because it
--                      is needed for the Houston warehouse move and it is
--                      easier to install pl_wh_move at Houston.
--                      Later I will add it to pl_planned_order.sql.
---------------------------------------------------------------------------
PROCEDURE send_planned_orders
            (i_send_for_what    IN  VARCHAR2,
             i_prod_id          IN  planned_order_dtl.prod_id%TYPE,
             i_cust_pref_vendor IN  planned_order_dtl.cust_pref_vendor%TYPE,
             i_order_id         IN  planned_order_hdr.order_id%TYPE,
             i_order_date       IN  DATE,
             o_status           OUT NUMBER)
IS
   l_message             VARCHAR2(512);  -- Message buffer.
   l_object_name         VARCHAR2(30);   -- Procedure name.  Used in messages.

   l_first_record_bln    BOOLEAN;  -- To know when processing the 1st record.
   l_last_order_id       planned_order_hdr.order_id%TYPE; -- Last order
                            -- processed.  Needed to create the trailer record
                            -- for the last order processed.

   l_order_record_count  PLS_INTEGER;  -- Order detail record count.  This
                                       -- goes in the Order trailer record.

   l_previous_order_id   planned_order_hdr.order_id%TYPE;  -- To know when
                                        -- we switch orders.

   -- Miniload order header record.
   l_r_ord_hdr_info  pl_miniload_processing.t_new_ship_ord_hdr_info := NULL;

   -- Miniload order detail record.
   l_r_ord_dtl_info  pl_miniload_processing.t_new_ship_ord_item_inv_info :=NULL;

   -- Miniload order trailer record.
   l_r_ord_tr_info   pl_miniload_processing.t_new_ship_ord_trail_info := NULL;

   e_bad_parameter        EXCEPTION;  -- Invalid parameter.
   e_processing_error     EXCEPTION;

   --
   -- This cursor selects the planned orders to send to the miniloader.
   -- Historical orders will not be sent.
   -- The planned orders can be sent for:
   --    - An item for a specified date
   --    - An item.
   --    - An order.
   --    - All orders for a specified date.
   --
   -- Brian Bent  The where clause uses BETWEEN for the order date to use
   -- the index on the order date, if it exists.   We also will not have to
   -- worry about the order date being stored with or without the time
   -- component.
   --
   CURSOR c_planned_order(cp_send_for_what     VARCHAR2,
                          cp_prod_id           VARCHAR2,
                          cp_cust_pref_vendor  VARCHAR2,
                          cp_order_id          VARCHAR2,
                          cp_order_date        DATE) IS
      SELECT h.order_id              order_id,
             h.description           description,
             h.order_priority        order_priority,
             h.order_type            order_type,
             TRUNC(h.order_date)     order_date,
             d.order_item_id         order_item_id,
             d.uom                   uom,
             d.prod_id               prod_id,
             d.cust_pref_vendor      cust_pref_vendor,
             d.qty                   qty,
             NVL(d.sku_priority, 0)  sku_priority
        FROM planned_order_dtl d,
             planned_order_hdr h
       WHERE d.order_id = h.order_id
         AND h.order_id NOT LIKE 'HIST%'   -- Leave out historical orders
         AND (
                  --
                  -- Send planned orders for a specified item on a specifed
                  -- date.
                  --
                 (cp_send_for_what   = 'ITEM_AND_DATE' AND
                  d.prod_id          LIKE cp_prod_id AND
                  d.cust_pref_vendor LIKE cp_cust_pref_vendor AND
                  h.order_date       BETWEEN TRUNC(cp_order_date)
                                         AND (TRUNC(cp_order_date) + 1) -
                                                     (1 / (24 * 60 * 60)))
                  --
                  -- Send planned orders for a specified item.
                  --
              OR (cp_send_for_what   = 'ITEM' AND
                  d.prod_id          LIKE cp_prod_id AND
                  d.cust_pref_vendor LIKE cp_cust_pref_vendor)
                  --
                  -- Send planned order for a specified order.
                  --
              OR (cp_send_for_what = 'ORDER' AND
                  h.order_id       LIKE cp_order_id)
                  --
                  -- Send planned orders for a specified date.
                  --
              OR (cp_send_for_what = 'DATE' AND
                  h.order_date     BETWEEN TRUNC(cp_order_date)
                                       AND (TRUNC(cp_order_date) + 1) -
                                                     (1 / (24 * 60 * 60)))
             )
         ORDER BY h.order_id, d.order_item_id;  -- The ordering is important

BEGIN
   --
   -- Check for invalid or null parameters.
   --
   IF (i_send_for_what = 'ITEM_AND_DATE') THEN
      --
      -- Sending planned orders for an item for a specified date.
      -- i_prod_id, i_cust_pref_vendor and i_order_date all need to
      -- have a value.
      --
      IF (i_prod_id          IS NULL OR
          i_cust_pref_vendor IS NULL OR
          i_order_date       IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSIF (i_send_for_what = 'ITEM') THEN
      --
      -- Sending planned orders for an item for a specified date.
      -- i_prod_id, i_cust_pref_vendor and i_order_date all need to
      -- have a value.
      --
      IF (i_prod_id          IS NULL OR
          i_cust_pref_vendor IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSIF (i_send_for_what = 'ORDER') THEN
      --
      -- Sending planned orders for an order.
      -- i_order_id needs to have a value.
      --
      IF (i_order_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSIF (i_send_for_what = 'DATE') THEN
      --
      -- Sending planned orders for a date.
      -- i_order_date needs to have a value.
      --
      IF (i_order_date IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
   ELSE
      --
      -- i_send_for_what has an unhandled value.
      --
      RAISE e_bad_parameter;
   END IF;

   --
   -- Send the planned order(s) to the miniloader.
   --

   o_status := pl_miniload_processing.ct_success;
   l_first_record_bln := TRUE;

   FOR r_planned_order IN c_planned_order
                                (i_send_for_what,
                                 i_prod_id,
                                 i_cust_pref_vendor,
                                 i_order_id,
                                 i_order_date) LOOP

      --
      -- Debug stuff
      -- DBMS_OUTPUT.PUT_LINE('Order ID: '
      --    || RPAD(r_planned_order.order_id, 14)
      --    || '  Order Item ID: ' || RPAD(r_planned_order.order_item_id,  10)
      --    || '  Prod ID: ' || r_planned_order.prod_id
      --    || '  Order Date: '
      --    || TO_CHAR(r_planned_order.order_date, 'MM/DD/YYYY'));
      --

      l_last_order_id := r_planned_order.order_id;

      IF (l_first_record_bln = TRUE) THEN
         --
         -- First record processed.  Perform initialization.
         --
         l_previous_order_id  := r_planned_order.order_id;
         l_order_record_count := 1;
         l_first_record_bln   := FALSE;
      ELSIF (l_previous_order_id <> r_planned_order.order_id) THEN
         --
         -- Order changed.  Send the order trailer for the previous order.
         --
         l_r_ord_tr_info.v_msg_type  := pl_miniload_processing.ct_ship_ord_trl;
         l_r_ord_tr_info.v_order_id            := l_previous_order_id;
         l_r_ord_tr_info.n_order_item_id_count := l_order_record_count;

         pl_miniload_processing.p_send_new_ship_ord_trail(l_r_ord_tr_info,
                                                          o_status);

         IF (o_status <> pl_miniload_processing.ct_success) THEN
            RAISE e_processing_error;
         END IF;

         --
         -- Initialization for current order.
         --
         l_order_record_count := 1;
         l_previous_order_id  := r_planned_order.order_id;
      ELSE
         --
         -- Record being processed is for the same order as the
         -- previous record.
         --
         l_order_record_count := l_order_record_count + 1;
      END IF;

      --
      -- Send the order header if processing the first record for the order.
      --
      IF (l_order_record_count = 1) THEN
         l_r_ord_hdr_info.v_msg_type := pl_miniload_processing.ct_ship_ord_hdr;
         l_r_ord_hdr_info.v_order_id       := r_planned_order.order_id;
         l_r_ord_hdr_info.v_description    := r_planned_order.description;
         l_r_ord_hdr_info.n_order_priority := r_planned_order.order_priority;
         l_r_ord_hdr_info.v_order_type     := r_planned_order.order_type;
         l_r_ord_hdr_info.v_order_date     := TRUNC(r_planned_order.order_date);
 
         pl_miniload_processing.p_send_new_ship_ord_hdr
                                    (l_r_ord_hdr_info, o_status);

         IF (o_status <> pl_miniload_processing.ct_success) THEN
            RAISE e_processing_error;
         END IF;
      END IF;

      --
      -- Send the order detail.
      --
      l_r_ord_dtl_info.v_msg_type := pl_miniload_processing.ct_ship_ord_inv;
      l_r_ord_dtl_info.v_order_id         := r_planned_order.order_id;
      l_r_ord_dtl_info.v_order_item_id    := r_planned_order.order_item_id;
      l_r_ord_dtl_info.n_uom              := r_planned_order.uom;
      l_r_ord_dtl_info.v_prod_id          := r_planned_order.prod_id;
      l_r_ord_dtl_info.v_cust_pref_vendor := r_planned_order.cust_pref_vendor;
      l_r_ord_dtl_info.n_qty              := r_planned_order.qty;
      l_r_ord_dtl_info.n_sku_priority     := r_planned_order.sku_priority;

      pl_miniload_processing.p_send_new_ship_ord_item_inv(l_r_ord_dtl_info,
                                                          o_status);

      IF (o_status <> pl_miniload_processing.ct_success) THEN
         RAISE e_processing_error;
      END IF;

   END LOOP;

   IF (l_order_record_count >= 1) THEN
      --
      -- Send the order trailer for the last order.
      --
      l_r_ord_tr_info.v_msg_type := pl_miniload_processing.ct_ship_ord_trl;
      l_r_ord_tr_info.v_order_id            := l_last_order_id;
      l_r_ord_tr_info.n_order_item_id_count := l_order_record_count;
             
      pl_miniload_processing.p_send_new_ship_ord_trail(l_r_ord_tr_info,
                                                       o_status);

      IF (o_status <> pl_miniload_processing.ct_success) THEN
         RAISE e_processing_error;
      END IF;
   END IF;

EXCEPTION
   WHEN gl_e_parameter_null THEN
      l_object_name := 'send_planned_orders';

      l_message := 'x'
                   || '  A required parameter is null.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN e_bad_parameter THEN
      l_object_name := 'send_planned_orders';

      l_message :=  'i_send_for_what'
            || '[' || i_send_for_what || ']'
            || ' has an unhandled value.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_message := 'i_send_for_what[ ' || i_send_for_what || ']';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END send_planned_orders;


---------------------------------------------------------------------------
-- Procedure:
--    send_planned_orders_for_item
--
-- Description:
--
--    This procedure sends the planned orders to the miniloaders for a
--    specified item for a specified date.
--
-- Parameters:
--    i_prod_id           - The item to send the order for.
--    i_cust_pref_vendor  - The CPV to send the order for.
--    i_order_date        - Send orders with this date.
--    o_status            - Status of call to procedure send_planned_orders().
--
-- Called by:
--      Database trigger on WHMOVE.PM table.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/15/09 prpbcb   Created.
--                      It is intended to be called when an item is slotted
--                      to the miniloader.
---------------------------------------------------------------------------
PROCEDURE send_planned_orders_for_item
            (i_prod_id          IN planned_order_dtl.prod_id%TYPE,
             i_cust_pref_vendor IN planned_order_dtl.cust_pref_vendor%TYPE,
             i_order_date       IN DATE,
             o_status           IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(512);  -- Message buffer.
   l_object_name   VARCHAR2(30) :='send_planned_orders_for_item'; -- Procedure
                                             -- name.  Used in messages.
BEGIN
   --
   -- send_planned_orders will validate the parameters so it is not done
   -- here.
   --
   send_planned_orders
            (i_send_for_what    => 'ITEM_AND_DATE',
             i_prod_id          => i_prod_id,
             i_cust_pref_vendor => i_cust_pref_vendor,
             i_order_id         => NULL,
             i_order_date       => i_order_date,
             o_status           => o_status);

   --
   -- If send_planned_orders had an error then write a log message.
   --
   IF (o_status <> pl_miniload_processing.ct_success) THEN
      l_message := 'ERROR  i_prod_id[ ' || i_prod_id || ']'
            || 'i_cust_pref_vendor[ ' || i_cust_pref_vendor || ']'
            || 'i_order_date[ '
            || TO_CHAR(i_order_date, 'MM/DD/YYYY HH24:MI:SS') || ']'
            || '  send_planned_orders returned an error status of '
            || TO_CHAR(o_status);  

      pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_message := 'ERROR  i_prod_id[ ' || i_prod_id || ']'
            || 'i_cust_pref_vendor[ ' || i_cust_pref_vendor || ']'
            || 'i_order_date[ '
            || TO_CHAR(i_order_date, 'MM/DD/YYYY HH24:MI:SS') || ']';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END send_planned_orders_for_item;


---------------------------------------------------------------------------
-- Function:
--    get_new_whse_staging_location
--
-- Description:
--    This function returns the location in the new warehouse to stage
--    the pallet by when moving reserve pallets from the old warehouse
--    during the move process for an item with a home slot in the new
--    warehouse.
--
--    The staging location will either be the new warehouse home slot
--    (i_new_whse_home_slot) or will be the back location of the new
--    warehouse home slot.
--
--    ******************************************************************
--    The tables in the SWMS schema are used.  No tables in the WHMOVE
--    schema.  This is by design and needs to be this way.  If there is
--    no pre-receving into the new warehouse there will be no data in 
--    WHMOVE schema.
--    ******************************************************************
--
-- Parameters:
--    i_new_whse_home_slot  - The home slot in the new warehouse.
--                            This needs to be the actual home slot and
--                            not with the temp area.
--                            It needs to exist in table
--                            SWMS.WHMVELOC_HIST as a newloc.
--
-- Return Values:
--    The staging location for the new warehouse home slot.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - rp1reoracle.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/23/11 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION get_new_whse_staging_location(i_new_whse_home_slot IN VARCHAR2)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(512);  -- Message buffer.
   l_object_name   VARCHAR2(30);   -- Function name.  Used in messages.

   l_staging_location  loc.logi_loc%TYPE;

   --
   -- This cursor determines the staging location for the new warehouse move slot.
   -- The order by in this cursor is important.
   --
   CURSOR c_staging_location(cp_new_whse_home_slot  VARCHAR2) IS
      SELECT '1'                    order_by_this,
             'show front'           info_descrip,    -- not used by anything
             cp_new_whse_home_slot  staging_location
        FROM DUAL
       WHERE EXISTS
             (SELECT 'x'
                FROM swms.whmveloc_hist lhist,
                     swms.loc_reference lr,
                     swms.zone z,
                     swms.lzone lz,
                     swms.loc loc,
                     --
                     -- These table are for getting info about the
                     -- reserve flow slot.
                     swms.loc_reference res_lr,
                     swms.lzone res_lz,
                     swms.loc   res_loc,
                     (SELECT tmp_new_wh_area || SUBSTR(cp_new_whse_home_slot, 2) tmp_new_home_slot
                        FROM swms.whmveloc_area_xref xref
                       WHERE xref.putback_wh_area = SUBSTR(cp_new_whse_home_slot, 1, 1)) t_area
               WHERE lr.plogi_loc = tmp_new_home_slot
                 AND lz.logi_loc  = tmp_new_home_slot
                 AND loc.logi_loc = lz.logi_loc
                 AND z.zone_id    = lz.zone_id
                 AND z.zone_type  = 'PUT'
                 AND lhist.newloc = cp_new_whse_home_slot
                 --
                 -- Joins for the reserve flow slots.
                 AND res_lz.zone_id      = lz.zone_id -- Reserve slot PUT zone needs to match the home slot.
                 AND res_lr.bck_logi_loc = res_loc.logi_loc
                 AND res_lz.logi_loc     = res_loc.logi_loc
                 AND res_loc.perm        = 'N'
                 AND res_loc.slot_type   = loc.slot_type   -- Reserve slot slot type needs to match the home slot.
                 AND res_loc.logi_loc LIKE SUBSTR(tmp_new_home_slot, 1, 2) || '%')
    UNION
    SELECT '2'           order_by_this,
           'show back'   info_descrip,    -- not used by anything
           xref_back.putback_wh_area || SUBSTR(lr.bck_logi_loc, 2) staging_location
      FROM swms.whmveloc_hist lhist,
           swms.loc_reference lr,
           swms.whmveloc_area_xref xref_back,
           swms.loc loc,
           (SELECT tmp_new_wh_area || SUBSTR(cp_new_whse_home_slot, 2) tmp_new_home_slot
              FROM swms.whmveloc_area_xref xref
             WHERE xref.putback_wh_area = SUBSTR(cp_new_whse_home_slot, 1, 1)) t_area
     WHERE lr.plogi_loc              = tmp_new_home_slot
       AND xref_back.tmp_new_wh_area = SUBSTR(lr.bck_logi_loc, 1, 1)
       AND lhist.newloc              = cp_new_whse_home_slot
    UNION
    SELECT '3'            order_by_this,
           'show front'   info_descrip,    -- not used by anything,
           cp_new_whse_home_slot staging_location
      FROM swms.whmveloc_hist lhist
     WHERE lhist.newloc = cp_new_whse_home_slot
    ORDER BY 1;

   l_r_staging_location c_staging_location%ROWTYPE;
BEGIN
   OPEN c_staging_location(i_new_whse_home_slot);
   FETCH c_staging_location INTO l_r_staging_location;

   IF (c_staging_location%FOUND) THEN
      l_staging_location := l_r_staging_location.staging_location;
   ELSE
      l_staging_location := NULL;
   END IF;

   CLOSE c_staging_location;

   RETURN(l_staging_location);

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := 'get_new_whse_staging_location';
      l_message := l_object_name
           || ' i_new_whse_home_slot[' || i_new_whse_home_slot || ']'
           || '  Failed to determine the staging location in the new warehouse.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END get_new_whse_staging_location;


---------------------------------------------------------------------------
-- Function:
--    get_new_whse_staging_aisle
--
-- Description:
--    This function returns the aisle in the new warehouse to stage
--    the pallet by when moving reserve pallets from the old warehouse
--    during the move process. 
--
--    The staging aisle will either be the aisle of new warehouse home slot
--    or will be the aisle of the back location of the new
--    warehouse home slot.
--
--    Function get_new_whse_staging_location() is called which returns
--    the staging location.  A substr is make on this to return the aisle.
--
-- Parameters:
--    i_new_whse_home_slot  - The home slot in the new warehouse.
--                            This needs to be the actual home slot and
--                            not with the temp area.
--
-- Return Values:
--    The staging aisle for the new warehouse home slot.
--    If i_new_whse_home_slot is not a perm slot or is not a valid
--    location then NULL is returned. 
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - rp1reoracle.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/27/11 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION get_new_whse_staging_aisle(i_new_whse_home_slot IN VARCHAR2)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(512);  -- Message buffer.
   l_object_name   VARCHAR2(30);   -- Function name.  Used in messages.
BEGIN
   RETURN(SUBSTR(get_new_whse_staging_location(i_new_whse_home_slot), 1, 2));
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_object_name := 'get_new_whse_staging_aisle';
      l_message := l_object_name
           || ' i_new_whse_home_slot[' || i_new_whse_home_slot || ']'
           || '  Failed to determine the staging aisle in the new warehouse.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END get_new_whse_staging_aisle;

END pl_wh_move;
/

show errors

