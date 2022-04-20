
SET DOC OFF

--------------------------------------------------------------------------
-- Package Specification
--------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE swms.pl_rcv_open_po_cursors
AS

-- sccs_id=@(#) src/schema/plsql/pl_rcv_open_po_cursors.sql, swms, swms.9, 11.2 4/9/10 1.23

---------------------------------------------------------------------------
-- Package Name:
--    pl_put_cursors
--
-- Description:
--    This package has the select stmts used to select the candidate putaway
--    slots for the open PO/SN process.  It also has CURSORS shared by
--    program units.
--
--    The packages used in the open PO/SN process are:
--       - pl_rcv_open_po_types
--       - pl_rcv_open_po_cursors
--       - pl_rcv_open_po_pallet_list
--       - pl_rcv_open_po_find_slot
--
--    See file pl_rcv_open_po_find_slot.sql for additional information.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/05 prpbcb   Created.
--                      Putaway by cube and inches have been combined
--                      into one set of packages.
--
--                      Oracle 8 rs239b swms9 DN 11992
--                      Project: 7698-SWMS PBI Partial Pallet
--
--                      Oracle 8 rs239b swms9 DN 11993
--                      Project: SWMS-IM48262-Pallet Not Assign Reserve
-- 
--                      Oracle 8 rs239b swms9 DN 11994
--                      Project: 5713-TD-Partial Aging Beef
--
--                      Oracle 8 rs239b swms9 DN 11995
--                      Project: CMBFS-Combine floating slots for non-fif
--
--    09/01/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Fixed to bugs found by SQ.
--
--    09/11/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Fixed to bugs found by SQ.
--
--    09/13/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Add slot_height.
--
--    09/27/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Added selecting the home slot put zone id in cursor
--                      g_c_case_home_slots.
--
--    10/19/05 prpbcb   Oracle 8 rs239b swms9 DN 12016
--                      Changed the ordering for deep slots from
--                         loc.cube
--                      to
--                         loc.cube / number of positions
--                      Candidate reserve locations are found for items with
--                      deep home slots by matching by the deep indicator.
--                      It used to be that the matching was done by the slot
--                      type but this was changed in SWMS 9.3 to match by
--                      deep indicator.  Deep slots do not use the PALLET_TYPE
--                      syspar.  This change was made to handle the situation
--                      where the home slot and reserve slots in the putaway
--                      zone do not have the same type of deep slot such as
--                      a 3PB home slot and 2PB reserve slots.  OpCo 67 has
--                      a situation where a pallet for an item that has a 2PB
--                      home slot has pallets directed to 1D slots which are
--                      in a different aisle than the home slot.  The
--                      primary put zone has LWC, 2PB and 1D slots.  The 1D
--                      slots are 60 cube.  The 2PB slots are 120 cube.
--                      Because the 1D slots are smaller than the 2PB slots
--                      they get selected first in the processing.  The
--                      change to sort by "loc.cube / number of positions"
--                      should help in resolving this issue.  It will not help
--                      if the 1D slots are on the other side of the aisle.
--                      Looking back we should have created a syspar that
--                      controls if reserve deep slots should be matched to
--                      the deep home slot by the slot type or deep indicator.
--                      A syspar exists in this program called
--                      "putaway_to_any_deep_slot" which has a default
--                      value of Y.  So the program already has the code to
--                      handle a syspar.  All that needs to be done for the
--                      users to control if matching is done by slot type or
--                      deep indicator is to create a syspar called
--                      PUTAWAY_TO_ANY_DEEP_SLOT.
--         
--    11/29/05 prpbcb   Oracle 8 rs239b swms9 DN 12043
--
--                      Ticket: 80672
--                      Changed the cursors that select slots with existing
--                      inventory to exclude slots where the
--                         slot cube - occupied cube < cube of the pallet to 
--                                                     putaway
--                      Before the condition was
--                         slot cube >= cube of the
--                                      pallet to putaway
--                      This was resulting in slots being processed that
--                      were not large enough for a pallet which slowed
--                      processing and caused a lot of unnecessary swms_log
--                      messages to get created.
--                      The logic added to the cursors is very similar to that
--                      in procedure
--                      pl_rcv_open_po_find_slot.get_rsrv_float_slot_occ_cube().
--                      When a slot that has existing inventory is processed
--                      the occupied cube is calculated.  But waiting until
--                      the slot is processed is not efficient when there
--                      are many slots where the pallet will fit when the
--                      slot is empty but will not fit when taking into 
--                      account the occupied cube.  We want to exclude these
--                      slots in the select statement.
--                      Procedures modified:
--                         - non_deep_slots()    SAME_ITEM cursor
--                         - non_deep_slots()    ANY_NON_EMPTY_LOCATION cursor
--                         - deep_slots()        SAME_ITEM cursor
--                         - deep_slots()        DIFFERENT_ITEM cursor
--                         - bulk_rule_slots()   SAME_ITEM cursor
--                         - bulk_rule_slots()   DIFFERENT_ITEM cursor
--                      The same sub-query was added to each cursor
--                      So now a check is made if the pallet fits in both
--                      the cursor and also in procedure
--                      pl_rcv_open_po_find_slot.direct_pallets_to_zone().
--                      direct_pallets_to_zone() calls
--                      get_rsrv_float_slot_occ_cube().
--                      This is redundant but trying to do everything in the
--                      cursor that procedure get_rsrv_float_slot_occ_cube does
--                      is not practical.  Testing has shown the performance
--                      to be about 35% faster than pallet_label2.pc.
--
--                      Changed the order by in the cursors for non-deep,
--                      deep slots and bulk rule slots to use syspar
--                      partial_minimize_option when ordering the locations
--                      for a partial pallet.  Floating items do not use this
--                      syspar.  If the syspar is 'S' (for size--cube or inches)
--                      then the order is by location the best fit closest to
--                      the anchor location (the way it always has been).  If
--                      the syspar is 'D' (for distance) then order is by
--                      closest to the anchor location.  The anchor location is
--                      represented by the put path values in the item info
--                      record.  The reason for this syspar is to give the
--                      OpCo the ability to direct partial pallets to locations
--                      nearest the case home slot.
--                      See procedure
--                      pl_rcv_open_po_find_slot.set_put_path_values() for
--                      more information on how the put path values are set.
--                      Note:  Candidate putaway slots for partial pallets
--                             for an item with a non-deep home slot are
--                             processed in this order:
--                                1.  Home slot
--                                2.  Non-open non-deep slots that have at
--                                    least one pallet of the item.
--                                3.  Any non-empty non-deep slot, any product.
--                                4.  Open non-deep slots.
--                             This means if there is an open slot right above
--                             the home slot and there is an occupied slot
--                             the partial pallet can fit in on the next aisle
--                             the pallet will be directed to the slot in the
--                             next aisle because occupied slots are checked
--                             first.
--
--                      Added i_r_pallet parameter to procedures:
--                         - non_deep_slots()
--                         - deep_slots()
--                         - floating_slots()
--                         - bulk_rule_slots()
--                      Removed parameters
--                         - i_pallet_cube_with_skid
--                         - i_pallet_height_with_skid
--                      from the above procedures because they are in the
--                      pallet record.
--
--         
--    12/20/05 prpbcb   Oracle 8 rs239b swms9 DN 12048
--                      WAI changes.
--                      Cursor g_c_case_home_slots looks to be using the item
--                      record case cube and not case_cube_for_calc when
--                      calculating the occupied cube in the home slot which
--                      means extended case cube is not applied for existing
--                      qty in the home slot.
--                      This could cause pallets to be directed/not
--                      directed to the home slot which most likely is not
--                      apparent to the user--but maybe this is not an issue.
--                      Remember that this will only affect home slot with qoh
--                      because if the home slot is empty no check of the cube
--                      is made.
--
--                      Changed the cursors in procedures deep_slots() and
--                      bulk_rule_slots() to handle a null inv.rec_date.
--                      The rec_date (receive date) is used along with a
--                      syspar for deep slots and bulk rule slots to determine
--                      if a pallet should be directed to a slot that already
--                      has one or more pallets of the item with different
--                      receive dates.  A null inv.rec_date was resulting
--                      in a pallet directed to slot with the same item with
--                      different receive dates but the syspar was set not
--                      to have this happen.
--
--                      Added the PO/SN number to the parameter list for the
--                      procedures and functions.  This was done so the PO/SN
--                      number can be put in the aplog messages.
--
--                      Changed cursor g_c_case_home_slots to select the
--                      loc.width_positions.
--
--                      Moved cursor c_loc_info from
--                      pl_rcv_open_po_pallet_list.sql to this file and
--                      named it g_c_loc_info.
--
--                      Changed the cursors selecting candidate putaway
--                      slots to round/not round the quantity to a full Ti
--                      before calculating the cube occupied in the slot
--                      based on the fields round_inv_cube_up_to_ti_flag and
--                      round_plt_cube_up_to_ti_flag in the item info record.
--                      These two item info fields were added in defect 12043
--                      but not used.  Now they will be looked at.
--
--                      Changed 'ANY_LOCATION' to 'ANY_NON_EMPTY_LOCATION'
--                      to better reflect what it means.
--         
--    03/24/06 prpbcb   Oracle 8 rs239b swms9 DN 12078
--                      Ticket: 142935
--                      Removed the check of reserve slot cube >= home
--                      slot cube in procedure non_deep_slots() when
--                      selecting open reserve slots and putaway is by
--                      inches.  This was a bug.
--         
--    05/02/06 prpbcb   Oracle 8 rs239b swms9 DN 12087
--                      Test Direct defect: 6561
--                      Floating slots were not ordered correctly in
--                      procedure floating_slots.
--         
--    06/01/06 prpbcb   Oracle 8 rs239b swms9 DN 12087
--                      Ticket: 182100
--                      Began changes to
--                      cursor in procedure floating_slots() to look
--                      at syspar CHK_FLOAT_CUBE_GE_LSS_CUBE when putaway
--                      is by cube.  This is a new syspar used to
--                      check/not check that the slot cube is >= last ship
--                      ship slot cube when selecting candidate OPEN floating
--                      slots.
--                      This syspar does not exist yet so the change has
--                      no affect to the current logic.
--                      *** Things commented out for now ***
--         
--    06/06/06 prpbcb   Oracle 8 rs239b swms9 DN 12097
--                      Add documentation.
--
--                      Ticket: 182100
--                      Back working on using syspar
--                      CHK_FLOAT_CUBE_GE_LSS_CUBE to check/not check that
--                      the slot cube is >= last ship ship slot cube when
--                      selecting candidate OPEN floating slots.
--                      Code ready but commented out.
--         
--    07/20/06 prpbcb   Oracle 8 rs239b swms9 DN 12114
--                      Ticket: 182100
--                      Project: 182100-Direct Pallet for Floating Item
--                      Finish change to check/not check that
--                      the slot cube is >= last ship ship slot cube when
--                      selecting candidate OPEN floating slots.
--
--    05/01/07 prpbcb   DN 12235
--                      Ticket: 265200
--                      Project: 265200-Putaway By Inches Modifications
--
--                      Implement logic for pm.pallet_stack for non-deep
--                      slots.  It was missed when pallet_label2.pc was
--                      converted to PL/SQL.  pallet stack is ignored for
--                      deep slots baecause pallets are not stacked
--                      in deep slots.
--
--                      Changed cursor in procedure floating_slots() to look
--                      at syspar CHK_FLOAT_HGT_GE_LSS_HGT when putaway
--                      is by inches.  This is a new syspar used to
--                      check/not check that the slot height is >= last ship
--                      ship slot height when selecting candidate OPEN
--                      floating slots.  It works the same as syspar
--                      CHK_FLOAT_CUBE_GE_LSS_CUBE but for inches.
--
--                      Added true_slot_height to g_c_loc_info.
--
--                      Changed procedure floating_items() adding logic for
--                      putaway by max qty for a floating item.
--                   
--    11/06/09 prpbcb   Added AUTHID CURRENT_USER so things work correctly
--                      when pre-receiving into the new warehouse for a
--                      warehouse move.
--
--    12/17/09 prpbcb   DN 12533
--                      Removed AUTHID CURRENT_USER.  We found a problem in
--                      pl_rcv_open_po_cursors.f_get_inv_qty when using it.
--
--    04/07/10 prpbcb   DN 12571
--                      Project: CRQ15757-Miniload In Reserve Fixes
--
--                      Changed the select statment in procedure
--                      floating_slots() to use the pallet type cross
--                      reference for minload items going to reserve slots
--                      and the item has cases stored in the miniloader
--                      (miniload_storage_ind = 'B')
--                      Miniload items will have a pallet type of HS and
--                      the pallet types of the reserve slots in the
--                      main warehouse probably will not be HS.
--
--    12/04/15 prpbcb  Project:
-- R30.4--WIB#587--Charm6000008479_Open_PO_for_full_pallet_provide_ability_to_find_slot_by_best_fit_or_closest_to_case_home_slot
--
--                     Need to be able to direct full pallets for items with
--                     a rank 1 case home to reserve slots based on:
--                        - Best fit by size, cube or inches--whichever is active
--                        or
--                        - Slots closest to the home slot
--                     Currently it is by best fit.
--
--                     Three new syspars created:
--                        - full_plt_minimize_option_clr  Initial value will be S.
--                        - full_plt_minimize_option_frz  Initial value will be S.
--                        - full_plt_minimize_option_dry  Initial value will be S.
--                     The valid values are 'D' for distance and 'S' for size.
--                     Added these syspars to record type "t_r_putaway_syspars".
--
--                     Added field "full_plt_minimize_option" to record type
--                     "t_r_putaway_syspars".  It is populated from one of
--                     the new syspars based on the area of the item.
--                     The cursors that selects the slots use "full_plt_minimize_option"
--                     in the ORDER BY.
--
--                     Add checking "full_plt_minimize_option" in the ORDER BY
--                     in procedures:
--                        - non_deep_slots
--                        - deep_slots
--                        - bulk_rule_slots
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/28/16 bben0556 Brian Bent
--                      Project:
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_33_find_dest_loc
--
--                      Change i_r_pallet.qty to i_r_pallet.qty_received
--                      We want to use the actual qty on the pallet.
--                      This comes into play when checking-in a live
--                      receiving pallet on the RF.
--
--    02/02/17 bben0556 Brian Bent
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_276_lock_records_when_finding_putaway_dest_loc
--
--                      Lock the candidate putaway locations
--                      by adding "FOR UPDATE l.occupied_height" clause to the
--                      select statements.
--
--                      With Live Receiving, if 2 putaway or receiving
--                      associates are requesting a put location at the same
--                      time, or someone is requesting a location at the same
--                      time the receiver is asking for one we want to
--                      process the requests sequentially.
--
--                      README     README     README     README
--
--    07/10/18 mpha8134 Meat Company Project Jira-438:
--                          -Add logic for the overflow/catch-all floating location
--                          for the Meat company.
--    03/08/21 sban3548	OPCOF-3339: Removed "magic" number used in the putaway find slot logic 
--						(reverted back above Jira-438 changes)
--
--
---------------------------------------------------------------------------


--------------------------------------------------------------------------
--  Public Modules
--
-- Declared before cursors because cursors may use these modules.
--------------------------------------------------------------------------

---------------------------------------------------------------------------
--     prpbcb 05/02/06
--     NOT USED    NOT USED    NOT USED    NOT USED    NOT USED
--     NOT USED    NOT USED    NOT USED    NOT USED    NOT USED
--     NOT USED    NOT USED    NOT USED    NOT USED    NOT USED
-- Function:
--    f_get_rsrv_slot_occupied_cube
--
-- Description:
--    This function returns the cube occupied in a slot.  It is designed
--    to be used for reserve or floating slots.
--
--    For the skid cube the items pallet type is used if it is not 0
--    otherwise the skid cube of the pallet type for the location is used.
--    The cube of a pallet is round to the nearest ti unless otherwise
--    specified by parameter i_cp_round_cube_to_nearest_ti.
--
--    If is used in the select stmts that select the candidate putaway slots.
--
---------------------------------------------------------------------------
FUNCTION f_get_rsrv_slot_occupied_cube
              (i_logi_loc                     IN loc.logi_loc%TYPE,
               i_cp_round_cube_to_nearest_ti  IN VARCHAR2 DEFAULT 'Y')
RETURN NUMBER;


---------------------------------------------------------------------------
-- Function:
--    f_get_inv_qty
--
-- Description:
--    This function returns the qoh + qty_planned for a slot.
--
--    Used by procedure floating_slots().
---------------------------------------------------------------------------
FUNCTION f_get_inv_qty(i_logi_loc  IN loc.logi_loc%TYPE,
                       i_erm_id    IN erm.erm_id%TYPE)
RETURN NUMBER;


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Cursor g_c_case_home_slots
--------------------------------------------------------------------------
-- This cursor selects the rank 1 case home slot as a candidate putaway
-- location for an item.  It is also used when getting info about the item
-- when building the pallet list.
--
-- It will be used twice for an item.  Once when building the pallet list
-- and again when determing if a pallet can be directed to the home slot.
--
-- The cube used calculation is based on what was in pallet_label2.pc.
-- Note that the skid cube is added based on the number of deep positions.
-- This means if only 1 case was in a 2 deep pushback the skid cube is
-- added twice.  Should the skid cube added be based on the qoh/qty planned
-- and the ti hi is an open question.
-- 
-- 02/14/06  prpbcb  Added width_positions and total_positions.
-- The total positions is the same as the deep positions.  If we get to
-- the point where the width positions is used then the total positions
-- will need to be set to width_positions * deep_positions.
-- 
-- 06/01/07 prpbcb  Put in separate fields the cube occupied by the
--                  qoh + qty alloc and the cube occupied by the skid.
--                  Before they were combined in a field called "cube_used".
--                  This is to allow the calling program more control in
--                  determining the occupied cube in the slot.  The
--                  "qty_occupied_cube" is the cube of the qoh + qty planned.
--                  The "skids_in_slot" is the number if skids in the slot
--                  based on the qty and Ti Hi.  It will be same as the
--                  "positions_occupied".
--
CURSOR g_c_case_home_slots
               (cp_r_item_info  pl_rcv_open_po_types.t_r_item_info) IS
   SELECT l.logi_loc                  logi_loc,
          l.slot_type                 slot_type,
          l.pallet_type               pallet_type,
          l.rank                      rank,
          l.uom                       uom,
          l.perm                      perm,
          l.put_aisle                 put_aisle,
          l.put_slot                  put_slot,
          l.put_level                 put_level,
          NVL(l.cube, 0)              cube,
          l.available_height          available_height,
          l.occupied_height           occupied_height,
          NVL(l.slot_height, 0)       slot_height,
          l.true_slot_height          true_slot_height,
          l.liftoff_height            liftoff_height,
          l.status                    status,
          NVL(l.width_positions, 0)   width_positions,
          NVL(st.deep_ind, 'N')       deep_ind,
          st.deep_positions           deep_positions,
          st.deep_positions           total_positions,
          l.cube / st.deep_positions  position_cube,
          i.qoh,           -- Used in checking if a pallet can go to home.
          i.qty_planned,   -- Used in checking if a pallet can go to home.
          ((i.qoh + i.qty_planned) / cp_r_item_info.spc) *
                cp_r_item_info.case_cube                  qty_occupied_cube,
          CEIL((i.qoh + i.qty_planned) /
   (cp_r_item_info.spc * cp_r_item_info.ti * cp_r_item_info.hi))
                                                          skids_in_slot,
          CEIL((i.qoh + i.qty_planned) /
   (cp_r_item_info.spc * cp_r_item_info.ti * cp_r_item_info.hi))
                                                          positions_occupied,
          z.zone_id,  -- Case home PUT zone
          z.rule_id   -- Case home PUT zone rule id
     FROM slot_type st,
          zone      z,
          lzone     lz,
          inv       i,
          loc       l
    WHERE l.prod_id           = cp_r_item_info.prod_id
      AND l.cust_pref_vendor  = cp_r_item_info.cust_pref_vendor
      AND l.perm              = 'Y'
      AND l.uom               IN (0, 2)
      AND st.slot_type        = l.slot_type
      AND lz.logi_loc         = l.logi_loc
      AND z.zone_id           = lz.zone_id
      AND z.zone_type         = 'PUT'
      AND i.plogi_loc         = l.logi_loc
      AND l.rank              = 1
    ORDER BY l.rank;


--------------------------------------------------------------------------
-- Cursor g_c_loc_info
--------------------------------------------------------------------------
-- The cursor select location info and is used when the item is a
-- floating item.
--
-- 02/14/06  prpbcb  Added width_positions and total_positions.
-- The total positions is the same as the deep positions.  If we get to
-- the point where the width positions is used then the total positions
-- will need to be set to width_positions * deep_positions.
--
-- 05/05/06  prpbcb  Added true_slot_height.
--
CURSOR g_c_loc_info(cp_logi_loc  loc.logi_loc%TYPE) IS
   SELECT l.cube               cube,
          l.true_slot_height   true_slot_height,
          l.put_aisle          put_aisle,
          l.put_slot           put_slot,
          l.put_level          put_level,
          l.width_positions    width_positions,
          lz.zone_id           zone_id,
          z.rule_id            rule_id,
          st.deep_positions    deep_positions,
          st.deep_positions    total_positions
     FROM slot_type st,
          zone      z,
          lzone     lz,
          loc       l
    WHERE st.slot_type = l.slot_type
      AND l.logi_loc   = cp_logi_loc
      AND lz.logi_loc  = l.logi_loc
      AND z.zone_id    = lz.zone_id
      AND z.zone_type  = 'PUT';


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    non_deep_slots
--
-- Description:
--    This procedure assigns the desigated select stmt for candidate
--    non-deep slots.  A REF CURSOR is returned.
---------------------------------------------------------------------------
PROCEDURE non_deep_slots
 (i_what_locations             IN     VARCHAR2,
  i_r_syspars                  IN     pl_rcv_open_po_types.t_r_putaway_syspars,
  i_r_item_info                IN     pl_rcv_open_po_types.t_r_item_info,
  i_r_pallet                   IN     pl_rcv_open_po_types.t_r_pallet,
  i_zone_id                    IN     zone.zone_id%TYPE,
  i_chk_rsrv_cube_ge_home_cube IN     VARCHAR2,
  i_chk_rsrv_hgt_ge_home_hgt   IN     VARCHAR2,
  io_curvar_locations          IN OUT pl_rcv_open_po_types.t_refcur_location);


---------------------------------------------------------------------------
-- Procedure:
--    deep_slots
--
-- Description:
--    This procedure assigns the desigated select stmt for candidate
--    deep slots.  A REF CURSOR is returned.
---------------------------------------------------------------------------
PROCEDURE deep_slots
   (i_what_locations           IN     VARCHAR2,
    i_r_syspars                IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info              IN     pl_rcv_open_po_types.t_r_item_info,
    i_r_pallet                 IN     pl_rcv_open_po_types.t_r_pallet,
    i_zone_id                  IN     zone.zone_id%TYPE,
    io_curvar_locations        IN OUT pl_rcv_open_po_types.t_refcur_location);


---------------------------------------------------------------------------
-- Procedure:
--    floating_slots
--
-- Description:
--    This procedure selects the candidate floating slots.  A REF CURSOR
--    is returned.
---------------------------------------------------------------------------
PROCEDURE floating_slots
   (i_r_syspars                IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info              IN     pl_rcv_open_po_types.t_r_item_info,
    i_r_pallet                 IN     pl_rcv_open_po_types.t_r_pallet,
    i_zone_id                  IN     zone.zone_id%TYPE,
    i_direct_only_to_open_slot IN     VARCHAR2,
    io_curvar_locations        IN OUT pl_rcv_open_po_types.t_refcur_location);


---------------------------------------------------------------------------
-- Procedure:
--    bulk_rule_slots
--
-- Description:
--    This procedure assigns the desigated select stmt for candidate
--    bulk rule slots.  A REF CURSOR is returned.
---------------------------------------------------------------------------
PROCEDURE bulk_rule_slots
   (i_what_locations           IN     VARCHAR2,
    i_r_syspars                IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info              IN     pl_rcv_open_po_types.t_r_item_info,
    i_r_pallet                 IN     pl_rcv_open_po_types.t_r_pallet,
    i_zone_id                  IN     zone.zone_id%TYPE,
    io_curvar_locations        IN OUT pl_rcv_open_po_types.t_refcur_location);

END pl_rcv_open_po_cursors;  -- end package specification
/

SHOW ERRORS



--------------------------------------------------------------------------
-- Package Body
--------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY swms.pl_rcv_open_po_cursors
AS

-- sccs_id=@(#) src/schema/plsql/pl_rcv_open_po_cursors.sql, swms, swms.9, 11.2 4/9/10 1.23

---------------------------------------------------------------------------
-- Package Name:
--    pl_put_cursors
--
-- Description:
--    This package has the cursors used to select the candidate putaway
--    slots.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/05 prpbcb   Created.
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_rcv_open_po_cursors';  -- Package name.
                                            --  Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    f_get_inv_qty
--
-- Description:
--    This function returns the qoh + qty_planned for a slot.
--
-- Parameters:
--    i_logi_loc   - The slot to get the qty for.
--    i_erm_id     - PO/SN being processed.  Used in error messages.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - floating_slots()
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/26/05 prpbcb   Created
--    02/13/06 prpbcb   Added parameter i_erm_id to use in error messages.
---------------------------------------------------------------------------
FUNCTION f_get_inv_qty(i_logi_loc  IN loc.logi_loc%TYPE,
                       i_erm_id    IN erm.erm_id%TYPE)
RETURN NUMBER
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_get_inv_qty';

   l_inv_qty   NUMBER;   -- Inventory qty.

   CURSOR c_inv_qty(cp_logi_loc   loc.logi_loc%TYPE) IS
      SELECT NVL(SUM(i.qoh + i.qty_planned), 0)
        FROM inv i
       WHERE i.plogi_loc  = cp_logi_loc;
BEGIN
   OPEN c_inv_qty(i_logi_loc);
   FETCH c_inv_qty INTO l_inv_qty;
   CLOSE c_inv_qty;

   RETURN(l_inv_qty);
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
            || '(i_logi_loc[' || i_logi_loc || ']'
            || ',i_erm_id[' || i_erm_id || '])';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_get_inv_qty;


---------------------------------------------------------------------------
-- End Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
--     NOT USED    NOT USED    NOT USED    NOT USED    NOT USED
--     NOT USED    NOT USED    NOT USED    NOT USED    NOT USED
--     NOT USED    NOT USED    NOT USED    NOT USED    NOT USED
-- Function:
--    f_get_rsrv_slot_occupied_cube
--
-- Description:
--    This function returns the cube occupied in a slot.  It is designed
--    to be used for reserve or floating slots.
--
--    For the skid cube the items pallet type is used if it is not 0
--    otherwise the skid cube of the pallet type for the location is used.
--    The cube of a pallet is round to the nearest ti unless otherwise
--    specified by parameter i_cp_round_cube_to_nearest_ti.
--
--    If is used in the cursors that select the candidate putaway slots.
--
-- Parameters:
--    i_logi_loc   - The slot to find the occupied cube.
--    i_cp_round_cube_to_nearest_ti  - Designates if to round up the cube of
--                                     a pallet to the nearest ti.  The
--                                     default is Y.  If N then the cube is
--                                     rounded up to the nearest case.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - Various cursors.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION f_get_rsrv_slot_occupied_cube
              (i_logi_loc                     IN loc.logi_loc%TYPE,
               i_cp_round_cube_to_nearest_ti  IN VARCHAR2 DEFAULT 'Y')
RETURN NUMBER
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                         '.f_get_rsrv_slot_occupied_cube';

   l_occupied_cube   NUMBER;   -- Cube occupied in the slot

   --
   -- This cursor determines the cube occupied in a slot.  For the skid cube,
   -- the items pallet type is used if it is not 0 otherwise the skid cube
   -- of the pallet type for the location is used.  The cube of a pallet is
   -- round to the nearest ti unless otherwise specified.
   --
   CURSOR c_occupied_cube
               (cp_logi_loc                  loc.logi_loc%TYPE,
                cp_round_cube_to_nearest_ti  VARCHAR2) IS
      SELECT SUM(DECODE(SIGN(i.qoh + i.qty_planned),
                              0, 0,   -- Slot is empty so no skid cube.
                              DECODE(pt1.skid_cube,
                                     0, pt2.skid_cube,
                                     pt1.skid_cube)) +
             DECODE(cp_round_cube_to_nearest_ti,
                    'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                             pm.ti * pm.case_cube,
                    CEIL((i.qoh + i.qty_planned) / pm.spc) * pm.case_cube))
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             inv i,
             loc loc     -- To get the pallet type of the location
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND i.plogi_loc         = cp_logi_loc
         AND loc.logi_loc        = cp_logi_loc
       GROUP BY loc.logi_loc;
BEGIN
   OPEN c_occupied_cube(i_logi_loc, i_cp_round_cube_to_nearest_ti);
   FETCH c_occupied_cube INTO l_occupied_cube;
   IF (c_occupied_cube%NOTFOUND) then
      l_occupied_cube := 0;
   END IF;
   CLOSE c_occupied_cube;

   RETURN(l_occupied_cube);
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
            || '(i_logi_loc[' || i_logi_loc || ']'
            || 'i_cp_round_cube_to_nearest_ti['
            || i_cp_round_cube_to_nearest_ti || '])';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_get_rsrv_slot_occupied_cube;


---------------------------------------------------------------------------
-- Procedure:
--    non_deep_slots
--
-- Description:
--    This procedure assigns the desigated select stmt for candidate
--    non-deep reserve slots.  A REF CURSOR is returned.
--
-- Parameters:
--    i_what_locations     - Designates what locations to select.
--                           The valid values are:
--                              'OPEN'
--                              'SAME_ITEM'
--                              'ANY_NON_EMPTY_LOCATION'
--    i_r_syspars          - Syspars
--    i_r_item_info        - Item information.
--    i_r_pallet           - Pallet information.
--    i_zone_id            - The zone to look for slots in.
--    i_chk_rsrv_cube_ge_home_cube - Designates if the cube of the candidate
--                                   slots have to be >= home slot cube when
--                                   putaway is by cube.
--                                   It only applies when looking at open slots.
--                                   There is a syspar for this but there is
--                                   special processing when receiving splits
--                                   that occurs that may result in
--                                   the value being different from the syspar.
--    i_chk_rsrv_hgt_ge_home_hgt  -  Designates if the height of the candidate
--                                   slots have to be >= home slot height when
--                                   putaway is by inches.
--                                   It only applies when looking at open slots.
--                                   There is a syspar for this but there is
--                                   special processing when receiving splits
--                                   that occurs that may result in
--                                   the value being different from the syspar.
--    io_curvar_locations  - Cursor variable pointing to the appropriate
--                           select stmt.
--
-- Exceptions raised:
--    pl_exc.ct_data_error     - Bad parameter.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - x
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
--    03/24/06 prpbcb   Removed the check of reserve slot cube >= home
--                      slot cube when selecting open reserve slots and
--                      putaway is by inches.  This check should not be made
--                      when putaway is by inches.  This was a bug.
--    05/02/07 prpbcb   Implement logic in the where clause for pm.pallet_stack
--                      when selecting occupied slots.  It was missed when
--                      pallet_label2.pc was converted to PL/SQL.
---------------------------------------------------------------------------
PROCEDURE non_deep_slots
 (i_what_locations             IN     VARCHAR2,
  i_r_syspars                  IN     pl_rcv_open_po_types.t_r_putaway_syspars,
  i_r_item_info                IN     pl_rcv_open_po_types.t_r_item_info,
  i_r_pallet                   IN     pl_rcv_open_po_types.t_r_pallet,
  i_zone_id                    IN     zone.zone_id%TYPE,
  i_chk_rsrv_cube_ge_home_cube IN     VARCHAR2,
  i_chk_rsrv_hgt_ge_home_hgt   IN     VARCHAR2,
  io_curvar_locations          IN OUT pl_rcv_open_po_types.t_refcur_location)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name || '.non_deep_slots';

   e_bad_parameter  EXCEPTION;  -- Bad parameter.

BEGIN

   IF (i_what_locations = pl_rcv_open_po_types.ct_open_slot) THEN
      /*******************************************************************/
      -- Select open non-deep reserve slots in the specified zone.
      /*******************************************************************/
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- The slot is empty so the cube used is 0
          lz.zone_id
     FROM slot_type  st,
          lzone      lz,
          loc        l
    WHERE lz.zone_id             = i_zone_id
      AND l.perm                 = 'N'
      AND l.status               = 'AVL'
      AND l.logi_loc             = lz.logi_loc
      AND st.slot_type           = l.slot_type
      AND NVL(st.deep_ind, 'N')  = 'N'
      --
      -- Select slots big enough
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
               ROUND(l.cube, 2) >=  i_r_pallet.cube_with_skid)
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Select empty slots
      --
      AND NOT EXISTS
               (SELECT 'x'
                  FROM inv i
                 WHERE i.plogi_loc = lz.logi_loc)
      --
      -- Match by pallet type or slot type depending on the syspar setting.
      --
      AND (   (i_r_syspars.pallet_type_flag = 'Y' AND
               (l.pallet_type = i_r_item_info.pallet_type
                OR l.pallet_type IN
                        (SELECT mixed_pallet
                           FROM pallet_type_mixed pmix
                          WHERE pmix.pallet_type = i_r_item_info.pallet_type)))
           OR (i_r_syspars.pallet_type_flag = 'N' AND
               l.slot_type = i_r_item_info.case_home_slot_slot_type)
          )
      --
      -- Force the open slot cube to be >= home slot cube or height if
      -- putaway by inches depending on the parameter.  Round the cube to
      -- 2 decimal places in the comparison.
      --

      AND (   (i_r_syspars.putaway_dimension = 'C'
               AND (  (i_chk_rsrv_cube_ge_home_cube = 'Y' AND
                       ROUND(l.cube, 2) >= i_r_item_info.case_home_slot_cube)
                    OR (i_chk_rsrv_cube_ge_home_cube = 'N')))
           OR (i_r_syspars.putaway_dimension = 'I'
               AND (  (i_chk_rsrv_hgt_ge_home_hgt = 'Y' AND
                       l.true_slot_height >=
                                 i_r_item_info.case_home_slot_true_slot_hgt)
                    OR (i_chk_rsrv_hgt_ge_home_hgt = 'N')))
          )
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                       'I', l.available_height,
                                       l.cube),
                            0)),
            ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
            ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
            ABS(i_r_item_info.put_level - l.put_level), l.put_level;

   ELSIF (i_what_locations = pl_rcv_open_po_types.ct_same_item_slot) THEN
      ----------------------------------------------------------------------
      -- Select non-empty non-deep reserve slots in the specified zone that
      -- have at least one pallet of the item being processed.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type  st,
          lzone      lz,
          loc        l
    WHERE lz.zone_id                = i_zone_id
      AND l.perm                    = 'N'
      AND l.status                  = 'AVL'
      AND l.logi_loc                = lz.logi_loc
      AND st.slot_type              = l.slot_type
      AND NVL(st.deep_ind, 'N')     = 'N'
      --
      -- Only look at slots that have at least one pallet of the item being
      -- processed.
      --
      AND EXISTS
           (SELECT 'x'
              FROM inv i1
             WHERE i1.plogi_loc        = lz.logi_loc
               AND i1.prod_id          = i_r_item_info.prod_id
               AND i1.cust_pref_vendor = i_r_item_info.cust_pref_vendor)
      --
      -- Select slots big enough.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
               (ROUND(l.cube, 2) - i_r_pallet.cube_with_skid) >=
     ----------------------------------------------------------------
     (SELECT ROUND(SUM(DECODE(pt1.skid_cube, 0, pt2.skid_cube,
                                       pt1.skid_cube) +
              DECODE(i_r_item_info.round_inv_cube_up_to_ti_flag,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                      i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                                       i_r_item_info.case_cube_for_calc,
                                       pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) * 
                       DECODE(i.prod_id || i.cust_pref_vendor,
                  i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                              i_r_item_info.case_cube_for_calc,
                              pm.case_cube))), 2)     occupied_cube
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             loc loc,    -- To get the pallet type of the location
             inv i
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND loc.logi_loc        = i.plogi_loc
         AND I.plogi_loc         = l.logi_loc
       GROUP BY i.plogi_loc))
      ---------------------------------------------------------------
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Match by pallet type or slot type depending on the syspar setting.
      --
      AND (   (i_r_syspars.pallet_type_flag = 'Y' AND
               (l.pallet_type = i_r_item_info.pallet_type
                OR l.pallet_type IN
                        (SELECT mixed_pallet
                           FROM pallet_type_mixed pmix
                          WHERE pmix.pallet_type = i_r_item_info.pallet_type)))
           OR (i_r_syspars.pallet_type_flag = 'N' AND
               l.slot_type = i_r_item_info.case_home_slot_slot_type)
          )
      --
      -- Stackability
      --
      AND i_r_item_info.stackable > 0
      AND NOT EXISTS (SELECT 'x'
                        FROM pm p2, inv si
                       WHERE p2.prod_id          = si.prod_id
                         AND p2.cust_pref_vendor = si.cust_pref_vendor
                         AND si.plogi_loc        = lz.logi_loc
                         AND (p2.stackable > i_r_item_info.stackable
                              OR p2.stackable = 0))
      --
      -- Cannot have a MSKU in the slot.
      --
      AND NOT EXISTS (SELECT 'x'
                        FROM inv inv_msku
                       WHERE inv_msku.plogi_loc        = lz.logi_loc
                         AND inv_msku.parent_pallet_id IS NOT NULL)
      --
      -- Only select location if the items pallet stack (pm.pallet_stack) is
      -- greater than the number of existing pallets in the location.  If the
      -- pallet stack is set to the "magic" number then ignore the pallet stack 
      -- which should keep the query on the INV table from being made which
      -- should save some execution time.
      --
      AND (i_r_item_info.pallet_stack = i_r_item_info.pallet_stack_magic_num
           OR i_r_item_info.pallet_stack >
                                 (SELECT COUNT(*)
                                    FROM inv psi
                                   WHERE psi.plogi_loc  = lz.logi_loc)
          )
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                       'I', l.available_height,
                                       l.cube),
                            0)),
            ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
            ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
            ABS(i_r_item_info.put_level - l.put_level), l.put_level;

   ELSIF (i_what_locations = pl_rcv_open_po_types.ct_any_non_empty_slot) THEN
      ----------------------------------------------------------------------
      -- Select available non-deep reserve slots in the specified zone.
      -- Any item can be in the slot.
      -- These are the last slots checked for a non-deep item.
      -- The slot needs to be non-empty.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type  st,
          lzone      lz,
          loc        l
    WHERE lz.zone_id                = i_zone_id
      AND l.perm                    = 'N'
      AND l.status                  = 'AVL'
      AND l.logi_loc                = lz.logi_loc
      AND st.slot_type              = l.slot_type
      AND NVL(st.deep_ind, 'N')     = 'N'
      --
      -- Select slots big enough.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
               (ROUND(l.cube, 2) - i_r_pallet.cube_with_skid) >=
     ----------------------------------------------------------------
     (SELECT ROUND(SUM(DECODE(pt1.skid_cube, 0, pt2.skid_cube,
                                       pt1.skid_cube) +
              DECODE(i_r_item_info.round_inv_cube_up_to_ti_flag,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                      i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                                       i_r_item_info.case_cube_for_calc,
                                       pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) * 
                       DECODE(i.prod_id || i.cust_pref_vendor,
                  i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                              i_r_item_info.case_cube_for_calc,
                              pm.case_cube))), 2)     occupied_cube
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             loc loc,    -- To get the pallet type of the location
             inv i
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND loc.logi_loc        = i.plogi_loc
         AND I.plogi_loc         = l.logi_loc
       GROUP BY i.plogi_loc))
      ---------------------------------------------------------------
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Match by pallet type or slot type depending on the syspar setting.
      --
      AND (   (i_r_syspars.pallet_type_flag = 'Y' AND
               (l.pallet_type = i_r_item_info.pallet_type
                OR l.pallet_type IN
                        (SELECT mixed_pallet
                           FROM pallet_type_mixed pmix
                          WHERE pmix.pallet_type = i_r_item_info.pallet_type)))
           OR (i_r_syspars.pallet_type_flag = 'N' AND
               l.slot_type = i_r_item_info.case_home_slot_slot_type)
          )
      --
      -- Stackability
      --
      AND i_r_item_info.stackable > 0
      AND NOT EXISTS (SELECT 'x'
                        FROM pm p2, inv si
                       WHERE p2.prod_id          = si.prod_id
                         AND p2.cust_pref_vendor = si.cust_pref_vendor
                         AND si.plogi_loc        = lz.logi_loc
                         AND (p2.stackable > i_r_item_info.stackable
                              OR p2.stackable = 0))
      --
      -- Select non-empty slots
      --
      AND EXISTS
               (SELECT 'x'
                  FROM inv i
                 WHERE i.plogi_loc = lz.logi_loc)
      --
      -- Cannot have a MSKU in the slot.
      --
      AND NOT EXISTS (SELECT 'x'
                        FROM inv inv_msku
                       WHERE inv_msku.plogi_loc        = lz.logi_loc
                         AND inv_msku.parent_pallet_id IS NOT NULL)
      --
      -- Only select location if the items pallet stack (pm.pallet_stack) is
      -- greater than the number of existing pallets in the location.  If the
      -- pallet stack is set to the "magic" number then ignore the pallet stack 
      -- which should keep the query on the INV table from being made which
      -- should save some execution time.
      --
      AND (i_r_item_info.pallet_stack = i_r_item_info.pallet_stack_magic_num
           OR i_r_item_info.pallet_stack >
                                (SELECT COUNT(*)
                                   FROM inv psi
                                  WHERE psi.plogi_loc  = lz.logi_loc)
          )
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                      'I', l.available_height,
                                      l.cube),
                            0)),
            ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
            ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
            ABS(i_r_item_info.put_level - l.put_level), l.put_level;
   ELSE
      -- i_what_locations has an unhandled value.  This is an error.
      RAISE e_bad_parameter;
   END IF;

