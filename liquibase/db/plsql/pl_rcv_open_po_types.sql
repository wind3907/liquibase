CREATE OR REPLACE PACKAGE SWMS.pl_rcv_open_po_types
AS

-- sccs_id=@(#) src/schema/plsql/pl_rcv_open_po_types.sql, swms, swms.9, 11.2 11/13/09 1.24

---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_types
--
-- Description:
--    This package has the type definitions used with the packages
--    involved in finding putaway slots when opening a PO/SN.
--
--    See file pl_rcv_open_po_find_slot.sql for more information about
--    the open PO/SN process.
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
--                      Fixes to bugs found by SQ.
--
--    09/13/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Add slot_height field to t_r_location.
--                      Add case_home_slot field to t_r_item_info.
--
--    09/27/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Add primary_put_zone to t_r_item_info.
--                      Add primary_put_zone_rule_id to t_r_item_info.
--
--    10/19/05 prpbcb   Oracle 8 rs239b swms9 DN 12016
--                      Fix bugs found after the last build for 9.4.
--                      These fixes will not go in 9.4 but most likely in
--                      and emergency build or an emergency ftp.
--
--                      Documentation changes.
--
--    11/29/05 prpbcb   Oracle 8 rs239b swms9 DN 12043
--
--                      Added partial_minimize_option to the syspar
--                      record type t_r_putaway_syspars.  This syspar
--                      designates if to minimize the travel distance from
--                      the home slot or to  find the best fit by size.
--
--                      Added subtype t_cube number(12,2).  This will be used
--                      as the type for the location cube and the cube of
--                      the pallet to putaway.  Before loc.cube%type and
--                      inv.cube%type were used.  Using a subtype assures
--                      the precision will be the same for the location and
--                      the pallet to putaway.
--
--                      Added the following to the syspar record:
--                         - home_itm_rnd_inv_cube_up_to_ti
--                         - home_itm_rnd_plt_cube_up_to_ti
--                         - flt_itm_rnd_inv_cube_up_to_ti
--                         - flt_itm_rnd_plt_cube_up_to_ti
--                      They control if the current inventory in a slot is
--                      to be rounded up to the nearest ti when calculating
--                      the occupied cube in a slot and if the quantity on
--                      the pallet being received is to be rounded up to
--                      the nearest ti when calculating the cube of the
--                      pallet.  There is a syspar for home items and floating
--                      items
--                      Added the following fields to the t_r_item_info record.
--                         - round_inv_cube_up_to_ti_flag
--                         - round_plt_cube_up_to_ti_flag
--                      They are populated from syspars:
--                         - home_itm_rnd_inv_cube_up_to_ti
--                         - home_itm_rnd_plt_cube_up_to_ti
--                         - flt_itm_rnd_inv_cube_up_to_ti
--                         - flt_itm_rnd_plt_cube_up_to_ti
--                      At this time controlling the rounding the qty to a
--                      full Ti is at the syspar level.  It may be that these
--                      syspars do not allow enough flexibility and control
--                      needs to be moved to the pallet type level or some
--                      other level or maybe more syspars are needed.
--
--    12/16/05 prpbcb   Oracle 8 rs239b swms9 DN 12048
--                      WAI changes.
--                      Add the following fields to record type t_r_item_info.
--                         - split_zone_id        pm.split_zone_id%TYPE
--                         - split_zone_rule_id   pm.split_zone_id%TYPE
--                         - auto_ship_flag       pm.auto_ship_flag%TYPE
--                         - miniload_storage_ind pm.miniload_storage_ind%TYPE
--                         - case_induction_loc   loc.logi_loc%TYPE
--                         - split_induction_loc  loc.logi_loc%TYPE
--                         - case_home_slot_deep_positions
--                         - case_home_slot_width_positions
--                         - case_home_slot_total_positions
--
--                      Add the following fields to record type t_r_pallet.
--                         - inv_uom              inv.inv_uom%TYPE
--                      End of WAI changs.
--
--                      Changed data type of case_cube_for_calc from
--                      pm.case_cube%TYPE to NUMBER because of rounding
--                      issues.
--
--                      Moved the following constants
--                      from pl_rcv_open_po_find_slot to this package.
--                         - ct_check_reserve
--                         - ct_same_item
--                         - ct_new_item
--                         - ct_no_pallets_left
--
--                      Added the following syspars to the syspar record:
--                         - partial_nondeepslot_search_clr
--                         - partial_nondeepslot_search_frz
--                         - partial_nondeepslot_search_dry
--                         These are new syspars to designate the search
--                         order of slots for a partial pallet going to
--                         a non-deep reserve slot. for cooler, freezer
--                         and dry.
--
--                      Added the following field to the t_r_item_info record.
--                         - partial_nondeepslot_search
--                      It is populated from one of the following syspars
--                      based on the area of the item.
--                         - partial_nondeepslot_search_clr
--                         - partial_nondeepslot_search_frz
--                         - partial_nondeepslot_search_dry
--
--                      Added constants
--                         - ct_open_slot
--                         - ct_same_item_slot
--                         - ct_any_non_empty_slot
--                         - ct_different_item_slot
--                      and changed the pl_rcv_open_po* packages to use
--                      these constants instead of the hardcoded value.
--
--    03/25/06 prpbcb   Oracle 8 rs239b swms9 DN 12078
--                      Changed the uom data type in the pallet record from
--                         putawaylst.qty%TYPE
--                      to
--                         putawaylst.uom%TYPE.
--                      Note: It caused no problems because the qty is a
--                            number too.
--
--    06/01/06 prpbcb   Oracle 8 rs239b swms9 DN 12087
--                      Ticket: 182100
--                      Added field chk_float_cube_ge_lss_cube to the syspar
--                      record.  This may become a syspar.  See the
--                      documentation for the syspar record for more info.
--                      The previous putaway logic always checked that the
--                      slot cube was >= last ship slot cube.  The new
--                      putaway logic does not which was an oversite on my
--                      part.  OpCo 59 raised an issue because there
--                      floating slot setup in the warehouse was based
--                      on the putaway logic making this check.  We may end
--                      up creating a syspar to control this.  Alan Mckay
--                      was going to talk to Dick Apt at OpCo 59 to discuss
--                      this.
--                      The only thing implemented at this time was to add the
--                      syspar to the syspar record and get the syspar value.
--                      Procedure l_rcv_open_po_cursors.floating_slots does
--                      not use the value yet.
--
--    06/08/06 prpbcb   Oracle 8 rs239b swms9 DN 12097
--                      Documentation changes.
--
--    08/10/06 prpbcb   Oracle 8 rs239b swms9 DN 12114
--                      Ticket: 182100
--                      Project: 182100-Direct Pallet for Floating Item
--                      Documentation changes.
--
--    04/10/07 prpbcb   DN 12235
--                      Ticket: 265200
--                      Project: 265200-Putaway By Inches Modifications
--
--                      Changed data type of full_pallet_qty_in_splits from
--                      PLS_INTEGER to NUMBER because PLS_INTEGER was not
--                      large enough to hold Ti * Hi * SPC for some items.
--
--                      Add pallet_stack from the PM table to the item
--                      info and add logic to the other pl_rcv_open*
--                      program to implement its use.  It was missed when
--                      pallet_label2.pc was converted to PL/SQL
--                      Pallet_stack is the maximum number of pallets that
--                      can exist in a slot in order for a pallet of the item
--                      to be directed to the slot.
--                      It does not apply to a home slot.
--                      No logic was added for deep slots because the current
--                      processing will not stack pallets in deep slots.
--                      Example: pallet stack = 1.
--                               At most 1 pallet of the item will be
--                               directed to an open slot.  No pallets of
--                               the item will be directed to an occupied slot.
--                      Example: pallet stack = 2.
--                               At most 2 pallets of the item will be
--                               directed to an open slot.  No pallets of
--                               the item will be directed to an occupied slot.
--
--                      Added syspar chk_reserve_hgt_ge_home_hgt.  When
--                      putaway by is by inches it designates if the candiate
--                      reserve slot height needs to be >= home slot height
--                      for a home slot item when selecting OPEN non-deep
--                      slots.  If N then the pallet just needs to fit
--                      regardless if the reserve slot height is >= home
--                      slot height.  It does the same as
--                      syspar chk_reserve_cube_ge_home_cube but for inches.
--                      Before this check was not made for putaway by inches.
--                      Now the user can choose.  This will keep things
--                      similar to how putaway by cube works.
--
--                      Because we are creating syspar
--                      chk_reserve_hgt_ge_home_hgt and to keep things
--                      consistent we will now create syspar
--                      chk_reserve_cube_ge_home_cube for the user to see.
--                      The logic to handle the syspar has always been in
--                      the program.  The program defaults the value to Y
--                      if the syspar does not exist which is why the program
--                      works when the syspar does not exist.  Hopefully the
--                      the users will not get confused when they see this
--                      syspar.
--
--                      An actual syspar will be created for
--                      partial_minimize_option to allow the users to
--                      set it.  The logic was added to the programs in
--                      November 2005 but the syspar was never created.
--
--                      Added syspar chk_float_hgt_ge_lss_hgt which will
--                      work the same as syspar chk_float_cube_ge_lss_cube
--                      but for inches.
--
--                      Added last_ship_slot_height to the item record.  It
--                      is used in conjunction with syspar
--                      chk_float_hgt_ge_lss_hgt.
--
--                      Added pt_putaway_floating_by_max_qty to the item
--                      record.  It is populated from
--                      pallet_type.putaway_floating_by_max_qty when
--                      selecting info about the item and flags if
--                      directing a floating item to a slot will be by the
--                      item's max qty or by the current putaway dimension.
--                      If the value is Y then the item's max qty is used
--                      to direct pallets to slots for floatin items.  If
--                      the value is N then the putaway dimension syspar
--                      controls directing pallets to slots.
--                      pallet_type.putaway_floating_by_max_qty was added
--                      to the pallets type screen.
--                      This max qty will be the maximum number of cases
--                      this will fit in a slot for the floating item.
--                      This means if it is set to 10 and pallets of 20
--                      are always received then the location will '*'
--
--                      Added the following syspars to the syspar record.
--                         - floating_slot_sort_order_clr
--                         - floating_slot_sort_order_frz
--                         - floating_slot_sort_order_dry
--                      They control the sorting of the candidate floating
--                      slots for a floating item and have an effect when
--                      syspar non_fifo_combine_plts_in_float is Y.
--                      The user can choose to order the slots that have
--                      existing inventory (same item being received)
--                      before the empty slots or after the empty slots.
--                      The rules for directing floating items are:
--                         1. Direct pallets to empty slots if syspar
--                            non_fifo_combine_plts_in_float is N
--                         2. Direct pallets to empty slots or slots with
--                            existing inventory (same item being received)
--                            if syspar non_fifo_combine_plts_in_float is Y
--                            and it is not a FIFO item.
--                      The initial implementation of this was started on
--                      12/16/05 (it was never finished) and only used one
--                      syspar called floating_slot_sort_order.  Now there
--                      is a syspar for each area.
--
--                      Added the following fields to the t_r_item_info record:
--                         - floating_slot_sort_order
--                           It is populated from one of the following syspars
--                           based on the area of the item.
--                              - floating_slot_sort_order_clr
--                              - floating_slot_sort_order_frz
--                              - floating_slot_sort_order_dry
--                         - max_qty_in_splits
--                           It is pm.max_qty expressed as splits.
--
--                      Added the following fields to pallet record:
--                         - cube_for_home_putaway
--                           Cube of the pallet to use when directing the
--                           pallet to the home slot.  It will be
--                           cube_without_skid or cube_with_skid. For a partial
--                           pallet it will always be cube_without_skid.
--                         - pallet_height_for_home_putaway
--                           This is the pallet height to use when directing
--                           the pallet to the home slot.  It will be
--                           pallet_height_without_skid or
--                           pallet_height_with_skid.  For a partial pallet it
--                           will always be pallet_height_without_skid.
--
--                      Added constant:
--                         ct_application_function.
--                      It will be used in the log messages in the
--                      pl_rcv_open_po* packages.  The log messages in these
--                      packages will be changed to pass the application
--                      function and program name on the comamnd line.
--
--    03/13/09 prpbcb   DN 12474
--                      Incident:
--                      Project: CRQ7373-Split SN pallet if over SWMS Ti Hi
--
--                      Added the following syspars to the syspar record:
--                         - split_rdc_sn_pallet
--                         - split_vendor_sn_pallet
--                      These control to split/not split RDC SN pallet and
--                      vendor SN pallet when the qty on the pallet is greater
--                      than the SWMS Ti Hi.
--                      We will make these a syspars at this time.  Maybe in
--                      the future it will be changed to a different level
--                      such as at the item level ?
--
--                      Added the following fields to the t_r_item_info record:
--                         - split_rdc_sn_pallet
--                         - split_vendor_sn_pallet
--                      They are not used at this time.
--
--                      Added the following field to the t_r_pallet record:
--                         - from_splitting_sn_pallet_flag
--
--                      The processing of split_vendor_sn_pallet is not
--                      fully implemented at this time as the SN from vendor
--                      project is still ongoing.
--
--    05/02/09 prpbcb   DN 12500
--                      Project:
--                   CRQ9069-QTY Received not sent to SUS for SN pallet split
--
--                      Created a record type to be used in recording how a
--                      SN pallet was split.  It will be used to create log
--                      messages to show showing how the SN pallet was split.
--                      Pacakge pl_rcv_open_po_pallet_list will be creating
--                      the log messages.
--
--    06/05/09 prpbcb   DN 12505
--                      Project: CRQ9582-Split SN pallet log messages
--
--                      Re-arranged the fields in record
--                      t_r_how_sn_pallet_split.
--
--    06/05/09 prswp000 DN 12508
--                      Project: Miniload Reserve - Inbound Receiving
--
--                      Added miniload_reserve to the pallet record and
--                      case_qty_per_carrier and max_miniload_case_carriers
--                      to the item record.
--
--    10/17/12 prpbcb  Activty: Activity: CRQ39909-Putaway_by_min_qty
--                     Project: Activity: CRQ39909-Putaway_by_min_qty
--
--                     Change putaway by max qty logic to use the min qty
--                     as the threshold to send pallets to the home slot.
--                     The rules are:
--                     - If the qty in the home slot is <= min qty
--                       then direct the receiving pallet to the home slot.
--                     - If the qoh in the home slot plus the receiving
--                       pallet qty is < max qty then direct the receiving
--                       pallet to the home slot.
--
--                    NOTE: FIFO rules always apply
--
--                    Added following to the item record t_r_item_info:
--                       min_qty            pm.min_qty%TYPE
--                       min_qty_in_splits  NUMBER
--                       putaway_to_home_slot_method VARCHAR2(1)
--                           Values can be: Y - by min/max qty
--                                          N - Normal processing
--                                          NULL  - Normal processing
--                     Field "pt_putaway_use_repl_threshold" in t_r_item_info
--                     will not be used anymore since the name is somewhat
--                     confusing.  But we will still take the value for
--                     "putaway_to_home_slot_method"
--                     from column PALLET_TYPE.PUTAWAY_USE_REPL_THRESHOLD.
--                     Maybe at some time we can change the column name
--                     from PUTAWAY_USE_REPL_THRESHOLD to something more
--                     in line with what it means.
--
--                    Added following to the pallet record t_r_pallet:
--                       - erm_line_id  It is used to populate
--                                      PUTAWAYLST.ERM_LINE_ID
--                                      The check-in screen now needs
--                                      this populated.
--
--    08/05/14 sred5131  Added following to the pallet record t_r_item_info
--                           --MX_ITEM_ASSIGN_FLAG
--                             MX_MIN_CASE
--                             MX_MAX_CASE
--                             MX_FOOD_TYPE
--                       Added following to the pallet record t_r_pallet
--                           --matrix_reserve
--   09/26/14  vred5319  Added mx_eligible field to record t_r_item_info
--  28-OCT-2014 spot3255  Charm# 6000003789 - Ireland Cubic values - Metric conversion project
--                          Increased length of below variables to hold Cubic centimetre.
--                          SUBTYPE t_cube from NUMBER(12,2) to NUMBER(12,4).
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
--                     Added these syspars to record type "t_r_putaway_syspars".
--                     They designate if to minimize the travel distance from
--                     the home slot or find the best fit by size (the way it always
--                     worked) when finding a suitable reserve slot for a full
--                     with a home slot.  The valid values are 'D' for distance
--                     and 'S' for size.
--
--                     Added field "full_plt_minimize_option" to record type
--                     "t_r_putaway_syspars".  It is populated from one of
--                     the new syspars based on the area of the item.
--                     The cursors that selects the slots use "full_plt_minimize_option"
--                     in the ORDER BY.
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/06/16 bben0556 Brian Bent
--                      Project:
--           R30.6--WIE#669--CRQ000000008118_Live_receiving_story_15_cron_open_PO
-- 
--                      Added syspar ENABLE_LIVE_RECEIVING to record type
--                      "t_r_putaway_syspars".
-- 
--                      Added constant:
--                         ct_lr_dest_loc  CONSTANT VARCHAR2(2) := 'LR';
--                      This is the "temporary" putawaylst.dest_loc when the
--                      PO is first opened for Live Receiving.
--
--    09/20/16 bben0556 Brian Bent
--                      Project:
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_33_find_dest_loc
--
--                      Add field to the pallet record.
--                      - live_receiving_status - designates if the pallet
--                                                is a live receiving pallet
--                                                at the point in the
--                                                processing where we assigned
--                                                the putaway slot.
--
--                      - qty_expected  - Qty expected on pallet in splits.
--                      - qty_received  - Qty received on pallet in splits
--                                        Can updated during live receiving
--                                        RF check-in of LP.
--    07/20/17 bben0556 Brian Bent
--                      Project: 
--         30_6_Story_2030_Direct_miniload_items_to_induction_location_when_PO_opened
--
--                      Live Receiving change.
--                      Always set the putawaylst.dest_loc to the miniloader
--                      induction location and create inventory for pallets
--                      directed to the miniloader when the PO is opened
--                      regardless if Live Receiving is active.
--                      We don't want the pallets to "LR". 
--                      We need to do this because for the miniloader
--                      the expected receipts are sent to the
--                      miniloader when the PO is opened and syspar
--                      MINILOAD_AUTO_FLAG is set to Y.  If we use the
--                      "LR" logic then the creating of the expected receipts
--                      will fail because "LR" is not a valid location.
--                      Also since we know what pallets are going to the miniloader
--                      why use the "LR" logic.
--
--                      Modified "pl_rcv_open_po_types.sql"
--                         Added field "direct_to_ml_induction_loc_bln" to the pallet RECORD.
--                         The build pallet processing in "pl_rcv_open_po_list.sql"
--                         changed to set this to TRUE when the pallet is going to the miniloader
--                         induction location.
--
--                      Modified "pl_rcv_open_po_list.sql"
--                         Changed procedure "build_pallet_list_from_po" to
--                         populate "direct_to_ml_induction_loc_bln" in the
--                         pallet RECORD.
--
--                      Modified "pl_rcv_open_po_lr.sql"
--                         Changed procedure "create_putaway_task" adding
--                         parameter pl_rcv_open_po_types.t_r_item_info_table
--                         and calling "pl_rcv_open_po_ml.direct_ml_plts_to_induct_loc"
--
--                      Modified "pl_rcv_open_po_find_slot.sql"
--                         Changed call to pl_rcv_open_po_lr.create_putaway_task
--                         from
--                            pl_rcv_open_po_lr.create_putaway_task
--                                 (l_r_item_info_table,
--                                  l_r_pallet_table);
--                         to
--                            pl_rcv_open_po_lr.create_putaway_task
--                                 (i_r_syspars         => l_r_syspars,
--                                  i_r_item_info_table => l_r_item_info_table,
--                                  io_r_pallet_table   => l_r_pallet_table);
--
--                      Modified "pl_rcv_open_po_ml.sql"
--                         Created procedure "direct_ml_plts_to_induct_loc"
--                         It is called by procedure
--                         "pl_rcv_open_po_lr.sql.create_putaway_task" to
--                         send the pallets to the miniloader induction location.
--                         The pallets to send have been flagged in package
--                         package "pl_rcv_open_po_pallet_list.sql" when
--                         building the pallet list.
--
--    07/21/17 bben0556 Brian Bent
--                      Project: 
--         30_6_Story_2030_Direct_miniload_items_to_induction_location_when_PO_opened
--                      Checkout/checkin to force build.
--
--    01/25/18 mpha8134 Jira card OPCOF-289: Always set putawaylst.dest_loc to the matrix 
--                      induction location and create inventory pallets
--                      directed to the miniloader when the PO is opened
--                      regardless if Live Receiving is active. We don't
--                      want the pallets to "LR".
--                      
--                      Modified "pl_rcv_open_po_types.sql"
--                        Added field "direct_to_mx_induction_loc_bln" to the pallet RECORD.
--                        The build pallet processing in "pl_rcv_open_po_pallet_list.sql"
--                        chagned to set this to TRUE when the pallet is going to the
--                        matrix induction location.
--
--                      Modified "pl_rcv_open_po_list.sql"
--                        Changed procedure "build_pallet_list_from_po" to
--                        populate "direct_to_mx_induction_loc_bln" in the
--                        pallet RECORD.
--
--                      Modified "pl_rcv_open_po_lr.sql"
--                        Changed procedure "create_putaway_task to call
--                        "pl_rcv_open_po_ml.direct_mx_plts_to_induct_loc"
--
--                      Modified "pl_rcv_open_po_matrix.sql"
--                         Created procedure "direct_mx_plts_to_induct_loc"
--                         It is called by procedure
--                         "pl_rcv_open_po_lr.sql.create_putaway_task" to
--                         send the pallets to the matrix induction location.
--                         The pallets to send have been flagged in package
--                         package "pl_rcv_open_po_pallet_list.sql" when
--                         building the pallet list.
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/11/22 bben0556 Brian Bent
--                      Card: R50_0_DML_OPCOF-3872_BUG_Miniload_items_asterisk_when_directed_to_main_whse_reserve
--                      Bug fix.
--
--                      Miniload items "*" when directed to main warehouse reserve locations.
--
--                      This started happening after we took out the extended case cube "magic" cube check because of an issue at the BRAKES OpCo.
--                      The putaway logic would turn off extended case cube (if configured to use extended case cube)
--                      if the items "home" location cube was >= 900 (the magic cube).
--                      For purposes of the putaway logic the home location is:
--                         - Items home slot for home slot itims.
--                         - Items last ship slot for a floating item
--                         - Miniloader induction location for a miniloader item.
--
--                      The BRAKES OpCo is using extended case cube and uses cubic centimenters.  The magic cube was hardcoded
--                      to 900 which is fine for cubic feet but 900 is small for cubic centimeters as most locations have a cube
--                      much more than 900 so for the BRAKES OpCo the extended case cube almost always got turned off.
--
--                      When directing a miniload item pallet to main warehouse reserve the pallet would "*" because the induction
--                      location is used to determine the extended case cube.  The cube of the induction location is usually very
--                      large so the extended case cube is calculated to a large value thus the cube of the incoming pallet turns
--                      out to be too big for any slot.
--
--                      This magic cube check to turn off extended case cube will be re-implented and will use the value of syspar
--                      EXTENDED_CASE_CUBE_CUTOFF_CUBE and not hardcode 900.
--                      For OpCos using cubic feet the initial value of the syspar will be set to 900.
--                      For OpCos using cubic centimeters the initial value of the syspar will be set to 25484400 (900 * 28316).
--
--                      Add syspar EXTENDED_CASE_CUBE_CUTOFF_CUBE to "t_r_putaway_syspars".
--
--
---------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------

   -- Type for the location cube, cube of the pallet to putaway and the
   -- cube of existing inventory.  Using a subtype assures the precision
   -- will be the same.  Calculations using the location cube and pallet
   -- cube are rounded to two decimal places where appropriate so the
   -- precision in the subtype needs to be 2.
   /* Charm# 6000003789: changed data type from NUMBER (12,2) to NUMBER (12,4) */
   SUBTYPE t_cube IS NUMBER(12,4);


   -- Record to hold syspars that are used in the processing.
   -- Each syspar is a field in the record.
   --
   -- 06/23/05 prpbcb
   -- Additional fields were added that may become a syspars.
   -- For the time being these fields are assigned a value when the syspars
   -- are selected which takes place in pl_rcv_open_po_find_slot.sql.
   --  Note: prpbcb Not all the fields in the record are in the documentation
   --               below.
   --
   --    - non_fifo_combine_plts_in_float
   --      (11/10/05 prpbcb This is a syspar)
   --
   --            Designates if to putaway a non-fifo floating item to a
   --            floating slot that has existing pallets.
   --            Stackability logic applies.
   --            Project: CMBFS-Combine floating slots for non-fif
   --
   --
   --
   --
   --    - putaway_to_home_if_fifo_allows
   --            This is a syspar.
   --
   --            Designates if to putaway to the home slot for a 'S' fifo item
   --            that has existing qoh in the home slot, no pallets in reserve
   --            and the pallet will fit in the home slot.
   --            Project: FIFO-FIFO receiving change
   --            prpbcb 08/29/05 Not implemented at this time, project
   --                            pushed back.
   --            prpbcb 03/01/06 This change will go in 9.6.
   --
   --
   --
   --
   --    - putaway_to_any_deep_slot
   --            11/29/05 prpbcb This is a syspar.
   --
   --            Putaway to any deep slot when the home slot is a deep slot.
   --            For example, if the home slot is a 3PB then the reserve slots
   --            can be 2PB (or any deep slot).  The default is Y.  This was a
   --            change put in SWMS 9.3 and will always be the case in
   --            pallet_label2.pc.
   --            The default is Y.
   --
   --
   --
   --
   --    - chk_reserve_cube_ge_home_cube
   --            This is not a syspar.
   --
   --            Check if the reserve slot cube is >= home slot cube for the
   --            candidate reserve slot for a home slot item when selecting
   --            OPEN non-deep slots.  If N then the pallet just needs to fit
   --            regardless if the reserve slot cube >= home slot cube.
   --            The default is Y.  This is the current processing.
   --
   --
   --
   --
   --    - chk_reserve_hgt_ge_home_hgt
   --
   --            Check if the reserve slot height is >= home slot height for
   --            the candidate reserve slot for a home slot item when selecting
   --            OPEN non-deep slots.  If N then the pallet just needs to fit
   --            regardless if the reserve slot height >= home slot height.
   --
   --
   --
   --    - stack_in_deep_slots
   --            This is not a syspar.
   --
   --            Designates if to stack in deep slots.  Either home or reserve.
   --            Stackability logic applies.
   --            The default is N.  This is the current processing.
   --            06/24/05 prpbcb Currently the putaway process will not stack
   --                             pallets in deep slots.  Nothing looks at
   --                             the value other than it being set to N.
   --
   --
   --
   --
   --    - non_fifo_to_home_w_qty_in_rsrv
   --            This is not a syspar.    05/01/07 Not used
   --
   --            Designates if to putaway a non-fifo item to the home slot if
   --            there are pallets in reserve.
   --            Note: If extended case cube is on then a full pallet will not
   --                  be directed to the home slot if the qoh > 0 because the
   --                  case cube is adjusted so that a full pallet exactly
   --                  fills the slot.  A partial pallet could be directed to
   --                  the home slot though.
   --            Stackability logic applies.
   --            The default is Y.  This is the current processing.
   --
   --
   --
   --
   --    - putaway_to_any_matching_pt   06/23/05 prpbcb For what ???
   --
   --
   --
   --
   --    - partial_minimize_option   11/29/05 prpbcb  Added.
   --            05/03/07  A syspsar will be created for this so the users
   --                      can control it.
   --
   --            This designates if to minimize the travel distance from
   --            the home slot or find the best fit by size (the current
   --            method) when finding a suitable reserve slot for a partial
   --            pallet for an item with a home slot.  The valid values are
   --            'D' for distance and 'S' for size.
   --            The order by clauses in the cursors in
   --            pl_rcv_open_po_cursors.sql look at this.
   --
   --
   --
   --
   --    - home_itm_rnd_inv_cube_up_to_ti        11/29/05 prpbcb  Added.
   --            This is not a syspar.
   --
   --            This designates if the current inventory in a slot is to be
   --            rounded up to the nearest ti when calculating the occupied
   --            cube in a slot for an item with a home slot.
   --            The default is Y which is the current processing.
   --
   --
   --
   --
   --    - home_itm_rnd_plt_cube_up_to_ti        11/29/05 prpbcb  Added.
   --            This is not a syspar.
   --
   --            They designates if the quantity on the pallet being received
   --            is to be rounded up to the nearest ti when calculating the
   --            cube of the pallet for an item with a home slot.
   --            The default is Y which is the current processing.
   --
   --
   --
   --
   --    - flt_itm_rnd_inv_cube_up_to_ti         11/29/05 prpbcb  Added.
   --            This is not a syspar.
   --
   --            This designates if the current inventory in a slot is
   --            to be rounded up to the nearest ti when calculating
   --            the occupied cube in a slot for a floating item.
   --            The default is Y.  This is the current processing.
   --
   --
   --
   --
   --    - flt_itm_rnd_plt_cube_up_to_ti         11/29/05 prpbcb  Added.
   --            This is not a syspar.
   --
   --            This designates if the quantity on the pallet being
   --            received is to be rounded up to the nearest ti when
   --            calculating the cube of the pallet for a floating item.
   --            The default is Y.  This is the current processing.
   --
   --
   --
   --
   --    - partial_nondeepslot_search_clr      02/22/06 prpbcb  Added.
   --    - partial_nondeepslot_search_frz
   --    - partial_nondeepslot_search_dry
   --
   --            These syspars control the search order of the slots for a
   --            partial pallet going to a non-deep reserve slot in the
   --            desginated area.  The search order was fixed at the
   --            following:
   --               1.  Non-open non-deep slots that have at least
   --                   one pallet of the item.                   (A)
   --               2.  Any non-empty non-deep slot, any product. (B)
   --               3.  Open non-deep slots.                      (C)
   --            Now syspars control it.
   --            For documentation purposes the three different searches
   --            above are labeled with (A), (B) and (C).  The syspar can
   --            have 4 different values to correspond to the 4 combinations
   --            of the search order.  There is not 6 bacause there is no
   --            need to search (A) after (B) because (B) would include (A).
   --            The syspar values and the resulting search order are:
   --               Syspar
   --               Value  Search Order
   --               -----  ---------------------------------------------
   --                 1    (A) (B) (C)
   --                 2    (A) (C) (B)
   --                 3    (B) (C)
   --                 4    (C) (A) (B)
   --            NOTE:  These do not apply when receiving splits.
   --                   Splits for a slotted item will always be directed to
   --                   the rank 1 split home slot regardless of FIFO except
   --                   if it is an aging item in which case the splits are
   --                   directed to an open slot.
   --
   --                   Splits for a floating item will always be directed to
   --                   an empty floating slot regardless of the setting of
   --                   syspar NON_FIFO_COMBINE_PLTS_IN_FLOAT.
   --
   --
   --
   --
   --    - floating_slot_sort_order_clr
   --    - floating_slot_sort_order_frz
   --    - floating_slot_sort_order_dry
   --
   --            These syspars control the sorting of the candidate floating
   --            slots for a floating item and have an effect when
   --            syspar non_fifo_combine_plts_in_float is Y.
   --            The user can choose to order the slots that have
   --            existing inventory (same item being received)
   --            before the empty slots or after the empty slots.
   --            The rules for directing floating items are:
   --               1. Direct pallets to empty slots if syspar
   --                  non_fifo_combine_plts_in_float is N
   --               2. Direct pallets to empty slots or slots with
   --                  existing inventory (same item being received)
   --                  if syspar non_fifo_combine_plts_in_float is Y
   --                  and it is not a FIFO item.
   --            The syspar values and the resulting search order are:
   --               Syspar
   --               Value  Floating Slot Sort Order
   --               -----  ---------------------------------------------
   --                 1    Occupied slots followed by empty slots.
   --                 2    Empty slots followed by occupied slots.
   --
   --
   --
   --
   --    - chk_float_cube_ge_lss_cube          06/01/06 prpbcb  Added.
   --
   --            Check/not check that the floating slot cube is >= last ship
   --            slot cube when selecting candidate OPEN floating slots for
   --            a floating item and putaway is by cube.
   --            If N then the pallet just needs to fit in the open slot.
   --            If Y then the cube of the open slot needs to be >= the
   --            cube of the last ship slot and the pallet needs to fit.
   --            The default is N.  This is the current processing.
   --
   --
   --
   --
   --    - chk_float_cube_ge_lss_cube          05/05/07 prpbcb  Added.
   --
   --            Check/not check that the floating slot height is >= last ship
   --            slot height when selecting candidate OPEN floating slots for
   --            a floating item and putaway is by inches.
   --            If N then the pallet just needs to fit in the open slot.
   --            If Y then the height of the open slot needs to be >= the
   --            height of the last ship slot and the pallet needs to fit.
   --            The default is N.  This is the current processing.
   --
   --
   --
   --    - split_rdc_sn_pallet                     03/13/09 prpbcb  Added.
   --
   --            Split/not split RDC SN pallet when the qty on the pallet
   --            is greater than the SWMS Ti Hi.
   --            The default is N.
   --            We will make this a syspar at this time.  Maybe in the
   --            future it will be changed to a different level such as at
   --            the item level ?
   --
   --
   --
   --    - split_vendor_sn_pallet                  03/13/09 prpbcb  Added.
   --
   --            Split/not split vendor SN pallet when the qty on the pallet
   --            is greater than the SWMS Ti Hi.
   --            The default is N.
   --            We will make this a syspar at this time.  Maybe in the
   --            future it will be changed to a different level such as at
   --            the item level ?
   --
   --    - mx_staging_or_induction types          09/18/2014  vred5319 Added
   --    - extended_case_cube_cutoff_cube          01/11/2022  bben0556  Added.
   --
   --
   TYPE t_r_putaway_syspars IS RECORD
   (
      clam_bed_tracked                sys_config.config_flag_val%TYPE,
      home_putaway                    sys_config.config_flag_val%TYPE,
      mixprod_2d3d_flag               sys_config.config_flag_val%TYPE,
      mix_prod_bulk_area              sys_config.config_flag_val%TYPE,
      mix_same_prod_deep_slot         sys_config.config_flag_val%TYPE,
      pallet_type_flag                sys_config.config_flag_val%TYPE,
      putaway_dimension               sys_config.config_flag_val%TYPE,
      non_fifo_combine_plts_in_float  sys_config.config_flag_val%TYPE,
      putaway_to_home_if_fifo_allows  sys_config.config_flag_val%TYPE,
      putaway_to_any_deep_slot        sys_config.config_flag_val%TYPE,
      chk_reserve_cube_ge_home_cube   sys_config.config_flag_val%TYPE,
      chk_reserve_hgt_ge_home_hgt     sys_config.config_flag_val%TYPE,
      stack_in_deep_slots             VARCHAR2(1), -- pseudo syspar
      non_fifo_to_home_w_qty_in_rsrv  VARCHAR2(1), -- pseudo syspar
      putaway_to_any_matching_pt      VARCHAR2(1), -- psuedo syspar
      partial_minimize_option         sys_config.config_flag_val%TYPE,
      home_itm_rnd_inv_cube_up_to_ti  sys_config.config_flag_val%TYPE,
      home_itm_rnd_plt_cube_up_to_ti  sys_config.config_flag_val%TYPE,
      flt_itm_rnd_inv_cube_up_to_ti   sys_config.config_flag_val%TYPE,
      flt_itm_rnd_plt_cube_up_to_ti   sys_config.config_flag_val%TYPE,
      partial_nondeepslot_search_clr  sys_config.config_flag_val%TYPE,
      partial_nondeepslot_search_frz  sys_config.config_flag_val%TYPE,
      partial_nondeepslot_search_dry  sys_config.config_flag_val%TYPE,
      floating_slot_sort_order_clr    sys_config.config_flag_val%TYPE,
      floating_slot_sort_order_frz    sys_config.config_flag_val%TYPE,
      floating_slot_sort_order_dry    sys_config.config_flag_val%TYPE,
      Chk_Float_Cube_Ge_Lss_Cube      Sys_Config.Config_Flag_Val%Type,
      Chk_Float_Hgt_Ge_Lss_Hgt        Sys_Config.Config_Flag_Val%Type,
      Split_Rdc_Sn_Pallet             Sys_Config.Config_Flag_Val%Type,
      Split_Vendor_Sn_Pallet          Sys_Config.Config_Flag_Val%Type,
      mx_staging_or_induction_frz     Sys_Config.config_flag_val%Type,   --  VR added
      mx_staging_or_induction_clr     Sys_Config.config_flag_val%Type,   --  VR added
      mx_staging_or_induction_dry     Sys_Config.config_flag_val%Type,   --  VR added
      full_plt_minimize_option_clr    sys_config.config_flag_val%TYPE,
      full_plt_minimize_option_frz    sys_config.config_flag_val%TYPE,
      full_plt_minimize_option_dry    sys_config.config_flag_val%TYPE,
      enable_live_receiving           sys_config.config_flag_val%TYPE,   -- 09/06/2016  Brian Bent  Added
      extended_case_cube_cutoff_cube  sys_config.config_flag_val%TYPE    -- 01/11/2022  Brian Bent  Added.
   );


   -- Needed to declare subtypes for slot types and pallet types info
   -- because these tables have a column with the same name as the table.
   SUBTYPE t_pt_cube               IS pallet_type.cube%TYPE;
   SUBTYPE t_pt_skid_cube          IS pallet_type.skid_cube%TYPE;
   SUBTYPE t_pt_skid_height        IS pallet_type.skid_height%TYPE;
   SUBTYPE t_pt_ext_case_cube_flag IS pallet_type.ext_case_cube_flag%TYPE;
   SUBTYPE t_pt_putaway_use_replthreshold IS
                                 pallet_type.putaway_use_repl_threshold%TYPE;
   SUBTYPE t_putaway_floating_by_max_qty IS
                                 pallet_type.putaway_floating_by_max_qty%TYPE;
   SUBTYPE t_slot_type             IS slot_type.slot_type%TYPE;
   SUBTYPE t_deep_ind              IS slot_type.deep_ind%TYPE;
   SUBTYPE t_deep_positions        IS slot_type.deep_positions%TYPE;


   -------------------------------------------------------------------
   -- Item information record.
   -------------------------------------------------------------------
   -- This record is used to hold item information needed to find a
   -- putaway slot.  Not all the fields may be in use.
   TYPE t_r_item_info IS RECORD
   (
      prod_id           pm.prod_id%TYPE,
      cust_pref_vendor  pm.cust_pref_vendor%TYPE,
      category          pm.category%TYPE,
      hazardous         pm.hazardous%TYPE,
      abc               pm.abc%TYPE,
      split_trk         pm.split_trk%TYPE,
      exp_date_trk      pm.exp_date_trk%TYPE,
      mfg_date_trk      pm.mfg_date_trk%TYPE,
      lot_trk           pm.lot_trk%TYPE,
      catch_wt_trk      pm.catch_wt_trk%TYPE,
      temp_trk          pm.temp_trk%TYPE,
      clam_bed_trk      VARCHAR2(1),          -- Y or N
      tti_trk           VARCHAR2(1),          -- Y or N
      cool_trk          VARCHAR2(1),          -- Y or N
      stackable         pm.stackable%TYPE,
      spc               pm.spc%TYPE,
      ti                pm.ti%TYPE,
      hi                pm.hi%TYPE,
      mf_ti             pm.mf_ti%TYPE,        -- RDC large wood TI
      mf_hi             pm.mf_hi%TYPE,        -- RDC HI
      pallet_type       pm.pallet_type%TYPE,  -- The items pallet type.  For
                                              -- a slotted item it will be the
                                              -- rank 1 case home pallet type.
                                              -- For a floating item it will be
                                              -- pm.pallet_type.  Note that for
                                              -- a slotted item pm.pallet_type
                                              -- should be the same as the
                                              -- rank 1 case home pallet type.
      area              pm.area%TYPE,
      case_cube         pm.case_cube%TYPE,
      zone_id           pm.zone_id%TYPE,      -- Items put zone (pm.zone_id).
      rule_id           zone.rule_id%TYPE,    -- Rule ID for zone_id
      primary_put_zone_id   pm.zone_id%TYPE,  -- The items primary put zone.
                                              -- For a slotted item it is the
                                              -- rank 1 case home put zone.
                                              -- For a floating item it will
                                              -- be pm.zone_id.  For a slotted
                                              -- item the pm.zone_id should be
                                              -- be the same as the rank 1 case
                                              -- home.
      primary_put_zone_id_rule_id  zone.rule_id%TYPE, -- Rule ID for
                                                      -- primary_put_zone_id.
      max_slot          pm.max_slot%TYPE,
      max_slot_per      pm.max_slot_per%TYPE,
      fifo_trk          pm.fifo_trk%TYPE,
      last_ship_slot    pm.last_ship_slot%TYPE,
      case_height       pm.case_height%TYPE,
      split_height      pm.split_height%TYPE,
      min_qty           pm.min_qty%TYPE,      -- This will be in cases.
      min_qty_in_splits NUMBER,               -- min qty expressed as splits
      max_qty           pm.max_qty%TYPE,      -- This will be in cases.
      max_qty_in_splits NUMBER,               -- max qty expressed as splits.
      mf_sw_ti          pm.mf_sw_ti%TYPE,     -- RDC small wood TI.
      aging_item        VARCHAR2(1),          -- Y for aging item otherwise N.
      aging_days        NUMBER,
      full_pallet_qty_in_splits NUMBER,  -- ti * hi * spc
      full_pallet_qty_in_cases NUMBER, -- ti * hi
      case_cube_for_calc NUMBER,  -- Case cube to use in calculations.
                                  -- Affected by extended case cube.
      mfr_shelf_life    pm.mfr_shelf_life%TYPE,
      sysco_shelf_life  pm.sysco_shelf_life%TYPE,
      cust_shelf_life   pm.cust_shelf_life%TYPE,
      pallet_stack      pm.pallet_stack%TYPE,
      pallet_stack_magic_num  pm.pallet_stack%TYPE,-- Value in
                                                   -- ct_pallet_stack_magic_num
      num_next_zones    swms_areas.num_next_zones%TYPE,
      --
      -- Information about the items pallet type.
      --
      pt_cube                         t_pt_cube,
      pt_skid_cube                    t_pt_skid_cube,
      pt_skid_height                  t_pt_skid_height,
      pt_ext_case_cube_flag           t_pt_ext_case_cube_flag,
      pt_putaway_use_repl_threshold   t_pt_putaway_use_replthreshold,  -- 10/24/2012 Brian Bent  No longer used.
      putaway_to_home_slot_method     t_pt_putaway_use_replthreshold,
      pt_putaway_floating_by_max_qty  t_putaway_floating_by_max_qty,
      --
      -- Info about the items home slot/last ship slot.  Putaway slots will
      -- be found closest to the value in put_aisle, put_slot and put_level.
      --
      -- Candidate putaway slots in a zone are selected closest to the
      -- put_aisle, put_slot and put_level.
      -- The put_aisle, put_slot and put_level can be assigned different
      -- values in the processing of the pallets for an item depending on if
      -- the item has a case home slot in a next zone when processing an item
      -- with a home slot or if a floating item has inventory in the zone.
      -- Initially put_aisle, put_slot and put_level will be that of the
      -- items rank 1 case home for a slotted item and the last ship_slot
      -- for a floating item.  If there is not a last ship slot then the
      -- values will be 0.  When a floating item is being processed and the
      -- item exists in the zone being processed then the values will be
      -- changed to the location the item is in based on ordering by
      -- i.exp_date, i.qoh, i.logi_loc.
      --
      put_aisle                 loc.put_aisle%TYPE,
      put_slot                  loc.put_slot%TYPE,
      put_level                 loc.put_level%TYPE,
      has_home_slot_bln         BOOLEAN,   -- Indicates if the item has a
                                           -- caes home slot.
      case_home_slot            loc.logi_loc%TYPE,   -- Rank 1 case home slot.
      case_home_slot_slot_type  slot_type.slot_type%TYPE, -- Rank 1 case home
                                                          -- slot slot type.
      case_home_slot_deep_ind   slot_type.deep_ind%TYPE, -- Rank 1 case home
                                                         -- slot deep indicator.
      case_home_slot_cube       t_cube := 0,        -- Rank 1 case home slot
                                                    -- cube.
      case_home_slot_true_slot_hgt  loc.true_slot_height%TYPE := 0, -- Rank 1
                                    -- case home slot true slot height.
      case_home_slot_deep_positions  t_deep_positions := 0, -- Rank 1
                                             -- case home slot deep positions.
      case_home_slot_width_positions loc.width_positions%TYPE := 0, -- Rank 1
                                             -- case home slot width positions.
      case_home_slot_total_positions  NUMBER := 0, -- Total positions in the
                                              -- rank 1 case home slot.
      last_ship_slot_cube       t_cube := 0,        -- Cube of the items last
                                                    -- ship slot if a floating
                                                    -- item and the item has a
                                                    -- valid last ship slot.
      last_ship_slot_height     loc.true_slot_height%TYPE,  -- Height of the
                                                    -- items last ship slot if
                                                    -- a floating item and the
                                                    -- item has a valid last
                                                    -- ship slot.
      --
      -- Additional flags.
      --
      round_inv_cube_up_to_ti_flag  sys_config.config_flag_val%TYPE,
                                                 -- Indicates if the current
                                                 -- inventory in a slot is to
                                                 -- be rounded up to a full Ti
                                                 -- when calculating the
                                                 -- occupied cube.  Populated
                                                 -- from a syspar.
      round_plt_cube_up_to_ti_flag  sys_config.config_flag_val%TYPE,
                                                 -- Indicates if the qty on
                                                 -- the pallet being received
                                                 -- is to be rounded up to a
                                                 -- full Ti when calculating
                                                 -- the cube of the pallet.
                                                 -- Populated from a syspar.
      partial_nondeepslot_search    sys_config.config_flag_val%TYPE,
                                                 -- Indicates the search order
                                                 -- of slots for a partial
                                                 -- pallet going to a
                                                 -- non-deep reserve slot.
                                         -- It is populated from one of
                                         -- the following syspars based on the
                                         -- area of the item.
                                         --    - partial_nondeepslot_search_clr
                                         --    - partial_nondeepslot_search_frz
                                         --    - partial_nondeepslot_search_dry
      floating_slot_sort_order      sys_config.config_flag_val%TYPE,
                                         -- Indicates the sort order of the
                                         -- candidate slots for a floating
                                         -- item.  It is populated from one of
                                         -- the following syspars based on the
                                         -- area of the item.
                                         --    - floating_slot_sort_order_clr
                                         --    - floating_slot_sort_order_frz
                                         --    - floating_slot_sort_order_dry
      --
      -- Fields for WAI.
      --
      split_zone_id             pm.split_zone_id%TYPE,  -- If the split for the
                                           -- item (if splittable) is stored in
                                           -- the miniloader then this will be
                                           -- populated with the miniloader
                                           -- zone.
      split_zone_rule_id        zone.rule_id%TYPE,  -- The rule id for
                                                    -- split_zone_id.
      auto_ship_flag            pm.auto_ship_flag%TYPE,
      miniload_storage_ind      pm.miniload_storage_ind%TYPE,
      case_induction_loc        loc.logi_loc%TYPE,
      split_induction_loc       loc.logi_loc%TYPE,
      case_qty_per_carrier      pm.case_qty_per_carrier%TYPE,
      max_miniload_case_carriers pm.max_miniload_case_carriers%TYPE,
      --
      -- Fields for splitting/not splitting a pallet on a SN when the qty is
      -- greater than the SWMS Ti Hi.
      -- 3/13/09 Brian Bent  Added.  At this time they are populated from
      --                             syspars.
      --
      split_rdc_sn_pallet_flag        sys_config.config_flag_val%TYPE,
      split_vendor_sn_pallet_flag     sys_config.config_flag_val%TYPE,
	  --
	  -- Matrix
	  mx_item_assign_flag             pm.mx_item_assign_flag%TYPE,
	  mx_min_case                     pm.mx_min_case%TYPE,
      mx_max_case                     pm.mx_max_case%TYPE,
      mx_food_type                    pm.mx_food_type%TYPE,
      mx_eligible                     pm.mx_eligible%TYPE,                     -- VR added
      avg_wt                          pm.avg_wt%TYPE, -- Jira 438
      --
      full_plt_minimize_option        sys_config.config_flag_val%TYPE
                                      -- Indicates if to minimize the travel
                                      -- distance from the home slot or find
                                      -- the best fit by size (cube or
                                      -- inches--whichever is active) when finding
                                      -- a suitable reserve slot for a full
                                      -- pallet for an item with a home slot.
                                      -- The valid values are 'D' for distance
                                      -- and 'S' for size.
                                      -- It is populated from one of the following
                                      -- syspars based on the area of the item.
                                      --    - full_plt_minimize_option_clr
                                      --    - full_plt_minimize_option_frz
                                      --    - full_plt_minimize_option_dry
                                      -- The cursors that selects the slots
                                      -- use it in the ORDER BY.
   );


   -------------------------------------------------------------------
   -- Record for the pallet to putaway.
   -------------------------------------------------------------------
   -- For a PO the qty will be broken into pallets.
   -- For a SN each SN line item is a pallet.
   -- This information, the item information and the putaway location will
   -- be used to create the putawaylst record and the inventory record.
   --
   -- The collect* fields desigate if the required data needs collecting
   -- for the pallet and are used to populate the corresponding putaway
   -- columns.
   -- The valid values are;
   --    - Y  The data needs to be collected.
   --    - N  The data is not to be collected.
   --    - C  The data has been collected.
   -- Not all fields will be populated depending on if a PO or SN is being
   -- processed and what the tracking values are.  These fields are used to
   -- set the corresponding columns in the putaway task.
   --
   -- 09/28/2016 Brian Bent
   -- Live Receiving changes.
   -- Added fields qty_expected and qty_received
   -- Fields qty, qty_expected and qty_received initially all set to the
   -- qty(in splits) on the pallet.
   -- The corresponding PUTAWAYLST fields set to these values when the
   -- PUTAWAYLST record is created.  During live receving check-in on the RF
   -- the user can change the qty received.  It's this value that will be used
   -- for the qty on the LP when finding the putaway location for the live
   -- receiving pallet.
   --
   -- 07/14/2017  Brian Bent
   -- When live receiving is active we still want to assign the induction
   -- location to the putawaylst.dest_loc and create the inventory for the
   -- pallets directed to the miniloader when the PO/SN is first opened.
   -- We don't want them to "LR".  If we do not do this then the "auto"
   -- create expected receipts does not happen when the PO/SN is first opened
   -- because the putawaylst dest_loc is "LR".
   -- Added field "direct_to_ml_induction_loc_bln".  The build pallet processing
   -- changed to set this to TRUE when the pallet is going to the miniloader
   -- induction location.  
   --
   TYPE t_r_pallet IS RECORD
   (
      pallet_id                  putawaylst.pallet_id%TYPE,
      prod_id                    putawaylst.prod_id%TYPE,
      cust_pref_vendor           putawaylst.cust_pref_vendor%TYPE,
      qty                        putawaylst.qty%TYPE, -- Qty on pallet in splits
      qty_expected               putawaylst.qty_expected%TYPE, -- Qty expected on pallet in splits.
      qty_received               putawaylst.qty_received%TYPE, -- Qty received on pallet in splits
                                                               -- Can updated during live receiving RF check-in of LP.
      qty_produced               putawaylst.qty_produced%TYPE, -- Qty produced from the production room (Added for Meat company iteration 1)                                                        
      uom                        putawaylst.uom%TYPE, -- The PO/SN uom.
      dest_loc                   putawaylst.dest_loc%TYPE,  -- Where the pallet
                                                            -- will go.
      dest_loc_is_home_slot_bln  BOOLEAN := FALSE, -- Indicates if the dest loc
                                                   -- is a home slot.
      item_index                 PLS_INTEGER,  -- Index of the item in the
                                               -- item plsql table.
      cube_without_skid          t_cube,       -- Cube of pallet without skid
      cube_with_skid             t_cube,       -- Cube of pallet including
                                               -- skid.
      cube_for_home_putaway      t_cube,       -- Cube of the pallet to use
                                               -- when directing the pallet to
                                               -- the home slot.  It will be
                                               -- cube_without_skid or
                                               -- cube_with_skid. For a partial
                                               -- pallet it will always be
                                               -- cube_without_skid.
      pallet_height_without_skid inv.pallet_height%TYPE,    -- Pallet height
                                                            -- without skid.
      pallet_height_with_skid    inv.pallet_height%TYPE,    -- Pallet height
                                                            -- including skid.
      pallet_height_for_home_putaway inv.pallet_height%TYPE,  -- Pallet height
                                           -- to use when directing the pallet
                                           -- to the home slot.  It will be
                                           -- pallet_height_without_skid or
                                           -- pallet_height_with_skid.  For a
                                           -- partial pallet it will always be
                                           -- pallet_height_without_skid.
      parent_pallet_id           inv.parent_pallet_id%TYPE := NULL, -- Added for meat 
                                                            -- company changes                                        
      erm_id                     erm.erm_id%TYPE,           -- PO/SN number
      erm_type                   erm.erm_type%TYPE,         -- Type--PO or SN
      erm_line_id                erd.erm_line_id%TYPE,      -- erd.erm_line_id
      seq_no                     PLS_INTEGER,               -- Sequence #.  For
                                                            -- a PO it will be
                                                            -- a number starting
                                                            -- at 1.  For a SN
                                                            -- it wll be the
                                                            -- erd.erm_line_id.
      sn_no                      putawaylst.sn_no%TYPE,     -- SN.  Populated
                                                            -- when processing
                                                            -- a SN.
      po_no                      putawaylst.po_no%TYPE,     -- PO.
      po_line_id                 putawaylst.po_line_id%TYPE, -- PO line id.
                                                            -- Populated when
                                                            -- processing a SN.
      shipped_ti                 erd_lpn.shipped_ti%TYPE,   -- Shipped TI. Used
                                                            -- for SN.
      shipped_hi                 erd_lpn.shipped_hi%TYPE,   -- Shipped HI. Used
                                                            -- for SN.
      sn_pallet_type             erd_lpn.pallet_type%TYPE,  -- SN pallet type
      exp_date                   erd_lpn.exp_date%TYPE,     -- Expiration date.
                                                        -- May be populated for
                                                            -- a SN.
      mfg_date                   erd_lpn.mfg_date%TYPE,     -- Mfg date. May
                                                            -- be populated for
                                                            -- a SN.
      lot_id                     erd_lpn.lot_id%TYPE,       -- Lot ID. May
                                                            -- be populated for
                                                            -- a SN.
      catch_weight               erd_lpn.catch_weight%TYPE, -- Catch weight. May
                                                            -- be populated for
                                                            -- a SN.
      temp                       erd_lpn.temp%TYPE,         -- Temperature.  May
                                                            -- be populated for
                                                            -- a SN.
      partial_pallet_flag VARCHAR2(1),  -- Indicates if the pallet is a partial
                                        -- pallet.  Values are Y or N.
      pallet_processed_bln BOOLEAN := FALSE,  -- Indicates if the pallet was
                                          -- processed which means a slot was
                                          -- found or it '*'ed out.
      direct_only_to_open_slot_bln BOOLEAN,  -- Indicates if the pallet is to
                                             -- be directed only to an open
                                             -- slot.  An example of a pallet
                                             -- that needs to go to an open
                                             -- slot is when receiving splits.
      miniload_reserve      BOOLEAN := FALSE,  -- Set to TRUE if the pallet is
                                               -- to be sent to miniload reserve.
      direct_to_ml_induction_loc_bln BOOLEAN := FALSE, -- Set to TRUE if the pallet is
                                                       -- to be sent to the miniload induction location.
      matrix_reserve        BOOLEAN := FALSE,  -- Set to TRUE if the pallet is
                                               -- to be sent to reserve for a
                                               -- matrix item.
      direct_to_mx_induction_loc_bln    BOOLEAN := FALSE,  -- Set to TRUE if the pallet is
                                                        -- to be sent to matrix induction location. 
      direct_to_prod_staging_loc     BOOLEAN := FALSE, -- Direct Production room POs to the inbound staging location.
                                                    -- to cust specific staging location
      cust_id               erd.cust_id%TYPE,       -- Jira 438: Cust ID used for inbound_cust_setup
      auto_confirm_put      VARCHAR2(1) := 'N',     -- Jira 438: Set to Y if the PO was auto opened for specialty company
      order_id              erd.order_id%TYPE,      -- Jira 438
      inv_weight            inv.weight%TYPE,        -- Jira 438: The weight to be inserted into inv. Should be weight of 1 cs
      collect_exp_date      putawaylst.exp_date_trk%TYPE,   -- Data collection
      collect_mfg_date      putawaylst.date_code%TYPE,      -- Data collection
      collect_lot_id        putawaylst.lot_trk%TYPE,        -- Data collection
      collect_catch_wt      putawaylst.catch_wt%TYPE,       -- Data collection
      collect_temp          putawaylst.temp_trk%TYPE,       -- Data collection
      collect_clam_bed      putawaylst.clam_bed_trk%TYPE,   -- Data collection
      collect_tti           putawaylst.clam_bed_trk%TYPE,   -- Data collection
      collect_cool          putawaylst.clam_bed_trk%TYPE,   -- Data collection
      inv_uom               inv.inv_uom%TYPE,               -- The value for
                                                            -- inv.inv_uom when
                                                            -- creating the
                                                            -- inventory record.
                                                            -- Added for ML.
      --
      -- Indicates if the pallet was created from splitting a SN pallet.
      -- 09/21/2016  Brian Bent  Not used since we never implemented the splitting
      --             SN pallet logic.
      from_splitting_sn_pallet_flag
                  putawaylst.from_splitting_sn_pallet_flag%TYPE, 
      --
      live_receiving_status VARCHAR2(4),  -- Designates if we are initially creating
                                          -- the PUTAWAYLST records when first opening
                                          -- a live receiving PO/SN or we are at the
                                          -- point of finding the putaway slot for the
                                          -- PUTAWAYLST record.  Valid values are
                                          -- 'OPEN' or 'SLOT'     
      demand_flag           putawaylst.demand_flag%TYPE := NULL, 
      -- S4R_Story_3840 (kchi7065) Populate door number now.
      door_no               putawaylst.door_no%TYPE
   );

   -------------------------------------------------------------------
   -- Location record.
   -------------------------------------------------------------------
   -- The structure matches that of the cursors that select the
   -- candidate locations in pl_rcv_open_po_cursors.sql.  It is used
   -- for the REF CURSOR.
   -- The structure always needs to match the cursors.  If the cursors
   -- change then this structure needs to be changed too.
   TYPE t_r_location IS RECORD
   (
      logi_loc          loc.logi_loc%TYPE,
      slot_type         t_slot_type,
      pallet_type       loc.pallet_type%TYPE,
      rank              loc.rank%TYPE,
      uom               loc.uom%TYPE,
      perm              loc.perm%TYPE,
      put_aisle         loc.put_aisle%TYPE,
      put_slot          loc.put_slot%TYPE,
      put_level         loc.put_level%TYPE,
      cube              t_cube,
      available_height  loc.available_height%TYPE,
      occupied_height   loc.occupied_height%TYPE,
      slot_height       loc.slot_height%TYPE,
      true_slot_height  loc.true_slot_height%TYPE,
      liftoff_height    loc.liftoff_height%TYPE,
      status            loc.status%TYPE,
      deep_ind          t_deep_ind,      -- Home slot deep indicator
      deep_positions    t_deep_positions,
      position_cube     t_cube,
      qoh               inv.qoh%TYPE,
      qty_planned       inv.qty_planned%TYPE,
      cube_used         t_cube,
      put_zone_id       zone.zone_id%TYPE
   );


   -------------------------------------------------------------------
   -- Splitting SN pallet
   -------------------------------------------------------------------
   --
   -- The record stores the information on how a SN pallet was split.
   -- This information will be used to create log messages.
   --
   TYPE t_r_how_sn_pallet_split IS RECORD
   (
      sn_pallet_index   PLS_INTEGER,     -- Index of the SN pallet in the
                                         -- pallet plsql table that was split
                                         -- to create the new pallet.
      qty                putawaylst.qty%TYPE, -- Qty, in splits, that
                                         -- was taken from the SN pallet and put
                                         -- on the new pallet.
      new_pallet_index  PLS_INTEGER      -- Index of the new pallet in the
                                         -- pallet plsql table.  This is the
                                         -- pallet created from splitting the
                                         -- SN pallet.
   );



   TYPE t_r_item_info_table IS TABLE OF t_r_item_info
       INDEX BY BINARY_INTEGER;

   TYPE t_r_location_table IS TABLE OF t_r_location
       INDEX BY BINARY_INTEGER;

   TYPE t_r_pallet_table IS TABLE OF t_r_pallet
       INDEX BY BINARY_INTEGER;

   TYPE t_r_how_sn_pallet_split_table IS TABLE OF t_r_how_sn_pallet_split
       INDEX BY BINARY_INTEGER;



   TYPE t_refcur_location IS REF CURSOR RETURN t_r_location;


--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------

-- Application function to use for the log messages.
ct_application_function   CONSTANT VARCHAR2(9) := 'RECEIVING';


-- What candidate putaway slots to check.
ct_open_slot               CONSTANT VARCHAR2(10) := 'OPEN';
ct_same_item_slot          CONSTANT VARCHAR2(10) := 'SAME_ITEM';
ct_any_non_empty_slot      CONSTANT VARCHAR2(30) := 'ANY_NON_EMPTY_LOCATION';
ct_different_item_slot     CONSTANT VARCHAR2(30) := 'DIFFERENT_ITEM';


----------------------------------------
-- Status of finding slots for the item.
----------------------------------------
-- The procedures that assign slots to the pallets sets a status parameter.
--
-- NOTE: In the context of finding slots a change in the uom even if it is
--       the same item is considered a different item.
--
ct_check_reserve   CONSTANT PLS_INTEGER := 1;  -- Not all the pallets were
                                               -- directed to the home slot.
                                               -- The next step is to direct
                                               -- the pallets to reserve.
ct_same_item       CONSTANT PLS_INTEGER := 2;  -- Still processing the
                                               -- same item.
                                               -- What differentiates an item
                                               -- is the:
                                               --    - prod_id
                                               --    - CPV
                                               --    - Receiving uom
                                               --    - Partial pallet flag
ct_new_item        CONSTANT PLS_INTEGER := 3;  -- The next pallet to process
                                               -- is for a different item.
                                               -- A change in the uom is
                                               -- considered a different item.
ct_no_pallets_left CONSTANT PLS_INTEGER := 4;  -- All the pallets have been
                                               -- processed.

--
-- Magic pm.pallet_stack number.  If pm.pallet_stack is set to this value
-- then no count is made of the existing pallets in an occupied slot so
-- that a little time can be saved by not having to query the database.
-- The cursors for occupied non deep slots in pl_rcv_open_po_cursors.sql
-- look at the pallet stack.
-- pl_rcv_open_po_pallet_list.get_item_info uses NVL(pm.pallet_stack, 99)
-- in the select stmt when selecting the item info and most OpCos have
-- pm.pallet_stack set to 99.
--
ct_pallet_stack_magic_num CONSTANT NUMBER := 99;


--
-- What to assign to PUTAWAYLST.DEST_LOC when opening a PO with Live
-- Receiving active.
--
ct_lr_dest_loc  CONSTANT VARCHAR2(2) := 'LR';


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------


END pl_rcv_open_po_types;  -- end package specification
/
