CREATE OR REPLACE PACKAGE swms.pl_op_pick_zone
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_op_pick_zone   
--
-- Description:
--    Package for operations related to the ORDD.ZONE_ID.
--    Specifically updating ORDD.ZONE_ID.
--
--    Procedure "update_ordd_zone_id" is called at the start of order generation
--    to update ordd.zone_id.  'X' cross dock orders are not updated as tne ordd.zone_id
--    is assigned when the orders/floats merged at Site 2.
--    
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    03/29/15 bben0556 Created.
--                      Symbotic project.
--          R30.0 Symbotic/Matrix_Project-Assign_ordd_zone_id
--
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Do not update ordd.zone_id for 'X' cross dock type. 
--                      ordd.zone_id is assigned when the orders merged
--                      at Site 2.
--                      Modified cursor "c_ordd" in procedure "update_ordd_zone_id"
--                      to exclude 'X' cross dock type.
--                     
--
-----------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


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
--    matrix_pick_zone
--
-- Description:
--    This function returns the matrix pick zone for an item.  This is
--    based on the item's food type and the setup in the MX_FOOD_TYPE
--    table.
--
--    Keep in mind it does not check if PM.MX_ITEM_ASSIGN_FLAG is Y
--    so the calling program will need to check the mx_item_assign_flag
--    if it is desired to call this function only for a matrix item.
---------------------------------------------------------------------------
FUNCTION get_matrix_pick_zone
            (i_prod_id           IN  pm.prod_id%TYPE,
             i_cust_pref_vendor  IN  pm.cust_pref_vendor%TYPE)
RETURN zone.zone_id%TYPE;


---------------------------------------------------------------------------
-- Function:
--    get_item_pick_zone_for_order
--
-- Description:
--    This function determines the item pick zone for order processing.
--    The main use is to populate ORDD.ZONE_ID.
-- 
--    How the pick zone is determined.  In this order:
--    (1) If a matrix item then the matrix pick zone 
--    (2) Rank 1 case home slot pick zone
--    (3) Oldest AVL, HLD, CDK inventory record pick zone
--    (4) Item's last ship slot
--    (5) Default pick zone from SWMS_AREAS using the item's area.
--    (6) If the pick zone is null or invalid then the pick zone is set to
--        a random pick zone that has inventory and is in the item's area.
--        If the item area is blank then a random pick zone is used.
--        We want to have something for the pick zone.
--        Even if the pick zone is not correct it will still go
--        through order processing OK.  This pick zone is used in
--        building the floats so we could end up with the item on
--        a float is normally would not be on such as a cooler item
--        on a dry float.
---------------------------------------------------------------------------
FUNCTION get_item_pick_zone_for_order
            (i_prod_id           IN  pm.prod_id%TYPE,
             i_cust_pref_vendor  IN  pm.cust_pref_vendor%TYPE,
             i_uom               IN  ordd.uom%TYPE,
             i_order_id          IN  ordd.order_id%TYPE          DEFAULT NULL,
             i_order_line_id     IN  ordd.order_line_id%TYPE     DEFAULT NULL)
RETURN zone.zone_id%TYPE;


---------------------------------------------------------------------------
-- Procedure:
--    update_ordd_zone_id
--
-- Description:
--    This procedure updates ORDD.ZONE_ID with the pick zone to pick from.
--
--
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    CRT_order_proc.pc
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/29/15 bben0556 Created.   
---------------------------------------------------------------------------
PROCEDURE update_ordd_zone_id
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL);


---------------------------------------------------------------------------
-- Function:
--
-- Description:
---------------------------------------------------------------------------
FUNCTION xxx
RETURN VARCHAR2;

PROCEDURE update_unitize_ind
  (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL);

END pl_op_pick_zone;
/


SHOW ERRORS


CREATE OR REPLACE PACKAGE BODY swms.pl_op_pick_zone
AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;  -- Package name.
                                             -- Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function VARCHAR2(30) := 'ORDER GENERATION';


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
--    xxxxx
--
-- Description:
--    
-- Parameters:
--    None
--
-- Return Values:
--    xxx
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--   
---------------------------------------------------------------------------
FUNCTION xxx
RETURN varchar2
IS
   l_object_name VARCHAR2(30) := 'xxx';
BEGIN
   null;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, 'Error',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END xxx;


---------------------------------------------------------------------------
-- Function:
--    matrix_pick_zone
--
-- Description:
--    This function returns the matrix pick zone for an item.  This is
--    based on the item's food type and the setup in the MX_FOOD_TYPE
--    table.
--
--    Keep in mind it does not check if PM.MX_ITEM_ASSIGN_FLAG is Y
--    so the calling program will need to check the mx_item_assign_flag
--    if it is desired to call this function only for a matrix item.
--
--
--  How the pick zone is determined using the PM.MX_FOOD_TYPE and MX_FOOD TYPE.
--  +--------------+   +--------------+   +-----------+   +----------+     +------------+
--  |     PM       |   | MX_FOOD_TYPE |   |    LOC    |   |  LZONE   |     |   ZONE     |
--  +--------------+   +--------------+   +-----------+   +----------+     +------------+
--  | MX_FOOD_TYPE |---| MX_FOOD_TYPE |   | LOGI_LOC  |---| LOGI_LOC |  +--| ZONE_ID    |
--  |              |   | SLOT_TYPE    |---| SLOT_TYPE |   | ZONE_ID  | -+  | 'PIK' zone |
--  |              |   |              |   |           |   |          |     |       type |
--  +--------------+   +--------------+   +-----------+   +----------+     +------------+
--
--
-- Parameters:
--    i_prod_id          - The route batch number to process.
--    i_cust_pref_vendor - The route number to process.
--
-- Called by:
--    get_item_pick_zone_for_order
--
-- Exceptions raised:
--    None.  An error is logged and null is returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/04/14 bben0556 Created.
---------------------------------------------------------------------------
FUNCTION get_matrix_pick_zone
            (i_prod_id           IN  pm.prod_id%TYPE,
             i_cust_pref_vendor  IN  pm.cust_pref_vendor%TYPE)