EXCEPTION
   WHEN e_bad_parameter THEN
      l_message :=
         'LP[' || i_r_pallet.pallet_id || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_what_locations[' || i_what_locations || ']'
         || ' has an unhandled value.  This stops processing.';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_what_locations,i_r_syspars,i_r_item_info,i_r_pallet'
         || 'i_zone_id,i_chk_rsrv_cube_ge_home_cube,'
         || 'i_chk_rsrv_hgt_ge_home_hgt,io_curvar_locations)'
         || '  i_what_locations[' || i_what_locations || ']'
         || '  LP[' || i_r_pallet.pallet_id || ']'
         || '  Item[' || i_r_pallet.prod_id || ']'
         || '  CPV[' || i_r_pallet.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END non_deep_slots;


---------------------------------------------------------------------------
-- Procedure:
--    deep_slots
--
-- Description:
--    This procedure assigns the desigated select stmt for candidate
--    deep reserve slots.  A REF CURSOR is returned.
--
-- Parameters:
--    i_what_locations     - Designates what locations to select.
--                           The valid values are:
--                              'SAME_ITEM'
--                              'OPEN'
--                              'DIFFERENT_ITEM'
--    i_r_syspars          - Syspars
--    i_r_item_info        - Item information.
--    i_r_pallet           - Pallet information.
--    i_zone_id            - The zone to look for slots in.
--    io_curvar_locations  - Cursor variable pointing to the appropriate
--                           select stmt.
--
-- Exceptions raised:
--    pl_exc.ct_data_error     - Bad parameter.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - x
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
--    10/18/05 prpbcb   Changed  l.cube to l.cube / st.deep_positions in
--                      the order by clause.
---------------------------------------------------------------------------
PROCEDURE deep_slots
   (i_what_locations           IN     VARCHAR2,
    i_r_syspars                IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info              IN     pl_rcv_open_po_types.t_r_item_info,
    i_r_pallet                 IN     pl_rcv_open_po_types.t_r_pallet,
    i_zone_id                  IN     zone.zone_id%TYPE,
    io_curvar_locations        IN OUT pl_rcv_open_po_types.t_refcur_location)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name || '.deep_slots';

   e_bad_parameter  EXCEPTION;  -- Bad parameter.