RETURN zone.zone_id%TYPE
IS
   l_message       VARCHAR2(256);
   l_object_name   VARCHAR2(30)   := 'get_matrix_pick_zone';

   l_matrix_pick_zone   zone.zone_id%TYPE;   -- Return value
BEGIN
   --
   -- Check the parameters.
   -- i_prod_id and i_cust_pref_vendor need values.
   --
   IF (i_prod_id IS NULL OR i_cust_pref_vendor IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   BEGIN  -- new block to trap no data found
      SELECT z.zone_id      
        INTO l_matrix_pick_zone
        FROM mx_food_type ft,
             loc,
             lzone lz,
             zone z,
             pm
       WHERE loc.slot_type       = ft.slot_type
         AND loc.logi_loc        = lz.logi_loc
         AND lz.zone_id          = z.zone_id
         AND z.zone_type         = 'PIK'
         AND pm.mx_food_type     = ft.mx_food_type
         AND pm.prod_id          = i_prod_id
         AND pm.cust_pref_vendor = i_cust_pref_vendor;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_matrix_pick_zone := NULL;
   END;

   RETURN(l_matrix_pick_zone);

EXCEPTION
   WHEN gl_e_parameter_null THEN
      --
      -- A parameter is null.
      -- i_prod_id and i_cust_pref_vendor need values.
      --
      l_message := '(i_prod_id['            || i_prod_id          || '],'
                   || 'i_cust_pref_vendor[' || i_cust_pref_vendor || '])'
                   || '  All parameters need a value.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      -- AAA_ALERT  Need alert call here

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                    '(i_prod_id['            || i_prod_id          || '],'
                    || 'i_cust_pref_vendor[' || i_cust_pref_vendor || '])',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      -- AAA_ALERT  Need alert call here

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END get_matrix_pick_zone;


---------------------------------------------------------------------------
-- Function:
--    get_item_pick_zone_for_order
--
-- Description:
--    This function determines the item pick zone for order processing.
--    The main use is to populate ORDD.ZONE_ID.
-- 
--    How the pick zone is determined.  In this order:
--    (1) If a matrix item then the matrix pick zone 
--    (2) Rank 1 case home slot pick zone
--    (3) Oldest AVL, HLD, CDK inventory record pick zone
--    (4) Item's last ship slot
--    (5) Default pick zone from SWMS_AREAS using the item's area.
--    (6) If the pick zone is null or invalid then the pick zone is set to
--        a random pick zone that has inventory and is in the item's area.
--        If the item area is blank then a random pick zone is used.
--        We want to have something for the pick zone.
--        Even if the pick zone is not correct it will still go
--        through order processing OK.  This pick zone is used in
--        building the floats so we could end up with the item on
--        a float is normally would not be on such as a cooler item
--        on a dry float.
--
-- Parameters:
--    i_prod_id          - The route batch number to process.
--    i_cust_pref_vendor - The route number to process.
--    i_uom              - Order uom. 1 - splits ordered, anything else cases
--    i_order_id         - Order id being processed.  Optional but should be
--                         specified.  Used in log messages.
--    i_order_line_id    - Order line id being processed.  Optional but should be 
--                         specified.  Used in log messages.
--
-- Called by:
--    swmsorreader.pc
--    pl_order_processing.sql
--
-- Exceptions raised:
--    None.  An error is logged and a default pick zone is returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/14 bben0556 Created.
---------------------------------------------------------------------------
FUNCTION get_item_pick_zone_for_order
            (i_prod_id           IN  pm.prod_id%TYPE,
             i_cust_pref_vendor  IN  pm.cust_pref_vendor%TYPE,
             i_uom               IN  ordd.uom%TYPE,
             i_order_id          IN  ordd.order_id%TYPE          DEFAULT NULL,
             i_order_line_id     IN  ordd.order_line_id%TYPE     DEFAULT NULL)
RETURN zone.zone_id%TYPE
IS
   l_object_name   VARCHAR2(30)   := 'get_item_pick_zone_for_order';
   l_message       VARCHAR2(1024);

   l_cursor_found         BOOLEAN;  -- for storing cursor%FOUND so the cursor
                                    -- can be immediately closed.
   l_pick_zone_for_ordd   zone.zone_id%TYPE := NULL;  -- Return value

   l_e_item_not_found  EXCEPTION;  -- Item, cpv not found in PM. 

   --
   -- This cursor selects info about the item which includes the
   -- rank 1 case home.
   -- 
   -- 12/12/2014  Brian Bent  It is probably possible to include other info
   -- such as the last ship slot pick zone using additional inline views but
   -- I elected to use additional cursors instead since having to use the last
   -- ship slot to get the pick zone should happen very rarely and we save
   -- the additional processing of inline views that would be rarely needed.
   --
   --
   CURSOR c_item_info(cp_prod_id           pm.prod_id%TYPE,
                      cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE)
   IS
   SELECT pm.prod_id,
          pm.cust_pref_vendor,
          pm.area,
          pm.split_trk,
          pm.auto_ship_flag,
          pm.last_ship_slot,
          pm.zone_id,
          pm.mx_item_assign_flag,
          pm.mx_eligible,
          pm.mx_food_type,
          --
          rank_one_case_home.case_home_slot,
          rank_one_case_home.case_home_slot_perm,
          rank_one_case_home.case_home_slot_rank,
          rank_one_case_home.case_home_slot_uom,
          rank_one_case_home.case_home_slot_pick_zone,
          --
          rank_one_split_home.split_home_slot,
          rank_one_split_home.split_home_slot_perm,
          rank_one_split_home.split_home_slot_rank,
          rank_one_split_home.split_home_slot_uom,
          rank_one_split_home.split_home_slot_pick_zone
     FROM pm,
         ( -- start inline view, items rank 1 case home pick zone
          SELECT loc.logi_loc          case_home_slot, 
                 loc.prod_id           prod_id,
                 loc.cust_pref_vendor  cust_pref_vendor,
                 loc.perm              case_home_slot_perm,
                 loc.rank              case_home_slot_rank,
                 loc.uom               case_home_slot_uom,
                 lz.zone_id            case_home_slot_pick_zone,
                 z.zone_type           zone_type
            FROM loc,
                 lzone lz,
                 zone z
           WHERE loc.rank     = 1
             AND loc.uom      IN (0, 2)
             AND lz.logi_loc  = loc.logi_loc
             AND z.zone_id    = lz.zone_id
             AND z.zone_type  = 'PIK'
         ) rank_one_case_home, -- end inline view
         --
         ( -- start inline view, items rank 1 split home pick zone
          SELECT loc.logi_loc          split_home_slot, 
                 loc.prod_id           prod_id,
                 loc.cust_pref_vendor  cust_pref_vendor,
                 loc.perm              split_home_slot_perm,
                 loc.rank              split_home_slot_rank,
                 loc.uom               split_home_slot_uom,
                 lz.zone_id            split_home_slot_pick_zone,
                 z.zone_type           zone_type
            FROM loc,
                 lzone lz,
                 zone z
           WHERE loc.rank     = 1
             AND loc.uom      = 1   -- Split home
             AND lz.logi_loc  = loc.logi_loc
             AND z.zone_id    = lz.zone_id
             AND z.zone_type  = 'PIK'
          ) rank_one_split_home  -- end inline view
          --
    WHERE pm.prod_id                                = cp_prod_id
      AND pm.cust_pref_vendor                       = cp_cust_pref_vendor
      AND rank_one_case_home.prod_id            (+) = pm.prod_id
      AND rank_one_case_home.cust_pref_vendor   (+) = pm.cust_pref_vendor
      AND rank_one_split_home.prod_id           (+) = pm.prod_id
      AND rank_one_split_home.cust_pref_vendor  (+) = pm.cust_pref_vendor;

   --
   -- This cursor selects the pick zone of the oldest inventory
   -- for the item.
   --
   CURSOR c_item_inv(cp_prod_id           pm.prod_id%TYPE,
                     cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE)
   IS
   SELECT z.zone_id      zone_id,
          i.exp_date     exp_date,
          i.qoh          qoh,
          i.logi_loc     logi_loc,
          i.plogi_loc    plogi_loc,
          i.status       inv_status
     FROM lzone lz,
          zone z,
          loc,
          inv i,
          pm
    WHERE pm.prod_id          = cp_prod_id
      AND pm.cust_pref_vendor = cp_cust_pref_vendor
      AND i.prod_id           = pm.prod_id
      AND i.cust_pref_vendor  = pm.cust_pref_vendor
      AND loc.logi_loc        = i.plogi_loc
      AND i.status            IN ('AVL' , 'HLD', 'CDK')
      AND lz.logi_loc         = i.plogi_loc
      AND lz.zone_id          = z.zone_id
      AND z.zone_type         = 'PIK'
    ORDER BY DECODE(i.status, 'AVL' , 1,     -- Look at AVL inventory first
                              'HLD',  2,     -- Then HLD
                              'CDK',  9,     -- CDK (cross dock) last
                              3),            -- Other inv status
             TRUNC(i.exp_date), i.qoh, i.logi_loc;

   -- 
   -- This cursor gets the pick zone of the item's last ship slot.
   -- 
   CURSOR c_last_ship_slot_pick_zone
                (cp_last_ship_slot    pm.last_ship_slot%TYPE)
   IS
   SELECT z.zone_id      zone_id
     FROM lzone lz,
          zone z
    WHERE lz.logi_loc   = cp_last_ship_slot
      AND lz.zone_id    = z.zone_id
      AND z.zone_type   = 'PIK';

   -- 
   -- This cursor gets the default pick zone for an area.
   -- 
   CURSOR c_area_def_pik_zone(cp_area  pm.area%TYPE)
   IS
   SELECT sa.def_pik_zone   area_def_pik_zone
     FROM swms_areas sa
    WHERE sa.area_code = cp_area;

   -- 
   -- This cursor selects a random pick zone based on the area.
   -- If there happens to be no area then some random pick zone
   -- in some area is selected.
   -- This is failsafe measure as we always want to have a pick zone.
   --
   CURSOR c_area_pick_zone(cp_area  pm.area%TYPE)
   IS
   SELECT z.zone_id
     FROM loc l,
          lzone lz,
          swms_sub_areas ssa,
          aisle_info ai,
          zone z
    WHERE ssa.area_code             = NVL(cp_area, ssa.area_code)
      AND ai.sub_area_code          = ssa.sub_area_code
      AND substr(l.logi_loc, 1, 2)  = ai.name
      AND lz.logi_loc               = l.logi_loc
      AND lz.zone_id                = z.zone_id
      AND z.zone_type               = 'PIK'
      AND exists 
             (SELECT 'x'
                FROM inv
               WHERE inv.plogi_loc = l.logi_loc
                 AND inv.qoh > 0);


   l_r_item_info  c_item_info%ROWTYPE;
   l_r_item_inv   c_item_inv%ROWTYPE;
BEGIN
   --
   -- Log starting the procedure.
   --
   /***** 12/05/2014  Brian Bent  Don't log.  Will be too many messages.  *****/

   --
   -- Check the parameters.
   -- i_prod_id, i_cust_pref_vendor and i_uom need values.
   --
   IF (i_prod_id IS NULL OR i_cust_pref_vendor IS NULL or i_uom IS NULL)
   THEN
      RAISE gl_e_parameter_null;
   END IF;

   OPEN c_item_info(i_prod_id, i_cust_pref_vendor);
   FETCH c_item_info INTO l_r_item_info;

   IF (c_item_info%NOTFOUND) THEN
      --
      -- Item not in SWMS.  Log a message and flag not to continue processing
      -- This function will return null for the pick zone.
      -- In normal processing this should not happen.
      --
      RAISE l_e_item_not_found;
   END IF;

   CLOSE c_item_info;

   --
   -- For a matrix item get the matrix pick zone and the order not for splits.
   --
   IF (    l_r_item_info.mx_item_assign_flag = 'Y'
       AND i_uom <> 1)
   THEN
      l_pick_zone_for_ordd := get_matrix_pick_zone(l_r_item_info.prod_id, l_r_item_info.cust_pref_vendor);

      --
      -- If no pick zone found for a matrix item then log a message and
      -- create an alert.  Do not stop processing but continue to look for
      -- the pick zone.
      -- Ideally a pick zone should have been found.
      --
      IF (l_pick_zone_for_ordd IS NULL) THEN
         l_message :=
              '(i_prod_id['               || i_prod_id          || '],'
              || 'i_cust_pref_vendor['    || i_cust_pref_vendor || '],'
              || 'i_uom['                 || TO_CHAR(i_uom)     || '],'
              || 'i_order_id['            || i_order_id         || '],'
              || 'i_order_line_id['       || TO_CHAR(i_order_line_id) || '])'
              || '  item area['           || l_r_item_info.area || ']'
              || '  mx_item_assign_flag[' || l_r_item_info.mx_item_assign_flag || ']'
              || '  mx_eligible['         || l_r_item_info.mx_eligible || ']'
              || '  mx_food_type['        || l_r_item_info.mx_food_type || ']'
              || '  Could not determine the pick zone for a matrix item.'
              || '  Verify the food type is setup for the item.'
              || '  Will continue to look for the pick zone.'
              || '  The pick zone search rules are:'
              || '  (1) If a matrix item then the matrix pick zone'
              || ' based on the item''s food type and the setup in'
              || ' table MX_FOOD_TYPE;'
              || '  (2) Rank 1 case home slot pick zone;'
              || '  (3) Oldest AVL, HLD, CDK inventory record pick zone;'
              || '  (4) Item''s last ship slot;'
              || '  (5) Default pick zone from SWMS_AREAS using the item area.'
              || '  (6) A random pick zone that has inventory and is in the item''s area.';

         pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                        l_message, pl_exc.ct_data_error, NULL,
                        ct_application_function, gl_pkg_name);

         -- AAA_ALERT  Need alert call here
      END IF;
   END IF;

   --
   -- If no pick zone found yet.
   -- For a matrix item get use the rank 1 split home if the order is for splits.
   --
   IF (    l_r_item_info.mx_item_assign_flag = 'Y'
       AND i_uom = 1)
   THEN
      IF (l_r_item_info.split_home_slot_pick_zone IS NOT NULL) THEN
         --
         -- Item has a rank 1 split home.  Use it's pick zone.
         --
         l_pick_zone_for_ordd := l_r_item_info.split_home_slot_pick_zone;
      END IF;
   END IF;

   --
   -- If no pick zone found yet then look for rank 1 case home.
   --
   IF (l_pick_zone_for_ordd IS NULL) THEN
      IF (l_r_item_info.case_home_slot_pick_zone IS NOT NULL) THEN
         --
         -- Item has a rank 1 case home.  Use it's pick zone.
         --
         l_pick_zone_for_ordd := l_r_item_info.case_home_slot_pick_zone;

         --
         -- Log a message if it is a matrix item.  One message already
         -- logged above.  We want another message that a case home slot
         -- pick zone was used for a matrix item.
         --
         IF (l_r_item_info.mx_item_assign_flag = 'Y') THEN
            l_message :=
              '(i_prod_id['                      || i_prod_id          || '],'
              || 'i_cust_pref_vendor['           || i_cust_pref_vendor || '],'
              || 'i_uom['                        || TO_CHAR(i_uom)     || '],'
              || 'i_order_id['                   || i_order_id         || '],'
              || 'i_order_line_id['              || TO_CHAR(i_order_line_id) || '])'
              || '  item area['                  || l_r_item_info.area || ']'
              || '  last_ship_slot['             || l_r_item_info.last_ship_slot || ']'
              || '  mx_item_assign_flag['        || l_r_item_info.mx_item_assign_flag || ']'
              || '  mx_eligible['                || l_r_item_info.mx_eligible || ']'
              || '  mx_food_type['               || l_r_item_info.mx_food_type || ']'
              || '  rank 1 case home pick zone[' || l_r_item_info.case_home_slot_pick_zone || ']'
              || '  Using rank 1 case home pick zone for a matrix item.';

            pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                           l_message, pl_exc.ct_data_error, NULL,
                           ct_application_function, gl_pkg_name);

            -- AAA_ALERT  Need alert call here
         END IF;
      END IF;
   END IF;


   --
   -- If no pick zone found yet then look for an inventory record.
   --
   IF (l_pick_zone_for_ordd IS NULL) THEN
      --
      -- Use inventory record for the item if there is one.
      --
      OPEN c_item_inv(i_prod_id, i_cust_pref_vendor);
      FETCH c_item_inv INTO l_r_item_inv;

      IF (c_item_inv%FOUND) THEN
         --
         -- Found an inventory record.  Use the pick zone for the location
         -- of the inventory record.
         --
         l_pick_zone_for_ordd := l_r_item_inv.zone_id;

         --
         -- If it is a matrix item then log a message and create an
         -- info alert.  Normally for a matrix item we should not reach this 
         -- point which is why we create a log message and alert for a matix
         -- item.
         --
         IF (l_r_item_info.mx_item_assign_flag = 'Y') THEN
            l_message :=
                         '(i_prod_id['            || i_prod_id          || '],'
                      || 'i_cust_pref_vendor['    || i_cust_pref_vendor || '],'
                      || 'i_uom['                 || TO_CHAR(i_uom)     || '],'
                      || 'i_order_id['            || i_order_id         || '],'
                      || 'i_order_line_id['       || TO_CHAR(i_order_line_id) || '])'
                      || '  item area['           || l_r_item_info.area || ']'
                      || '  last_ship_slot['      || l_r_item_info.last_ship_slot || ']'
                      || '  mx_item_assign_flag[' || l_r_item_info.mx_item_assign_flag || ']'
                      || '  mx_eligible['         || l_r_item_info.mx_eligible || ']'
                      || '  mx_food_type['        || l_r_item_info.mx_food_type || ']'
                      || '  LP['                  || l_r_item_inv.logi_loc || ']'
                      || '  location['            || l_r_item_inv.plogi_loc || ']'
                      || '  pick zone['           || l_r_item_inv.zone_id || ']'
                      || '  Matrix item found pick zone using inventory record.'
                      || '  The pick zone for a matrix item should have come'
                      || ' from the item''s food type and the setup in the MX_FOOD_TYPE'
                      || ' table and not from an inventory location pick zone.';

            pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                           l_message, pl_exc.ct_data_error, NULL,
                           ct_application_function, gl_pkg_name);

            -- AAA_ALERT  Need info alert call here
         END IF;
      END IF;  -- end IF (c_item_inv%FOUND) THEN

      CLOSE c_item_inv;

   END IF;


   --
   -- If no pick zone found yet then look for the pick zone of the
   -- item's last ship slot.
   --
   IF (l_pick_zone_for_ordd IS NULL) THEN
      --
      -- Use the pick zone of the last ship slot if there is one.
      -- Normally this point will not be reached.
      --
      OPEN c_last_ship_slot_pick_zone(l_r_item_info.last_ship_slot);
      FETCH c_last_ship_slot_pick_zone INTO l_pick_zone_for_ordd;

      IF (c_last_ship_slot_pick_zone%FOUND) THEN
         --
         -- Got the pick zone of the last ship slot.  Use it.
         -- In normal processing we should not be using the last ship slot
         -- pick zone very often.  Log a message and alert.
         --
         l_message :=
                '(i_prod_id['            || i_prod_id          || '],'
             || 'i_cust_pref_vendor['    || i_cust_pref_vendor || '],'
             || 'i_uom['                 || TO_CHAR(i_uom)     || '],'
             || 'i_order_id['            || i_order_id         || '],'
             || 'i_order_line_id['       || TO_CHAR(i_order_line_id) || '])'
             || '  item area['           || l_r_item_info.area || ']'
             || '  last_ship_slot['      || l_r_item_info.last_ship_slot || ']'
             || '  mx_item_assign_flag[' || l_r_item_info.mx_item_assign_flag || ']'
             || '  mx_eligible['         || l_r_item_info.mx_eligible || ']'
             || '  mx_food_type['        || l_r_item_info.mx_food_type || ']'
             || '  last ship slot pick zone['  || l_pick_zone_for_ordd  || ']'
             || '  Found pick zone of last ship slot.  Use it';

         pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                        l_message, pl_exc.ct_data_error, NULL,
                        ct_application_function, gl_pkg_name);

         -- AAA_ALERT  Need info alert call here
      ELSE
         --
         -- Found no pick zone for the last ship slot.
         -- In normal processing we should not reach this point.
         -- Log a message and alert.
         --
         l_message :=
                 '(i_prod_id['               || i_prod_id          || '],'
              || 'i_cust_pref_vendor['       || i_cust_pref_vendor || '],'
              || 'i_uom['                    || TO_CHAR(i_uom)     || '],'
              || 'i_order_id['               || i_order_id         || '],'
              || 'i_order_line_id['          || TO_CHAR(i_order_line_id) || '])'
              || '  item area['              || l_r_item_info.area || ']'
              || '  last_ship_slot['      || l_r_item_info.last_ship_slot || ']'
              || '  Did not find pick of the last ship slot.'
              || '  Will check the area default pick zone next.';

         pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                              l_message, pl_exc.ct_data_error, NULL,
                              ct_application_function, gl_pkg_name);

         -- AAA_ALERT  Need info alert call here
      END IF;

      CLOSE c_last_ship_slot_pick_zone;

   END IF;


   --
   -- If no pick zone found yet then look for the area default pick zone.
   --
   IF (l_pick_zone_for_ordd IS NULL) THEN
      --
      -- Use the area default pick zone if there is one.
      -- Normally this point will not be reached.
      --
      OPEN c_area_def_pik_zone(l_r_item_info.area);
      FETCH c_area_def_pik_zone INTO l_pick_zone_for_ordd;

      IF (c_area_def_pik_zone%FOUND) THEN
         --
         -- We have a area default pick zone.  Use it.
         -- Log a message and alert.
         -- In normal processing we should not be using an area default
         -- pick zone which is why we log a message and create an alert.
         --
         l_message :=
                         '(i_prod_id['            || i_prod_id          || '],'
                      || 'i_cust_pref_vendor['    || i_cust_pref_vendor || '],'
                      || 'i_uom['                 || TO_CHAR(i_uom)     || '],'
                      || 'i_order_id['            || i_order_id         || '],'
                      || 'i_order_line_id['       || TO_CHAR(i_order_line_id) || '])'
                      || '  item area['           || l_r_item_info.area || ']'
                      || '  last_ship_slot['      || l_r_item_info.last_ship_slot || ']'
                      || '  mx_item_assign_flag[' || l_r_item_info.mx_item_assign_flag || ']'
                      || '  mx_eligible['         || l_r_item_info.mx_eligible || ']'
                      || '  mx_food_type['        || l_r_item_info.mx_food_type || ']'
                      || '  area default pick zone['  || l_pick_zone_for_ordd  || ']'
                      || '  Found no pick zone after checking:'
                      || '  (1) If a matrix item then the matrix pick zone;' 
                      || '  (2) Rank 1 case home slot pick zone;'
                      || '  (3) Oldest AVL, HLD, CDK inventory record pick zone.'
                      || '  (4) Item''s last ship slot.'
                      || '  Will use the item''s area default pick zone.';

         pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                        l_message, pl_exc.ct_data_error, NULL,
                        ct_application_function, gl_pkg_name);

         -- AAA_ALERT  Need info alert call here
      ELSE
         --
         -- There is no default pick zone for the item's area.
         -- In normal processing we should not reach this point.
         -- Log a message and alert.
         --
         l_message :=
                         '(i_prod_id['               || i_prod_id          || '],'
                      || 'i_cust_pref_vendor['       || i_cust_pref_vendor || '],'
                      || 'i_uom['                    || TO_CHAR(i_uom)     || '],'
                      || 'i_order_id['               || i_order_id         || '],'
                      || 'i_order_line_id['          || TO_CHAR(i_order_line_id) || '])'
                      || '  item area['              || l_r_item_info.area || ']'
                      || '  Item''s area has no default pick zone.';

         pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                              l_message, pl_exc.ct_data_error, NULL,
                              ct_application_function, gl_pkg_name);

         -- AAA_ALERT  Need info alert call here
      END IF;
      CLOSE c_area_def_pik_zone;
   END IF;


   --
   -- If no pick zone found yet then find a random pick zone that has
   -- inventory and is in the item's area.  If the item area is blank then
   -- a random pick zone is used.  We want to return something.
   --
   IF (l_pick_zone_for_ordd IS NULL) THEN
      --
      -- At the end of finding the pick zone.  Find some randon pick zone.
      -- Normally this point will not be reached.
      --
      OPEN c_area_pick_zone(l_r_item_info.area);
      FETCH c_area_pick_zone INTO l_pick_zone_for_ordd;
      l_cursor_found := c_area_pick_zone%FOUND;
      CLOSE c_area_pick_zone;

      IF (l_cursor_found = TRUE) THEN
         --
         -- Found a random pick zone.  Use it.
         -- Log a message and alert.
         -- In normal processing we should not readch this point
         -- which is why we log a message and create an alert.
         --
         l_message :=
                         '(i_prod_id['            || i_prod_id          || '],'
                      || 'i_cust_pref_vendor['    || i_cust_pref_vendor || '],'
                      || 'i_uom['                 || TO_CHAR(i_uom)     || '],'
                      || 'i_order_id['            || i_order_id         || '],'
                      || 'i_order_line_id['       || TO_CHAR(i_order_line_id) || '])'
                      || '  item area['           || l_r_item_info.area || ']'
                      || '  last_ship_slot['      || l_r_item_info.last_ship_slot || ']'
                      || '  mx_item_assign_flag[' || l_r_item_info.mx_item_assign_flag || ']'
                      || '  mx_eligible['         || l_r_item_info.mx_eligible || ']'
                      || '  mx_food_type['        || l_r_item_info.mx_food_type || ']'
                      || '  random pick zone['    || l_pick_zone_for_ordd  || ']'
                      || '  Found no pick zone after checking:'
                      || '  (1) If a matrix item then the matrix pick zone;' 
                      || '  (2) Rank 1 case home slot pick zone;'
                      || '  (3) Oldest AVL, HLD, CDK inventory record pick zone;'
                      || '  (4) Item''s last ship slot;'
                      || '  (5) Item area default pick zone.'
                      || '  Used a random pick zone based on the item''s area.';

         pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                        l_message, pl_exc.ct_data_error, NULL,
                        ct_application_function, gl_pkg_name);

         -- AAA_ALERT  Need info alert call here
      ELSE
         --
         -- Found no random pick zone.
         -- In normal processing we should never reach this point.
         -- Log a message and alert.
         --
         l_pick_zone_for_ordd := 'UNKP';

         l_message :=
                         '(i_prod_id['               || i_prod_id          || '],'
                      || 'i_cust_pref_vendor['       || i_cust_pref_vendor || '],'
                      || 'i_uom['                    || TO_CHAR(i_uom)     || '],'
                      || 'i_order_id['               || i_order_id         || '],'
                      || 'i_order_line_id['          || TO_CHAR(i_order_line_id) || '])'
                      || '  item area['              || l_r_item_info.area || ']'
                      || '  Did not find a random pick zone.  Will use UNKP';

         pl_log.ins_msg(pl_log.ct_error_msg, l_object_name,
                        l_message, pl_exc.ct_data_error, NULL,
                        ct_application_function, gl_pkg_name);

         -- AAA_ALERT  Need info alert call here
      END IF;
   END IF;

   RETURN(l_pick_zone_for_ordd);

EXCEPTION
   WHEN gl_e_parameter_null THEN
      --
      -- A parameter is null.
      -- i_prod_id and i_cust_pref_vendor need values.
      --
      l_message := '(i_prod_id['            || i_prod_id          || '],'
                   || 'i_cust_pref_vendor[' || i_cust_pref_vendor || '],'
                   || 'i_uom['              || TO_CHAR(i_uom)     || '],'
                   || 'i_order_id['         || i_order_id         || '],'
                   || 'i_order_line_id['    || TO_CHAR(i_order_line_id) || '])'
                   || '  i_prod_id, i_cust_pref_vendor and i_uom all need a value.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      -- AAA_ALERT  Need alert call here

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

   WHEN l_e_item_not_found THEN
      --
      -- Item not found in PM table.  Log message and create alert and
      -- return NULL.
      --
      -- Calling program needs to decide how to handle null returned for
      -- the pick zone
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     '(i_prod_id['              || i_prod_id          || '],'
                       || 'i_cust_pref_vendor[' || i_cust_pref_vendor || '],'
                       || 'i_uom['              || TO_CHAR(i_uom)     || '],'
                       || 'i_order_id['         || i_order_id         || '],'
                       || 'i_order_line_id['    || TO_CHAR(i_order_line_id) || '])'
                       || '  Item not in SWMS PM.',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      -- AAA_ALERT  Need alert call here

      RETURN(NULL);

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     '(i_prod_id['              || i_prod_id          || '],'
                       || 'i_cust_pref_vendor[' || i_cust_pref_vendor || '],'
                       || 'i_uom['              || TO_CHAR(i_uom)     || '],'
                       || 'i_order_id['         || i_order_id         || '],'
                       || 'i_order_line_id['    || TO_CHAR(i_order_line_id) || '])',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      -- AAA_ALERT  Need alert call here

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);