BEGIN
   IF (i_what_locations = pl_rcv_open_po_types.ct_same_item_slot) THEN
      ----------------------------------------------------------------------
      -- Select the candidate deep slots in the specified zone that
      -- are occupied with one or more pallets of the item being processed
      -- and if syspar MIX_SAME_PROD_DEEP_SLOT is 'N' then the pallets in
      -- the slot must all have the same receive date as the pallet being
      -- processed.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type        st,
          lzone            lz,
          loc              l
    WHERE lz.zone_id               = i_zone_id
      AND l.perm                   = 'N'
      AND l.status                 = 'AVL'
      AND l.logi_loc               = lz.logi_loc
      AND st.slot_type             = l.slot_type
      AND st.deep_ind              = 'Y'            -- Select only deep slots
      --
      -- Only look at slots that have at least one pallet of the item being
      -- processed.
      --
      AND EXISTS
           (SELECT 'x'
              FROM inv i1
             WHERE i1.plogi_loc        = lz.logi_loc
               AND i1.prod_id          = i_r_item_info.prod_id
               AND i1.cust_pref_vendor = i_r_item_info.cust_pref_vendor)
      --
      -- Allow/do not allow mixing different receive dates for the item
      -- depending on the syspar setting.
      -- The pallet being assigned a location does not have the inventory
      -- record created yet which is why SYSDATE is used.  When the inventory
      -- record is created the receive date is set to the SYSDATE.
      -- 02/09/06 prpbcb Changed to handle a null inv.rec_date.
      --
      AND (   i_r_syspars.mix_same_prod_deep_slot = 'Y'
           OR NOT EXISTS
             (SELECT 'x'
                FROM inv i2
               WHERE i2.plogi_loc        = lz.logi_loc
                 AND i2.prod_id          = i_r_item_info.prod_id
                 AND i2.cust_pref_vendor = i_r_item_info.cust_pref_vendor
                 AND TRUNC(NVL(i2.rec_date, SYSDATE)) != TRUNC(SYSDATE))
          )
      --
      -- Exclude the location if there is a different item in the location.
      --
      AND NOT EXISTS
           (SELECT 'x'
              FROM inv i3
             WHERE i3.plogi_loc            = lz.logi_loc
               AND (i3.prod_id             != i_r_item_info.prod_id
                    OR i3.cust_pref_vendor != i_r_item_info.cust_pref_vendor))
      --
      -- Select slots big enough.
      -- A position within the slot needs to be large enough for a pallet.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
          ROUND(l.cube / st.deep_positions, 2) >= i_r_pallet.cube_with_skid AND
               (ROUND(l.cube, 2) - i_r_pallet.cube_with_skid) >=
     ----------------------------------------------------------------
     (SELECT ROUND(SUM(DECODE(pt1.skid_cube, 0, pt2.skid_cube,
                                       pt1.skid_cube) +
              DECODE(i_r_item_info.round_inv_cube_up_to_ti_flag,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                      i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                                       i_r_item_info.case_cube_for_calc,
                                       pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) * 
                       DECODE(i.prod_id || i.cust_pref_vendor,
                  i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                              i_r_item_info.case_cube_for_calc,
                              pm.case_cube))), 2)     occupied_cube
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             loc loc,    -- To get the pallet type of the location
             inv i
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND loc.logi_loc        = i.plogi_loc
         AND I.plogi_loc         = l.logi_loc
       GROUP BY i.plogi_loc))
      ---------------------------------------------------------------
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid AND
               l.slot_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Match by slot type or deep indicator depending on the syspar.
      --
      AND (   (i_r_syspars.putaway_to_any_deep_slot = 'Y')
           OR (i_r_syspars.putaway_to_any_deep_slot = 'N' AND
               l.slot_type = i_r_item_info.case_home_slot_slot_type)
          )
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube / st.deep_positions),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                       'I', l.available_height,
                                       l.cube / st.deep_positions),
                           0)),
            ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
            ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
            ABS(i_r_item_info.put_level - l.put_level), l.put_level;

   ELSIF (i_what_locations = pl_rcv_open_po_types.ct_open_slot) THEN
      ----------------------------------------------------------------------
      -- Select open deep reserve slots in the specified zone.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- The slot is empty so the cube used is 0
          lz.zone_id
     FROM slot_type  st,
          lzone      lz,
          loc        l
    WHERE lz.zone_id             = i_zone_id
      AND l.perm                 = 'N'
      AND l.status               = 'AVL'
      AND l.logi_loc             = lz.logi_loc
      AND st.slot_type           = l.slot_type
      AND st.deep_ind            = 'Y'
      AND NVL(st.deep_ind, 'N')  = i_r_item_info.case_home_slot_deep_ind
      --
      -- Select slots big enough
      -- A position within the slot needs to be large enough for a pallet.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
            ROUND(l.cube / st.deep_positions, 2)  >= i_r_pallet.cube_with_skid)
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid AND
               l.slot_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Select empty slots
      --
      AND NOT EXISTS
               (SELECT 'x'
                  FROM inv i
                 WHERE i.plogi_loc = lz.logi_loc)
      --
      -- Match by slot type or deep indicator depending on the syspar.
      --
      AND (   (i_r_syspars.putaway_to_any_deep_slot = 'Y')
           OR (i_r_syspars.putaway_to_any_deep_slot = 'N' AND
               l.slot_type = i_r_item_info.case_home_slot_slot_type)
          )
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube / st.deep_positions),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                       'I', l.available_height,
                                       l.cube / st.deep_positions),
                           0)),
             ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
             ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
             ABS(i_r_item_info.put_level - l.put_level), l.put_level;

   ELSIF (i_what_locations = pl_rcv_open_po_types.ct_different_item_slot) THEN
      ----------------------------------------------------------------------
      -- Select the candidate deep slots in the specified zone with
      -- different items if syspar MIXPROD_2D3D_FLAG is 'Y'.  If the syspar
      -- is 'N' then no slots will be selected.
      --
      -- It is possible for the slot to have a different item and a pallet
      -- of the item currently being processed.
      --
      -- Use this only for items with deep home slots.  If used by a
      -- non-deep item then no records will be selected.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type         st,
          lzone             lz,
          loc               l
    WHERE lz.zone_id               = i_zone_id
      AND l.perm                   = 'N'
      AND l.status                 = 'AVL'
      AND l.logi_loc               = lz.logi_loc
      AND st.slot_type             = l.slot_type
      AND st.deep_ind              = 'Y'            -- Select only deep slots
      --
      -- Allow mixing of different items needs to be 'Y'.
      --
      AND i_r_syspars.mixprod_2d3d_flag = 'Y'
      --
      -- The slots needs to have a pallet of a different item.
      -- processed.
      --
      AND EXISTS 
           (SELECT 'x'
              FROM inv i1
             WHERE i1.plogi_loc            = lz.logi_loc
               AND (i1.prod_id             != i_r_item_info.prod_id
                    OR i1.cust_pref_vendor != i_r_item_info.cust_pref_vendor))
      --
      -- Allow/do not allow mixing different receive dates for the item
      -- depending on the syspar setting.
      -- The pallet being assigned a location does not have the inventory
      -- record created yet which is why SYSDATE is used.  When the inventory
      -- record is created the receive date is set to the SYSDATE.
      -- 02/09/06 prpbcb Changed to handle a null inv.rec_date.
      --
      AND (   i_r_syspars.mix_same_prod_deep_slot = 'Y'
           OR NOT EXISTS
             (SELECT 'x'
                FROM inv i2
               WHERE i2.plogi_loc        = lz.logi_loc
                 AND i2.prod_id          = i_r_item_info.prod_id
                 AND i2.cust_pref_vendor = i_r_item_info.cust_pref_vendor
                 AND TRUNC(NVL(i2.rec_date, SYSDATE)) != TRUNC(SYSDATE))
          )
      --
      -- Select slots big enough.
      -- A position within the slot needs to be large enough for a pallet.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
           ROUND(l.cube / st.deep_positions, 2) >= i_r_pallet.cube_with_skid AND
               (ROUND(l.cube, 2) - i_r_pallet.cube_with_skid) >=
     ----------------------------------------------------------------
     (SELECT ROUND(SUM(DECODE(pt1.skid_cube, 0, pt2.skid_cube,
                                       pt1.skid_cube) +
              DECODE(i_r_item_info.round_inv_cube_up_to_ti_flag,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                      i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                                       i_r_item_info.case_cube_for_calc,
                                       pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) * 
                       DECODE(i.prod_id || i.cust_pref_vendor,
                  i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                              i_r_item_info.case_cube_for_calc,
                              pm.case_cube))), 2)     occupied_cube
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             loc loc,    -- To get the pallet type of the location
             inv i
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND loc.logi_loc        = i.plogi_loc
         AND I.plogi_loc         = l.logi_loc
       GROUP BY i.plogi_loc))
      ---------------------------------------------------------------
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid AND
               l.slot_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Match by slot type or deep indicator depending on the syspar.
      --
      AND (   (i_r_syspars.putaway_to_any_deep_slot = 'Y')
           OR (i_r_syspars.putaway_to_any_deep_slot = 'N' AND
               l.slot_type = i_r_item_info.case_home_slot_slot_type)
          )
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube / st.deep_positions),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                      'I', l.available_height,
                                      l.cube / st.deep_positions),
                           0)),
             ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
             ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
             ABS(i_r_item_info.put_level - l.put_level), l.put_level;

   ELSE
      -- i_what_locations has an unhandled value.  This is an error.
      RAISE e_bad_parameter;
   END IF;

EXCEPTION
   WHEN e_bad_parameter THEN
      l_message :=
         'LP[' || i_r_pallet.pallet_id || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_what_locations[' || i_what_locations || ']'
         || ' has an unhandled value.  This stops processing.';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_what_locations,i_r_syspars,i_r_item_info,i_r_pallet'
         || 'i_zone_id,io_curvar_locations)'
         || '  i_what_locations[' || i_what_locations || ']'
         || '  LP[' || i_r_pallet.pallet_id || ']'
         || '  Item[' || i_r_pallet.prod_id || ']'
         || '  CPV[' || i_r_pallet.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END deep_slots;


---------------------------------------------------------------------------
-- Procedure:
--    floating_slots
--
-- Description:
--    This procedure selects the candidate floating slots.  A REF CURSOR
--    is returned.
--
--    It is expected that a floating slot will not be a deep slot but if
--    it is things will still work correctly.
--
--    Only empty slots are selected except when syspar
--    non_fifo_combine_plts_in_float is set to Y in which case occupied slots
--    are also selected but only if the item being received is not a FIFO
--    item and the pallet(s) in the slot are all the same item as the item
--    being received.
--
--    Syspar floating_slot_sort_order controls the sort order when syspar
--    non_fifo_combine_plts_in_float is Y.  This allows the user to control
--    if occupied slots are checked first or checked last.  When syspar
--    non_fifo_combine_plts_in_float is N syspar floating_slot_sort_order has
--    no affect.
--       Value  Floating Slot Sort Order
--       -----  ---------------------------------------------
--         1    Occupied slots followed by empty slots.
--         2    Empty slots followed by occupied slots.
--
--    The pallet type cross reference is not used for floating items except
--    for miniload items and the pallet is being directed to reserve in the
--    main warehouse and the item has cases stored in the miniloader.
--
-- Parameters:
--    i_r_syspars                - Putaway syspars.
--    i_r_item_info              - Item information.
--    i_r_pallet                 - Pallet information.
--    i_zone_id                  - The zone to look for slots in.
--    i_direct_only_to_open_slot - Designates if to select only open slots.
--                                 This should be Y when receiving splits
--                                 otherwise it should be N.
--    io_curvar_locations        - Cursor variable pointing to the select stmt.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - x
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
--    02/22/06 prpbcb   Modified to use new syspar floating_slot_sort_order 
--                      to control how the locations are sorted and to
--                      check that the putaway pallet will fit when looking
--                      at an occupied slot.
--    05/02/06 prpbcb   Fix order by.  The slot with the smallest available
--                      cube was not selected first.  The previous version
--                      broke it.
--                  ***** Syspar floating_slot_sort_order not used yet. *****
--    07/20/06 prpbcb   Change where clause to look at new syspar
--                      CHK_FLOAT_CUBE_GE_LSS_CUBE.
--    05/05/07 prpbcb   Change where clause to look at new syspar
--                      CHK_FLOAT_HGT_GE_LSS_HGT.
--
--                      Add logic for putaway by max qty.
--                      Add logic for floating_slot_sort_order.
--    04/07/10 prpbcb   Modified to use the pallet type cross reference for
--                      miniload items with casess in the miniloader and the
--                      pallet is directed to reserve in the main warehouse.
--    07/10/18 mpha8134 Meat Company Project Jira-438: 
--                          -Add logic for the overflow/catch-all floating location
--                          for the Meat company.
---------------------------------------------------------------------------
PROCEDURE floating_slots
   (i_r_syspars                IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info              IN     pl_rcv_open_po_types.t_r_item_info,
    i_r_pallet                 IN     pl_rcv_open_po_types.t_r_pallet,
    i_zone_id                  IN     zone.zone_id%TYPE,
    i_direct_only_to_open_slot IN     VARCHAR2,
    io_curvar_locations        IN OUT pl_rcv_open_po_types.t_refcur_location)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name || '.floating_slots';