END get_item_pick_zone_for_order;


---------------------------------------------------------------------------
-- Procedure:
--    update_ordd_zone_id
--
-- Description:
--    This procedure updates ORDD.ZONE_ID with the pick zone to pick from.
--
--
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by:
--    CRT_order_proc.pc
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/29/15 bben0556 Created.   
--    09/28/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Do not update ordd.zone_id for 'X' cross dock type. 
--                      ordd.zone_id is assigned when the orders/floats merged
--                      at Site 2.
--                      Modified cursor "c_ordd" to exclude 'X' cross dock type.
---------------------------------------------------------------------------
PROCEDURE update_ordd_zone_id
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL)
IS
   l_object_name   VARCHAR2(30)   := 'update_ordd_zone_id';
   l_message       VARCHAR2(256);

   --
   -- Used in error messages.
   --
   l_prod_id            pm.prod_id%TYPE;
   l_order_id           ordd.order_id%TYPE;
   l_order_line_id      ordd.order_line_id%TYPE;

   l_pick_zone          zone.zone_id%TYPE;

   --
   -- Variables to count the exceptions and log at the end of the processing.
   --
   l_num_records_processed         PLS_INTEGER := 0;

   e_parameter_bad_combination    EXCEPTION;  -- Bad combination of
                                              -- parameters.

   --
   -- This cursor selects the ORDD records to update.
   --
   CURSOR c_ordd(cp_route_batch_no  route.route_batch_no%TYPE,
                 cp_route_no        route.route_no%TYPE)
   IS
      SELECT r.route_no,
             r.route_batch_no,
             ordd.prod_id,
             ordd.cust_pref_vendor,
             ordd.order_id,
             ordd.order_line_id,
             ordd.uom,
             pm.miniload_storage_ind,
             pm.mx_eligible,
             pm.mx_item_assign_flag
        FROM ordd,
             route r,
             pm,
             ordm
       WHERE (   r.route_batch_no  = cp_route_batch_no
              OR r.route_no        = cp_route_no)
         AND ordd.route_no                    = r.route_no
         AND pm.prod_id                       = ordd.prod_id
         AND pm.cust_pref_vendor              = ordd.cust_pref_vendor
         AND ordm.order_id                    = ordd.order_id
         AND NVL(ordm.cross_dock_type, 'aaa') <> 'X';           -- 09/28/21 Exclude R1 'X' cross dock orders
BEGIN
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || '])'
         || '  This procedure updates ORDD.ZONE_ID to the pick zone to pick from.'
         || '  Note that this is the initial update.  CRT_order_proc.pc can make'
         || ' and additonal update for a split order.'
         || '  R1 X cross dock orders are ignored as the ordd.zone_id is assigned'
         || ' when the orders merged at Site 2.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   --
   -- Check the parameters.
   -- One and only one of i_route_batch_no and i_route_batch_no should
   -- be populated.
   --
   IF (   i_route_batch_no IS NULL     AND i_route_no IS NOT NULL
       OR i_route_batch_no IS NOT NULL AND i_route_no IS NULL)
   THEN
      NULL;  -- Parameter check OK.
   ELSE
      RAISE e_parameter_bad_combination;
   END IF;


   FOR r_ordd in c_ordd(i_route_batch_no, i_route_no)
   LOOP
      --
      -- For error messages if we get an error that breaks us out of the loop.
      --
      l_prod_id        := r_ordd.prod_id;
      l_order_id       := r_ordd.order_id;
      l_order_line_id  := r_ordd.order_line_id;

      l_num_records_processed := l_num_records_processed + 1;

      DBMS_OUTPUT.PUT_LINE(
               'route_no:'              || r_ordd.route_no
            || ' route_batch_no:'       || r_ordd.route_batch_no
            || ' prod_id:'              || r_ordd.prod_id
            || ' order_id:'             || r_ordd.order_id
            || ' order_line_id:'        || r_ordd.order_line_id
            || ' uom:'                  || r_ordd.uom
            || ' mx_eligible:'          || r_ordd.mx_eligible
            || ' mx_item_assign_flag:'  || r_ordd.mx_item_assign_flag);

      l_pick_zone  := get_item_pick_zone_for_order(r_ordd.prod_id, r_ordd.cust_pref_vendor,
                                                   r_ordd.uom, r_ordd.order_id, r_ordd.order_line_id);

      DBMS_OUTPUT.PUT_LINE('-----' || r_ordd.prod_id
            || '  ' || TO_CHAR(r_ordd.uom)
            || '  ' || rpad(nvl(l_pick_zone, ' '), 5));

       UPDATE ordd o
          SET o.zone_id = l_pick_zone
        WHERE o.order_id      =  r_ordd.order_id
          AND o.order_line_id =  r_ordd.order_line_id;

   END LOOP;    -- end the ordd loop

   --
   -- Log the counts.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Counts:  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
                     || 'i_route_no['              || i_route_no                     || ']),'
                     || '  l_num_records_processed['  || TO_CHAR(l_num_records_processed)  || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   --
   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure'
                     || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
                     || 'i_route_no['              || i_route_no                     || '])',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
					 
   pl_op_pick_zone.update_unitize_ind( I_ROUTE_BATCH_NO, I_ROUTE_NO );				 
					 