BEGIN
   ----------------------------------------------------------------------
   -- Select the candidate floating slots in the specified zone.
   --
   -- Note: 05/02/06 prpbcb  There is some duplication of logic in the
   --       WHERE clause when looking at i_direct_only_to_open_slot 
   --       and i_r_syspars.non_fifo_combine_plts_in_float.
   ----------------------------------------------------------------------
   OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type        st,
          lzone            lz,
          loc              l
    WHERE lz.zone_id          = i_zone_id
      AND l.perm              = 'N'
      AND l.status            = 'AVL'
      AND l.logi_loc          = lz.logi_loc
      AND st.slot_type        = l.slot_type
      --
      -- The pallet type of the slot needs to match the pallet type for
      -- the item except if it is a miniload item with cases in the miniloader
      -- which will use the pallet type cross reference.
      --
      AND (   (l.pallet_type = i_r_item_info.pallet_type)
           OR (i_r_item_info.miniload_storage_ind = 'B' AND
               l.pallet_type IN
                      (SELECT mixed_pallet
                         FROM pallet_type_mixed pmix
                        WHERE pmix.pallet_type = i_r_item_info.pallet_type)))
      --
      -- If putaway is by max qty for a floating item then check that the
      -- qty on the receiving pallet (plus existing inv if pallets can be
      -- combined) is <= max qty (pm.max_qty).
      -- To use max qty for floating items a flag is set at the pallet type
      -- level.  The max qty is the maximum number of cases this will fit
      -- in a slot and comes from the pm.max_qty column.  It works a little
      -- different from a home slot item in that the full qty on the
      -- receiving pallet (plus existing inv if pallets can be combined) must
      -- be <= max qty in order for the receiving pallet to be directed to the
      -- slot.  This means if the qty on the receiving pallet is greater than
      -- the max qty then the pallet will not be directed to a slot.
      --
      AND (   i_r_item_info.pt_putaway_floating_by_max_qty = 'N'
           OR (i_r_item_info.pt_putaway_floating_by_max_qty = 'Y' AND
               ((   i_r_syspars.non_fifo_combine_plts_in_float = 'N' AND
                    i_r_pallet.qty_received <=
                                  (i_r_item_info.max_qty_in_splits)))
                OR (i_r_syspars.non_fifo_combine_plts_in_float = 'Y' AND
                    i_r_pallet.qty_received +
                         f_get_inv_qty(l.logi_loc, i_r_pallet.erm_id) <=
                         (i_r_item_info.max_qty_in_splits))
              )
          )
      --
      -- Select slots big enough if not putting away by max qty.
      -- A position within the slot needs to be large enough for a pallet if
      -- using the putaway dimension--cube or inches.
      --
      -- 05/02/06 prpbcb  When putaway dimension is C,
      -- non_fifo_combine_plts_in_float is checked for Y or N.  This was done
      -- so that the occupied cube calculation select stmt would not need to be
      -- executed when non_fifo_combine_plts_in_float is N (saving a little
      -- execution time???) (I am not sure if the select stmt is executed or
      -- not when non_fifo_combine_plts_in_float is N so maybe it was a waste
      -- of time to check non_fifo_combine_plts_in_float).  The other way to
      -- do this is to always calculate the occupied cube even if
      -- non_fifo_combine_plts_in_float is N.
      --
      AND ((i_r_syspars.putaway_dimension = 'C' AND
           i_r_item_info.pt_putaway_floating_by_max_qty = 'N' AND
           ROUND(l.cube / st.deep_positions, 2) >= i_r_pallet.cube_with_skid AND
           (i_r_syspars.non_fifo_combine_plts_in_float = 'N'
                OR (i_r_syspars.non_fifo_combine_plts_in_float = 'Y'
                    AND (((ROUND(l.cube, 2) - i_r_pallet.cube_with_skid) >=
      ----------------------------------------------------------------
            -- Calculate the occupied cube of the slot rounding the inv
            -- pallet qty to a full Ti if designated.
           (SELECT ROUND(SUM(DECODE(pt1.skid_cube, 0, pt2.skid_cube,
                                       pt1.skid_cube) +
              DECODE(i_r_item_info.round_inv_cube_up_to_ti_flag,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                      i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                                       i_r_item_info.case_cube_for_calc,
                                       pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) * 
                       DECODE(i.prod_id || i.cust_pref_vendor,
                  i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                              i_r_item_info.case_cube_for_calc,
                              pm.case_cube))), 2) occupied_cube
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             loc loc,    -- To get the pallet type of the location
             inv i
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND loc.logi_loc        = i.plogi_loc
         AND i.plogi_loc         = lz.logi_loc
       GROUP BY i.plogi_loc))
      ---------------------------------------------------------------
                           OR NOT EXISTS (SELECT 'x'
                                            FROM inv i
                                           WHERE i.plogi_loc = lz.logi_loc))
                   )
               )
           )
           OR (i_r_syspars.putaway_dimension = 'I' AND
               i_r_item_info.pt_putaway_floating_by_max_qty = 'N' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid AND
               l.slot_height >= i_r_pallet.pallet_height_with_skid)
           OR ( i_r_item_info.pt_putaway_floating_by_max_qty = 'Y')
          )
      --
      -- Select only empty slots if designated to do so.
      -- (there may be a way to combine this with the next stmts)
      -- prpbcb 05/20/06 There is some duplicate of logic between this and
      -- selecting slots big enough above.  I left things separate because
      -- it seemed to be a cleaner approach.
      --
      AND (    (i_direct_only_to_open_slot = 'Y' AND
                NOT EXISTS (SELECT 'x'
                              FROM inv i
                             WHERE i.plogi_loc = lz.logi_loc
							/* -- OPCOF-3339: Removed Location cube limitation to be less than 999 to find empty slot
                               AND EXISTS (
                                   SELECT 1 FROM loc
                                   WHERE loc.cube < 999
                                   AND loc.logi_loc = i.plogi_loc
                               )
                             */ 
                            )
                )
            OR (i_direct_only_to_open_slot = 'N')
          )
      --
      -- If syspar non_fifo_combine_plts_in_float is N then select:
      --    - Empty slots.
      -- If syspar non_fifo_combine_plts_in_float is Y then select:
      --    - Empty slots
      --    - Occupied slots that meet the following criteria:
      --      - The item is a non-FIFO item.
      --      - The slot only has pallets of the item being received.
      --      - Stackable > 0
      --
      AND ( (NOT EXISTS
                       (SELECT 'x'  
                          FROM inv i
                         WHERE i.plogi_loc = lz.logi_loc
						/* -- OPCOF-3339: Removed Location cube limitation to be less than 999 to find empty slot
                           AND EXISTS (
                               SELECT 1 FROM loc
                               WHERE loc.cube < 999
                               AND loc.logi_loc = i.plogi_loc
                           )  
						 */
                        )
            )
           OR (i_r_syspars.non_fifo_combine_plts_in_float = 'Y' AND
               i_r_item_info.fifo_trk = 'N' AND
               i_r_item_info.stackable > 0 AND
               EXISTS
                 (SELECT 'x'
                    FROM inv i
                   WHERE i.plogi_loc        = lz.logi_loc
                     AND i.prod_id          = i_r_item_info.prod_id
                     AND i.cust_pref_vendor = i_r_item_info.cust_pref_vendor)
              AND NOT EXISTS
                (SELECT 'x'
                   FROM inv i2
                  WHERE i2.plogi_loc        = lz.logi_loc
                    AND (i2.prod_id         != i_r_item_info.prod_id
                     OR i2.cust_pref_vendor != i_r_item_info.cust_pref_vendor))
              )
          )
    --
    -- Based on syspar CHK_FLOAT_CUBE_GE_LSS_CUBE, check/not check that
    -- the slot cube is >= last ship ship slot cube when selecting
    -- candidate OPEN floating slots and putaway is by cube.  If the item
    -- already exists in the slot then the slot is considered a candidate slot
    -- regardless of the setting of syspar CHK_FLOAT_CUBE_GE_LSS_CUBE.
    --
    -- Based on syspar CHK_FLOAT_HGT_GE_LSS_HGT, check/not check that
    -- the slot height is >= last ship ship slot height when selecting
    -- candidate OPEN floating slots and putaway is by inches.  If the item
    -- already exists in the slot then the slot is considered a candidate slot
    -- regardless of the setting of syspar CHK_FLOAT_HGT_GE_LSS_HGT.

      AND (     (i_r_syspars.putaway_dimension = 'C' AND
                 ((i_r_syspars.chk_float_cube_ge_lss_cube = 'Y' AND
                    (   ROUND(l.cube, 2) >=
                                ROUND(i_r_item_info.last_ship_slot_cube, 2)
                     OR EXISTS
                        (SELECT 'x'
                           FROM inv i4
                          WHERE i4.plogi_loc        = lz.logi_loc
                            AND i4.prod_id          = i_r_item_info.prod_id
                            AND i4.cust_pref_vendor =
                                             i_r_item_info.cust_pref_vendor)))
                   OR (i_r_syspars.chk_float_cube_ge_lss_cube = 'N'))
                )
           OR (i_r_syspars.putaway_dimension = 'I' AND
                 ((i_r_syspars.chk_float_hgt_ge_lss_hgt = 'Y' AND
                    (   l.true_slot_height >=
                                i_r_item_info.last_ship_slot_height
                     OR EXISTS
                        (SELECT 'x'
                           FROM inv i4
                          WHERE i4.plogi_loc        = lz.logi_loc
                            AND i4.prod_id          = i_r_item_info.prod_id
                            AND i4.cust_pref_vendor =
                                             i_r_item_info.cust_pref_vendor)))
                   OR (i_r_syspars.chk_float_hgt_ge_lss_hgt = 'N'))
              )
          )
    --
    -- Order by the slot with the least available cube first which is done
    -- to handle the situation when syspar non_fifo_combine_plts_in_float
    -- is Y.  This will be done by looking at the qty.  There is no need
    -- to actually calculate the cube since the cube is a function of the
    -- qty and if the slot has a pallet(s) it will always be of the same
    -- item being putaway.
    --
    ORDER BY