EXCEPTION
   WHEN e_parameter_bad_combination THEN
      --
      -- One and only one of i_route_batch_no and i_route_n can be populated.
      --
      l_message := '(i_route_batch_no[' || TO_CHAR(i_route_batch_no) || '],'
                   || 'i_route_no[' || i_route_no || '])'
                   || '  One and only one of these two parameters can have a value.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     l_message, pl_exc.ct_data_error, NULL,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no['      || TO_CHAR(i_route_batch_no)      || '],'
                      || 'i_route_no['             || i_route_no                     || '])'
                      || '  l_prod_id['            || l_prod_id                      || ']'
                      || '  l_order_id['           || l_order_id                     || ']'
                      || '  l_order_line_id['      || TO_CHAR(l_order_line_id)       || ']',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);
END update_ordd_zone_id;

---------------------------------------------------------------------------
-- Procedure:
--    update_unitize_ind
--
-- Description:
--    This procedure updates ordm.unitize_ind with 1st stop for a batch_route_no
-- Parameters:
--    NOTE: One and only one parameters i_route_batch_no and i_route_no can
--          be populated.
--    i_route_batch_no   - The route batch number to process.
--    i_route_no         - The route number to process.
--
-- Called by: procedure
--    update_ordd_zone_id
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/21/16 xzhe5043 Created.   
---------------------------------------------------------------------------
PROCEDURE update_unitize_ind
         (i_route_batch_no  IN  route.route_batch_no%TYPE        DEFAULT NULL,
          i_route_no        IN  route.route_no%TYPE              DEFAULT NULL)