DECODE(i_r_syspars.non_fifo_combine_plts_in_float,
       'N', 0,
       DECODE(i_r_item_info.floating_slot_sort_order,
              '1', DECODE(pl_rcv_open_po_cursors.f_get_inv_qty(l.logi_loc,
                                                          i_r_pallet.erm_id),
                          0, 1,
                          0),
              DECODE(pl_rcv_open_po_cursors.f_get_inv_qty(l.logi_loc,
                                                          i_r_pallet.erm_id),
                     0, 0,
                     1))
      ),
             DECODE(i_r_syspars.putaway_dimension,
                    'I', l.available_height,
                    DECODE(i_r_syspars.non_fifo_combine_plts_in_float,
                           'N', l.cube, 0)),
             DECODE(i_r_syspars.non_fifo_combine_plts_in_float,
                  'Y', pl_rcv_open_po_cursors.f_get_inv_qty(l.logi_loc,
                                                            i_r_pallet.erm_id),
                  0),
             ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
             ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
             ABS(i_r_item_info.put_level - l.put_level), l.put_level;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,i_r_item_info,i_r_pallet,i_zone_id,'
         || 'i_direct_only_to_open_slot,io_curvar_locations)'
         || '  LP[' || i_r_pallet.pallet_id || ']'
         || '  Item[' || i_r_pallet.prod_id || ']'
         || '  CPV[' || i_r_pallet.cust_pref_vendor || ']'
         || '  Zone[' || i_zone_id || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END floating_slots;