IS
      l_object_name   VARCHAR2(30)   := 'update_unitize_ind';
      l_message       VARCHAR2(256);
      l_num_records_processed         PLS_INTEGER := 0;
      l_syspar     VARCHAR2(1);


BEGIN

 
      l_syspar:= pl_common.f_get_syspar ('UNITIZE_IND', 'N');
      
         pl_log.ins_msg
        (pl_log.ct_info_msg, l_object_name,
         'Starting procedure update_unitize_ind'
         || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || '],'
         || 'i_route_no['              || i_route_no                     || '])',
         NULL, NULL,
         ct_application_function, gl_pkg_name);
         
         
        IF l_syspar = 'Y' THEN
        
                  UPDATE ordm o
                    SET  UNITIZE_IND = 'Y'
                  WHERE exists (select 'x' 
                                from route r 
                                where r.route_batch_no = i_route_batch_no
				and   r.route_no = o.route_no)
                    AND o.STOP_NO  = '1'
                    AND o.IMMEDIATE_IND = 'N'
                    AND nvl(o.unitize_ind,'N') not in ('Y','Z');
                             
                  COMMIT;
                              
        END IF;

   -- Log when done.  Note that if there is an exception this message can be bypassed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'Ending procedure: updated '
                     || '  (i_route_batch_no['     || TO_CHAR(i_route_batch_no)      || ']',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);    
 EXCEPTION


   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                         '(i_route_batch_no['      || TO_CHAR(i_route_batch_no)      || '])',
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            l_object_name || ': ' || SQLERRM);   

END update_unitize_ind;

END pl_op_pick_zone;
/

SHOW ERRORS


/****/
CREATE OR REPLACE PUBLIC SYNONYM pl_op_pick_zone FOR swms.pl_op_pick_zone
/

GRANT EXECUTE ON swms.pl_op_pick_zone TO SWMS_USER
/
/***/