---------------------------------------------------------------------------
-- Procedure:
--    bulk_rule_slots
--
-- Description:
--    This procedure assigns the desigated select stmt for candidate
--    bulk rule slots.  A REF CURSOR is returned.
--
-- Parameters:
--    i_what_locations     - Designates what locations to select.
--                           The valid values are:
--                              'SAME_ITEM'
--                              'OPEN'
--                              'DIFFERENT_ITEM'
--    i_r_syspars          - Syspars
--    i_r_item_info        - Item information.
--    i_r_pallet           - Pallet information.
--    i_zone_id            - The zone to look for slots in.
--    io_curvar_locations  - Cursor variable pointing to the appropriate
--                           select stmt.
--
-- Exceptions raised:
--    pl_exc.ct_data_error     - Bad parameter.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - x
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE bulk_rule_slots
   (i_what_locations           IN     VARCHAR2,
    i_r_syspars                IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info              IN     pl_rcv_open_po_types.t_r_item_info,
    i_r_pallet                 IN     pl_rcv_open_po_types.t_r_pallet,
    i_zone_id                  IN     zone.zone_id%TYPE,
    io_curvar_locations        IN OUT pl_rcv_open_po_types.t_refcur_location)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name || '.bulk_rule_slots';

   e_bad_parameter  EXCEPTION;  -- Bad parameter.

BEGIN
   IF (i_what_locations = pl_rcv_open_po_types.ct_same_item_slot) THEN
      ----------------------------------------------------------------------
      -- Select the candidate deep slots in the specified zone that
      -- are occupied with one or more pallets of the item being processed.
      --
      -- If syspar MIX_SAME_PROD_DEEP_SLOT is 'N' and it is a deep slot then
      -- the pallets in the slot must all have the same receive date as the
      -- pallet being processed.
      --
      --  There can be other items in the slot.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type        st,
          lzone            lz,
          loc              l
    WHERE lz.zone_id               = i_zone_id
      AND l.perm                   = 'N'
      AND l.status                 = 'AVL'
      AND l.logi_loc               = lz.logi_loc
      AND st.slot_type             = l.slot_type
      --
      -- Only look at slots that have at least one pallet of the item being
      -- processed.
      --
      AND EXISTS
           (SELECT 'x'
              FROM inv i1
             WHERE i1.plogi_loc        = lz.logi_loc
               AND i1.prod_id          = i_r_item_info.prod_id
               AND i1.cust_pref_vendor = i_r_item_info.cust_pref_vendor)
      --
      -- Allow/do not allow mixing different receive dates in deep slots for
      -- and item depending on the syspar setting.
      -- The pallet being assigned a location does not have the inventory
      -- record created yet which is why SYSDATE is used.  When the inventory
      -- record is created the receive date is set to the SYSDATE.
      -- 02/09/06 prpbcb Changed to handle a null inv.rec_date.
      --
      AND (    (st.deep_ind = 'N')
           OR  (i_r_syspars.mix_same_prod_deep_slot = 'Y')
           OR  (    i_r_syspars.mix_same_prod_deep_slot = 'N'
                AND NOT EXISTS
                  (SELECT 'x'
                     FROM inv i2
                    WHERE i2.plogi_loc        = lz.logi_loc
                      AND i2.prod_id          = i_r_item_info.prod_id
                      AND i2.cust_pref_vendor = i_r_item_info.cust_pref_vendor
                      AND TRUNC(NVL(i2.rec_date, SYSDATE)) != TRUNC(SYSDATE)))
          )
      --
      -- Select slots big enough.
      -- A position within the slot needs to be large enough for a pallet.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
           ROUND(l.cube / st.deep_positions, 2) >= i_r_pallet.cube_with_skid AND
               (ROUND(l.cube, 2) - i_r_pallet.cube_with_skid) >=
     ----------------------------------------------------------------
     (SELECT ROUND(SUM(DECODE(pt1.skid_cube, 0, pt2.skid_cube,
                                       pt1.skid_cube) +
              DECODE(i_r_item_info.round_inv_cube_up_to_ti_flag,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                      i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                                       i_r_item_info.case_cube_for_calc,
                                       pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) * 
                       DECODE(i.prod_id || i.cust_pref_vendor,
                  i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                              i_r_item_info.case_cube_for_calc,
                              pm.case_cube))), 2)     occupied_cube
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             loc loc,    -- To get the pallet type of the location
             inv i
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND loc.logi_loc        = i.plogi_loc
         AND I.plogi_loc         = l.logi_loc
       GROUP BY i.plogi_loc))
      ---------------------------------------------------------------
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid AND
               l.slot_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Match pallet type.
      -- FW and LW are treated as equivalent.
      --
      AND (    DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                      DECODE(i_r_item_info.pallet_type, 'FW', 'LW',
                             i_r_item_info.pallet_type)
            OR (l.pallet_type IN
                        (SELECT mixed_pallet
                           FROM pallet_type_mixed pmix
                          WHERE pmix.pallet_type = i_r_item_info.pallet_type))
          )
      --
      -- Stackability
      --
      AND (    (st.deep_ind = 'Y')
           OR  (st.deep_ind = 'N'
                AND NOT EXISTS
                       (SELECT 'x'
                        FROM pm p2, inv si
                       WHERE p2.prod_id          = si.prod_id
                         AND p2.cust_pref_vendor = si.cust_pref_vendor
                         AND si.plogi_loc        = lz.logi_loc
                         AND (p2.stackable > i_r_item_info.stackable
                              OR p2.stackable = 0)))
          )
      --
      -- Cannot have a MSKU in the slot.
      --
      AND NOT EXISTS (SELECT 'x'
                        FROM inv inv_msku
                       WHERE inv_msku.plogi_loc        = lz.logi_loc
                         AND inv_msku.parent_pallet_id IS NOT NULL)
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube / st.deep_positions),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                       'I', l.available_height,
                                       l.cube / st.deep_positions),
                           0)),
             ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
             ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
             ABS(i_r_item_info.put_level - l.put_level), l.put_level;

   ELSIF (i_what_locations = pl_rcv_open_po_types.ct_open_slot) THEN
      ----------------------------------------------------------------------
      -- Select open slots in the specified zone.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type        st,
          lzone            lz,
          loc              l
    WHERE lz.zone_id               = i_zone_id
      AND l.perm                   = 'N'
      AND l.status                 = 'AVL'
      AND l.logi_loc               = lz.logi_loc
      AND st.slot_type             = l.slot_type
      --
      -- Select slots big enough.
      -- A position within the slot needs to be large enough for a pallet.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
               ROUND(l.cube, 2) >= i_r_pallet.cube_with_skid AND
               ROUND(l.cube / st.deep_positions, 2) >=
                                                  i_r_pallet.cube_with_skid)
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid AND
               l.slot_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Select empty slots.
      --
      AND NOT EXISTS
               (SELECT 'x'
                  FROM inv i
                 WHERE i.plogi_loc = lz.logi_loc)
      --
      -- Match pallet type.
      -- FW and LW are treated as equivalent.
      --
      AND (    DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                      DECODE(i_r_item_info.pallet_type, 'FW', 'LW',
                             i_r_item_info.pallet_type)
            OR (l.pallet_type IN
                        (SELECT mixed_pallet
                           FROM pallet_type_mixed pmix
                          WHERE pmix.pallet_type = i_r_item_info.pallet_type))
          )
      --
      -- Cannot have a MSKU in the slot.
      --
      AND NOT EXISTS (SELECT 'x'
                        FROM inv inv_msku
                       WHERE inv_msku.plogi_loc        = lz.logi_loc
                         AND inv_msku.parent_pallet_id IS NOT NULL)
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube / st.deep_positions),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                      'I', l.available_height,
                                      l.cube / st.deep_positions),
                           0)),
             ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
             ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
             ABS(i_r_item_info.put_level - l.put_level), l.put_level;

   ELSIF (i_what_locations = pl_rcv_open_po_types.ct_different_item_slot) THEN
      ----------------------------------------------------------------------
      -- Select the candidate deep slots in the specified zone with
      -- different items if syspar MIX_PROD_BULK_AREA is 'Y'.  If the syspar
      -- is 'N' then no slots will be selected.
      --
      -- It is possible for the slot to have a different item and a pallet
      -- of the item currently being processed.
      ----------------------------------------------------------------------
      OPEN io_curvar_locations FOR
   SELECT l.logi_loc,
          l.slot_type,
          l.pallet_type,
          l.rank,
          l.uom,
          l.perm,
          l.put_aisle,
          l.put_slot,
          l.put_level,
          NVL(l.cube, 0)        cube,
          l.available_height,
          l.occupied_height,
          NVL(l.slot_height, 0) slot_height,
          l.true_slot_height,
          l.liftoff_height,
          l.status,
          NVL(st.deep_ind, 'N') deep_ind,
          st.deep_positions,
          l.cube / st.deep_positions  position_cube,
          0 qoh,           -- Added so columns selected match other cursors
          0 qty_planned,   -- Added so columns selected match other cursors
          0 cube_used,     -- Will be calculated later.  To costly to do 
                           -- it now.
          lz.zone_id
     FROM slot_type        st,
          lzone            lz,
          loc              l
    WHERE lz.zone_id               = i_zone_id
      AND l.perm                   = 'N'
      AND l.status                 = 'AVL'
      AND l.logi_loc               = lz.logi_loc
      AND st.slot_type             = l.slot_type
      --
      -- Allow mixing of different items needs to be 'Y'.
      --
      AND i_r_syspars.mix_prod_bulk_area = 'Y'
      --
      -- Look at slots that have a pallet of other items.
      --
      AND EXISTS
           (SELECT 'x'
              FROM inv i1
             WHERE i1.plogi_loc       = lz.logi_loc
               AND (   i1.prod_id          != i_r_item_info.prod_id
                    OR i1.cust_pref_vendor != i_r_item_info.cust_pref_vendor))
      --
      -- Select slots big enough.
      -- A position within the slot needs to be large enough for a pallet.
      --
      AND (   (i_r_syspars.putaway_dimension = 'C' AND
          ROUND(l.cube / st.deep_positions, 2) >= i_r_pallet.cube_with_skid AND
               (ROUND(l.cube, 2) - i_r_pallet.cube_with_skid) >=
     ----------------------------------------------------------------
     (SELECT ROUND(SUM(DECODE(pt1.skid_cube, 0, pt2.skid_cube,
                                       pt1.skid_cube) +
              DECODE(i_r_item_info.round_inv_cube_up_to_ti_flag,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                      i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                                       i_r_item_info.case_cube_for_calc,
                                       pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) * 
                       DECODE(i.prod_id || i.cust_pref_vendor,
                  i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                              i_r_item_info.case_cube_for_calc,
                              pm.case_cube))), 2)     occupied_cube
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             loc loc,    -- To get the pallet type of the location
             inv i
       WHERE pt1.pallet_type     = pm.pallet_type
         AND pt2.pallet_type     = loc.pallet_type
         AND pm.prod_id          = i.prod_id
         AND pm.cust_pref_vendor = i.cust_pref_vendor
         AND loc.logi_loc        = i.plogi_loc
         AND I.plogi_loc         = l.logi_loc
       GROUP BY i.plogi_loc))
      ---------------------------------------------------------------
           OR (i_r_syspars.putaway_dimension = 'I' AND
               l.available_height >= i_r_pallet.pallet_height_with_skid AND
               l.slot_height >= i_r_pallet.pallet_height_with_skid)
          )
      --
      -- Allow/do not allow mixing different receive dates in deep slots for
      -- an item depending on the syspar setting.
      -- The pallet being assigned a location does not have the inventory
      -- record created yet which is why SYSDATE is used.  When the inventory
      -- record is created the receive date is set to the SYSDATE.
      -- 02/09/06 prpbcb Changed to handle a null inv.rec_date.
      --
      AND (    (st.deep_ind = 'N')
           OR  (i_r_syspars.mix_same_prod_deep_slot = 'Y')
           OR  (    i_r_syspars.mix_same_prod_deep_slot = 'N'
                AND NOT EXISTS
                  (SELECT 'x'
                     FROM inv i2
                    WHERE i2.plogi_loc        = lz.logi_loc
                      AND i2.prod_id          = i_r_item_info.prod_id
                      AND i2.cust_pref_vendor = i_r_item_info.cust_pref_vendor
                      AND TRUNC(NVL(i2.rec_date, SYSDATE)) != TRUNC(SYSDATE)))
          )
      --
      -- Match pallet type.
      -- FW and LW are treated as equivalent.
      --
      AND (    DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                      DECODE(i_r_item_info.pallet_type, 'FW', 'LW',
                             i_r_item_info.pallet_type)
            OR (l.pallet_type IN
                        (SELECT mixed_pallet
                           FROM pallet_type_mixed pmix
                          WHERE pmix.pallet_type = i_r_item_info.pallet_type))
          )
      --
      -- Stackability
      --
      AND (    (st.deep_ind = 'Y')
           OR  (st.deep_ind = 'N'
                AND NOT EXISTS
                       (SELECT 'x'
                        FROM pm p2, inv si
                       WHERE p2.prod_id          = si.prod_id
                         AND p2.cust_pref_vendor = si.cust_pref_vendor
                         AND si.plogi_loc        = lz.logi_loc
                         AND (p2.stackable > i_r_item_info.stackable
                              OR p2.stackable = 0)))
          )
      --
      -- Cannot have a MSKU in the slot.
      --
      AND NOT EXISTS (SELECT 'x'
                        FROM inv inv_msku
                       WHERE inv_msku.plogi_loc        = lz.logi_loc
                         AND inv_msku.parent_pallet_id IS NOT NULL)
    --
    -- If a full pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a full pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    -- If a partial pallet and minimizing the distance then order by the
    -- slots closest to the anchor location.
    -- If a partial pallet and not minimizing the distance then order by the
    -- best fit slot based on the putaway dimension syspar.
    --
    ORDER BY DECODE(i_r_pallet.partial_pallet_flag,
                    'N', DECODE(i_r_item_info.full_plt_minimize_option,
                                'D', 0,
                                'S', DECODE(i_r_syspars.putaway_dimension,
                                            'I', l.available_height,
                                            l.cube / st.deep_positions),
                                 0),
                    DECODE(i_r_syspars.partial_minimize_option,
                           'D', 0,
                           'S', DECODE(i_r_syspars.putaway_dimension,
                                      'I', l.available_height,
                                      l.cube / st.deep_positions),
                           0)),
             ABS(i_r_item_info.put_aisle - l.put_aisle), l.put_aisle,
             ABS(i_r_item_info.put_slot - l.put_slot), l.put_slot,
             ABS(i_r_item_info.put_level - l.put_level), l.put_level;
   ELSE
      -- i_what_locations has an unhandled value.  This is an error.
      RAISE e_bad_parameter;
   END IF;

EXCEPTION
   WHEN e_bad_parameter THEN
      l_message :=
         'LP[' || i_r_pallet.pallet_id || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_what_locations[' || i_what_locations || ']'
         || ' has an unhandled value.  This stops processing.';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_what_locations,i_r_syspars,i_r_item_info,i_r_pallet'
         || 'i_zone_id,io_curvar_locations)'
         || '  i_what_locations[' || i_what_locations || ']'
         || '  LP[' || i_r_pallet.pallet_id || ']'
         || '  Item[' || i_r_pallet.prod_id || ']'
         || '  CPV[' || i_r_pallet.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END bulk_rule_slots;


END pl_rcv_open_po_cursors;  -- end package body
/


SHOW ERRORS

