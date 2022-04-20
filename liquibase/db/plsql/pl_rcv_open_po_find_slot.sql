CREATE OR REPLACE  PACKAGE swms.pl_rcv_open_po_find_slot
AS

-- sccs_id=@(#) src/schema/plsql/pl_rcv_open_po_find_slot.sql, swms, swms.9, 11.2 12/17/09 1.28

---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_find_slot
--
-- Description:
--    This package is the driving package in directing pallets to slots
--    in the open PO/SN process.
--
--    The packages used in the open PO/SN process are:
--       - pl_rcv_open_po_types
--       - pl_rcv_open_po_cursors
--       - pl_rcv_open_po_pallet_list
--       - pl_rcv_open_po_find_slot
--       - pl_rcv_open_po_ml
--
--
--    The basic process flow is to build a list of the pallets on the PO/SN,
--    which is stored in a PL/SQL table, then direct the pallets to slots.
--    The items are stored in a separate PL/SQL table.  The pallet PL/SQL
--    table has the index of the item in the item PL/SQL table.
--    This package finds and assigns the pallets to the slots.
--    Package pl_rcv_open_po_pallet_list builds the pallet list.
--
--
----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
--        READ THIS    READ THIS    READ THIS    READ THIS    READ THIS
--
--    When processing the pallets a change of one of the following signifies
--    a new item.
--       - prod_id
--       - CPV
--       - Receiving uom
--       - Partial pallet flag
--
--    Processing is based on this.  A change would required a review of
--    all the programs.  The cursors in pl_rcv_open_po_cursors.sql also
--    depend on this.
----------------------------------------------------------------------------
----------------------------------------------------------------------------
--
--    Rules:
--    When putaway by cube:
--    Pallets, full or partial, will not be stacked in deep home slots
--    regardless if the pallet will fit or not.  Pallets can be stacked in
--    deep reserve slots.
--    For general and bulk rule zones pallets are directed to deep slots until
--    full following stackability rule.  This means pallets can be stacked.
--
--    pallet_label2.pc was filling a deep slot to the maximum cube if
--    the slot had a pallet of the item with a different receive date
--    and syspar MIX_SAME_PROD_DEEP_SLOT was Y.  Thus pallet_label2.pc was
--    stacking pallets in the deep slot if the slot was able to hold the
--    pallets.  But it would not stack if the slot was empty.  Now it will
--    not stack.
--
--    For non-deep slots pallets will be directed to the slot (home or
--    reserve) if the pallet will fit.  Pallets can be stacked in non-deep
--    slots.  FIFO logic applies.  Stackability logic applies only to
--    reserve slots.  Stackability is ignored for home slots.
--
--    When extended case cube is on a pallet will not be directed to the home
--    slot if the home slot has qoh or qty planned except if putaway is
--    by max qty.
--
--    The partial pallet of an item will be the first pallet directed to
--    the home slot if it will fit.  If it will not fit in the home slot
--    then it is processed last.
--    FIFO and stackability logic apply.
--
--    An aging item will always be put on hold.
--    An aging item will never be directed to the home slot.
--    pallet_label2.pc treating an aging item with a deep home slot as if the
--    the home slot was not a deep slot.  Now the deep logic is used for an
--    aging item with a deep home slot.
--
--    Splits for a slotted item will always be directed to the rank 1 split
--    home slot regardless of FIFO except if it is an aging item.
--
--    Splits for a floating item will always be directed to an empty floating
--    slot regardless of the setting of syspar NON_FIFO_COMBINE_PLTS_IN_FLOAT.
--
--    Splits will next zone.
--
--
--    The Search Order For Slots For Slotted Items:
--       Stackability logic always applies.
--
--       Non-Deep Slots  (the items rank 1 case home is a non-deep slot)
--
--         Partial pallets will go to the home slot before full pallets.
--         If a partial pallet cannot go to the home slot then it is
--         processed after the full pallets.
--
--         Full Pallet
--            1.  Home slot.
--                Note: pallet_label2.pc was ignoring the skid cube of the
--                      second pallet when two full pallets were directed
--                      to the home slot.  Now the skid cube is always
--                      considered for full pallets.
--            2.  Open non-deep slots.
--
--                The slot cube needs to be >= home slot cube to be
--                considered a candidate slot if pseudo syspar
--                chk_reserve_cube_ge_home_cube is 'Y' which it is.
--                If receiving splits then this rule does not apply.
--                08/20/05 prpbcb Pseudo syspar chk_reserve_cube_ge_home_cube
--                                default value is Y.
--            3.  Non-open non-deep slots that have at least one pallet of
--                the item.  The slot can have other items.
--            4.  Any non-deep with existing inventory, any product.
--         Partial Pallet
--            1.  Home slot.  Partial pallets will go to the home slot
--                before full pallets.  The skid cube of the partial pallet
--                is not considered when directing a pallet to the home
--                slot with qoh.  The skid cube of the partial pallet is not
--                considered if the home slot is empty a partial pallet is
--                directed to the home slot then a full pallet is directed
--                to the home slot.  It is expected the partial pallet qty
--                will be handstacked into the home slot.
--            2.  Non-open non-deep slots that have at least one pallet of
--                the item.
--            3.  Any non-empty non-deep slot, any product.
--            4.  Open non-deep slots.
--
--      Deep Slots  (the items rank 1 case home is a deep slot)
--         Applies for full and partial pallets.
--
--         Partial pallets will go to the home slot before full pallets.
--         If a partial pallet cannot go to the home slot then it is
--         processed after the full pallets.
--
--         1.  Home slot.
--         2.  Non-open slots that only have the same item in the slot.
--             Syspar MIX_SAME_PROD_DEEP_SLOT controls if to allow or not
--             allow putting away like items with different receive dates
--             to the same deep slot.
--         3.  Open deep slots.
--         4.  Any deep slot if syspar 2D3D_MIXPROD_FLAG is Y.
--             At this point the available slots will be occupied slots
--             with different items and could have a pallet of the same item.
--             If the slot has the same item then syspar
--             MIX_SAME_PROD_DEEP_SLOT controls if a pallet will be directed
--             to the slot.
--
--      Bulk Rule Zones
--        If the item exists in the bulk rule zone:
--          1.  Slots with the same item.
--          2.  Open slots.
--          3.  Slots with different items if syspar MIX_PROD_BULK_AREA is Y.
--
--        If the item does not exist in the bulk rule zone:
--          1.  Open slots.
--          2.  Slots with different items if syspar MIX_PROD_BULK_AREA is Y.
--
--    If an item is slotted to a bulk rule zone, though it should not be. the
--    bulk rule zone processing applies.
--
--    Receiving Splits of a Floating Items and Syspsr "Combine Pallets
--    in Float Slot":
--       Receiving splits of a floating item will always go to an empty
--       floating slot regardless of the setting of syspar "Combine Pallets
--       in Float Slot".  Splits need to go to empty slots.
--
--    Receiving splits will be considered a partial pallet.  This applies to
--    a PO or SN.
--
--    All splits of an item will go on one pallet.  This applies to a PO.
--
--    Extended Case Cube For Floating Items:
--       If extended case cube is on then the last ship slot is used to
--       calculate the extended case cube.  If the last ship is blank or is
--       no longer a valid location then the extended case cube is set to
--       the regular case cube.
--
--    Extended Case Cube When Receiving Splits:
--       Splits will use extended case cube.
--
--    If the erd.uom is 0 then any splits will be dropped.  This takes place
--    in pl_rcv_open_po_pallet_list.sql.
--    Example:
--       erd.uom = 0
--       SPC = 6
--       erd.qty is 25.  This is 4 cases and 1 split.
--       The qty will be processed as 24.  The 1 split will be dropped.
--
--    If pm.zone_id for a floating item is not rule 1 then the pallets
--    will "*".
--
--    The Search Order For Slots For Floating Items:
--       Item Has Inventory in the Zone
--          - Open slots closest to the current inventory slot with the
--            least exp date, qoh and location.
--            Note: pallet_label2.pc checked that the pallet_type.cube was
--                  >= cube of the pallet and also had
--                       AND l.cube >= DECODE(:last_pik_cube,
--                                            0.0, :std_pallet_cube,
--                                            :last_pik_cube)
--
--                  Now these checks are not made.  The pallet just needs
--                  to fit.
--
--       Item Does Not Have Inventory in the Zone
--          -  Open slots closest to the last ship slot.  The last ship slot
--             may or may not be in the zone.  The select stmt is the same
--             as when then item is in the zone except for the order by clause.
--             Note:  See note above.
--
--
--
--    08/22/05  The procedure/function calling order is:
--       find_slot (the main driver)
--          - pl_msku.p_assign_msku_putaway_slots
--
--          - get_putaway_syspars
--
--          - pl_rcv_open_po_pallet_list.build_pallet_list
--              - pl_rcv_open_po_pallet_list.build_pallet_list_from_po
--                 - pl_rcv_open_po_pallet_list.get_item_info
--                 - pl_rcv_open_po_pallet_list.f_get_new_pallet_id
--                 - pl_rcv_open_po_pallet_list.calc_pallet_size
--
--              - pl_rcv_open_po_pallet_list.build_pallet_list_from_sn
--                 - pl_rcv_open_po_pallet_list.calc_pallet_size
--
--          - direct_pallets_to_slots
--              - direct_pallets_to_home_slot
--                  - f_can_item_go_to_home_slot
--                  - insert_records
--                      - validate_set_sn_data_capture
--
--              - direct_pallets_to_rsrv_float
--                  - direct_to_floating_slots
--                      - set_put_path_values
--                      - pl_rcv_open_po_cursors.floating_slots
--                      - direct_pallets_to_slots_inzone
--                          - get_rsrv_float_occ_cube
--                          - insert_records
--
--              - direct_to_bulk_rule_zone
--                   - pl_rcv_open_po_cursors.bulk_rule_slots
--                   - pl_rcv_open_po_cursors.deep_slots
--                   - pl_rcv_open_po_cursors.deep_slots
--                   - direct_pallets_to_slots_inzone
--                      - insert_records
--
--              - no_slot_found
--
--
--    09/11/05  A Few Notes About Differenes Between pallet_label2.pc
--              and the New Packages
--                 When next zoning pallet_label2.pc was not always finding
--                 the same location.
--                 Example:
--                    A zone has 3 next zones.
--                       1 - C29
--                       2 - CB35
--                       3 - CD35
--                    All the locations in the first two next zones are DMG.
--                    There are no available locations in the primary zone.
--                    pallet_label2 found a location in the third next zone,
--                    CD35.
--                    Change the next zones to one next zones.
--                       1 - CD35
--                    A different location was found in CD35 than when it
--                    was the third next zone.  The location should have been
--                    the same as when zone CD35 was the third next zones.
--                 The new program will find the same location.
--
--                 pallet_label2.pc would stack pallets in deep slots in a
--                 general rule zone even if the stackable was 0.  This is
--                 incorrect.  If it was a bulk rule zone then it would not
--                 stack which is correct.
--
--                 pallet_label2.pc would stack pallets in deep slots in a
--                 general rule with directing a pallet to a slot with
--                 different items which occurs when syspar MIXPROD_2D3D_FLAG
--                 is Y.  The new program does the same.
--
--                 If an item is slotted to a bulk rule zone, ideally it
--                 should not be, pallet_label2.pc would never send any
--                 pallets to the home slot.  Now pallets will be sent to
--                 the home slot.  Basically a bulk rule zone that is the
--                 primary put zone for an item will be treated similar to
--                 a general rule zone.
--
--                 pallet_label2.pc would not next zone a partial pallet.
--                 Now a partial pallet is next zoned.
--
--                 pallet_label2.pc used the pm.zone_id as the driving zone.
--                 Now the zone of the rank 1 case home is the driving zone
--                 for a slotted item.  For a floating item the pm.zone_id
--                 is still the driving zone.
--
--                 pallet_label2.pc checked that slots with cube >= last ship
--                 slot cube.  This check is no longer made.
--
--                 pallet_label2.pc checked that the pallet_type.cube >=
--                 putaway pallet cube.  This check is no longer made.
--
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/05 prpbcb   Created.
--                      Putaway by cube and inches have been combined
--                      into one set of packages.  The plan is to use
--                      have these pacakages replace the logic in
--                      pallet_label2 and pl_pallet_label2.sql.
--
--                      Right know these new packages will not handle a
--                      transfer request or a demand LP so the old logic is
--                      followed in pallet_label2.pc.
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
--                      Fixes to bugs found by SQ.
--
--                      TD 6108:
--                      In function insert_records() changed
--                         'X',               -- equip_id, mandatory
--                         'X',               -- rec_lane_id, mandatory
--                      to
--                         ' ',               -- equip_id, mandatory
--                         ' ',               -- rec_lane_id, mandatory
--                      in the insert into the PUTAWAYLST table.
--                      pallet_label2.pc used a space.  The first run of
--                      this package used an 'X' because putting a space
--                      in the database is not the thing to do.  It was
--                      changed to a space because of SQ and also because
--                      of the unknown side effects of using a 'X'.
--
--                      TD 6116:
--                      The insert into PUTAWAYLST had NLD instead of
--                      HLD for the status for an aging item.
--
--    09/11/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Fixes to bugs found by SQ.
--                      Lot trk/lot id was not being assigned for a SN.
--
--                      Changed procedure insert_records() to always update
--                      erd_lpn.pallet_assigned_flag to Y.  Before it was
--                      not updating pallet_assigned_flag if the destination
--                      location was a '*'.
--
--                      Changes to handle 0 pallets in the pallet list.
--
--    09/11/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Changes to process a partial pallet as a separate
--                      entity when directing it to a non-deep reserve slot.
--                      This is because the search order for slots is
--                         1.  Home slot.
--                         2.  Non-open non-deep slots that have at least one
--                             pallet of the item.
--                         3.  Open non-deep slots.
--                         4.  Any non-deep slot, any product.
--                      which is different than a full pallet.
--
--    09/13/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      More changes.
--
--                      Limiting the number of slots in a zone used by
--                      an item was not working correctly.
--
--                      Changed procedure direct_pallets_to_rsrv_float()
--                      to assign locations based on the zone rule id which
--                      will follow the pallet_label2.pc logic.
--                      Before it was based on a combination of the item
--                      having a home slot and the zone rule id.
--                      Now it is based on the zone rule id.  A situation
--                      came up with SQ for a floating item that had a
--                      rule 0 zone for the items zone (this is not a
--                      normal situation, it should be a rule 1 zone).
--                      The old logic in this program always processed the
--                      item as a floating so the rule 0 zone was treated as
--                      a rule 1 zone which affects what locations the pallet
--                      can be directed to.
--
--                      Change function f_get_rsrv_slot_occupied_cube() to a
--                      procedure called get_slot_info() and
--                      had it determine the occupied cube and the positions
--                      used.
--
--                      Changed procedures directs_pallets_to_home_slot()
--                      and direct_pallets_to_slots_inzone() to "*" the pallet
--                      if processing a SN and the SN qty is greater than the
--                      SWMS Ti Hi.
--
--    09/27/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      More fixes.
--                      Last changes for 9.4
--
--    10/19/05 prpbcb   Oracle 8 rs239b swms9 DN 12016
--                      Fix bugs found after the last build for 9.4.
--                      These fixes will not go in 9.4 but most likely in
--                      and emergency build or an emergency ftp.
--
--                      Fixed bug in procedure direct_pallets_to_home_slot()
--                      that was checking if the number of positions in the
--                      slot was reached instead of the max qty when putaway
--                      was by max qty and it was a deep slot.
--                      Non-deep slots were OK.
--
--                      Changed formatting in some of the aplog messages.
--
--                      The search order for slots for a partial pallet of
--                      an item slotted to a non-deep slot was:
--                         1.  Home slot.
--                         2.  Non-open non-deep slots that have at least one
--                             pallet of the item.
--                         3.  Open non-deep slots.
--                         4.  Any non-empty non-deep slot, any product.
--                     This was not correct.  3 and 4 should be switched.
--                     The correct order is:
--                         1.  Home slot.
--                         2.  Non-open non-deep slots that have at least one
--                             pallet of the item.
--                         3.  Any non-empty non-deep slot, any product.
--                         4.  Open non-deep slots.
--
--                      Procedure get_slot_info() was using
--                      the case cube of the item currently being processed
--                      as the case cube for all the items in the slot even
--                      if a pallet in the slot was for a different item.
--                      This resulted in an incorrect occupied cube if the
--                      slot had different items.
--
--                      10/10/05  SWMS 9.4 installed at Lankford on 10/06/05.
--                      On Monday 10/10/05 a bug was reported where the open PO
--                      process was directing a pallet to a 2PB slot that
--                      already had 2 pallets.  I duplicated this on rs242q.
--                      This is because of the bug in procedure
--                      Procedure get_slot_info() that was
--                      calculating the occupied cube incorrectly.  (see the
--                      documentation a above).
--
--                      Changed procedure direct_pallets_to_slots_inzone() to
--                      work as based on a discussion with John Cavers.  This
--                      is for deep slots.  Changed comments in this file to
--                      reflect these changes.  Following is the email I sent
--                      to John.
--
--                      START OF EMAIL
--                      John,
--
--                      OpCo 10 Lankford was upgraded to SWMS 9.4 this past
--                      weekend which included bug fixes when directing pallets
--                      to slots when a PO/SN is opened.  When making the bug
--                      fixes parts of the program were rewritten which
--                      included directing pallets to deep slots.  When making
--                      the changes I verified the action of the new code
--                      against the action of the old code to make sure things
--                      worked the same.  What I found out after the Lankford
--                      upgraded is that the old program was treating empty
--                      deep slots differently from non-empty slots.  These
--                      differences are:
--                      1.  If the deep slot is empty then pallets will be
--                          directed to the deep slot until the number of
--                          positions is reached even if the slot can hold
--                          more.
--                          Example: Empty 2PB slot.  2 pallets will be
--                                   directed to the slot regardless if the
--                                   slot can hold more.
--
--                      2.  If the deep slot is not empty then pallets will be
--                          directed to the deep slot until the cube is
--                          reached.  Stackability is ignored.
--                          Example: 2PB slot that currently has 1 pallet of
--                                   the same item as on the PO/SN.  The cube
--                                   is such that 4 pallets can fit in the
--                                   slot.  The PO/SN has 3 full pallets of the
--                                   item.  The 3 pallets will be directed to
--                                   the slot.
--
--                      It may be that the differences are not causing any
--                      issues because the deep slot can only hold no more than
--                      the number of positions specified by the slot type.
--
--                      The new program handled empty deep slots the same as
--                      the old program.
--
--                      The new program handled non-empty deep slots like empty
--                      deep slots so pallets were directed to the slots until
--                      the number of positions was reached.
--
--                      After our discussion today I will change the new
--                      program to work like the old program.
--       *** 11/15/05 prpbcb  This change was not made.  The new program
--       ***                  directs pallets to deep slots until the number
--       ***                  of positions is reached.  No issues have been
--       ***                  raised by the OpCos.
--
--                      Brian Bent
--
--                      ------------------------------------------------------
--                      From: Thompson, Justin 000
--                      Sent: Tuesday, October 11, 2005 12:11 PM
--                      To: Bent, Brian 000
--                      Subject: RE: VM about Putaway problems in 9.4
--
--                      Brian,
--
--                      I did receive your voicemail yesterday.  I forwarded
--                      the msg on to Gary Mills for his input.  You might
--                      compose and email and send it on as well.
--
--                      Justin
--                      X5019
--                      ------------------------------------------------------
--                      END OF EMAIL
--
--
--                      Changed procedure validate_set_sn_data_capture to
--                      force data collection of the lot id if processing
--                      a SN, the item is lot tracked on SWMS, and the lot id
--                      that was in ERD_LPN starts with a P (upper or lower).
--                      WMS is putting the PO number in the lot id field
--                      on the SN with the value starting with a P.  If the
--                      WMS puts in a lot id that does not start with a P
--                      and the item is lot tracked on SWMS then this will be
--                      considered a valid lot id on SWMS.  Also note that a
--                      lot tracked item on SWMS may or may not be lot tracked
--                      at the RDC.
--
--    01/12/05 prpbcb   Oracle 8 rs239b swms9 DN 12043
--
--                      Rounding up quantity to nearest ti changes.
--                      Changed procedure get_putaway_syspars() to populate:
--                         - o_r_syspars.home_itm_rnd_inv_cube_up_to_ti
--                         - o_r_syspars.home_itm_rnd_plt_cube_up_to_ti
--                         - o_r_syspars.flt_itm_rnd_inv_cube_up_to_ti
--                         - o_r_syspars.flt_itm_rnd_plt_cube_up_to_ti
--                      All are set to 'Y' which maintains the current
--                      processing.  These are not actual syspars yet.
--
--                      Changed procedure get_putaway_syspars() to select
--                      new syspar PUTAWAY_TO_ANY_DEEP_SLOT.  The programs
--                      were already handling the syspar so nothing else
--                      needed changing.
--
--                      Changed procedure get_slot_info()
--                      to use i_r_item_info.round_inv_cube_up_to_ti_flag.
--                      Removed parameter i_cp_round_cube_to_nearest_ti.
--
--    01/20/06 prpbcb   Oracle 8 rs239b swms9 DN 12048
--                      WAI changes.
--                      Changed procedure insert_records() to populate
--                      inv.inv_uom.
--                      Changed procedure direct_pallets_to_slots() to call
--                      pl_rcv_open_po_ml.direct_to_induction_location().
--                      End WAI changes.
--
--                      Moved the following constants to pl_rcv_open_po_types.
--                         - ct_check_reserve
--                         - ct_same_item
--                         - ct_new_item
--                         - ct_no_pallets_left
--
--                      Changed the appropriate packages and procedures to
--                      use syspars
--                         - home_itm_rnd_inv_cube_up_to_ti
--                         - home_itm_rnd_inv_cube_up_to_ti
--                         - home_itm_rnd_plt_cube_up_to_ti
--                         - flt_itm_rnd_inv_cube_up_to_ti
--                         - flt_itm_rnd_plt_cube_up_to_ti
--                      and to use fields
--                         - round_inv_cube_up_to_ti_flag
--                         - round_plt_cube_up_to_ti_flag
--                      in the item info record to control rounding/not
--                      rounding the qty to a full ti when calculating the
--                      cube of the putaway pallet and the cube of existing
--                      pallets.  They were first created in defect 12043 but
--                      not used.
--                      02/21/06 prpbcb  At this time the actual method of
--                      rounding/not rounding the qty to a Ti is not yet
--                      finalized.  The Business Anaylsts and Distribution
--                      Services will decide this.  Right now the syspars
--                      do not exist so they will default to Y retains the
--                      current processing.  If syspars does not allow enough
--                      flexibility and control is moved to a different level
--                      such as the pallet type level then packages
--                         - pl_rcv_open_po_types
--                         - pl_rcv_open_po_cursors
--                         - pl_rcv_open_po_pallet_list
--                      and this package, pl_rcv_open_po_find_slot, need
--                      to be reviewed/changed.
--
--                      Slot search order changes for a partial pallet going
--                      to a non-deep reserve slot:
--                      Created procedure set_nondeep_partial_slotsearch() to
--                      set the search order using field
--                      "partial_nondeepslot_search" in the item info record.
--                      This field controls the search order of the slots for a
--                      partial pallet and is populated from one of the
--                      following syspars depending on the area of the item.
--                         - PARTIAL_NONDEEPSLOT_SEARCH_CLR
--                         - PARTIAL_NONDEEPSLOT_SEARCH_FRZ
--                         - PARTIAL_NONDEEPSLOT_SEARCH_DRY
--                      Changed procedure direct_to_non_deep_slots() to call
--                      set_nondeep_partial_slotsearch().
--                      Before the search order was fixed at the following
--                      for a partial pallet.
--                         1.  Non-open non-deep slots that have at least
--                             one pallet of the item.                   (A)
--                         2.  Any non-empty non-deep slot, any product. (B)
--                         3.  Open non-deep slots.                      (C)
--                      Now the syspar controls it.
--                      For documentation purposes the three different
--                      searches above are labeled (A), (B) and (C).
--                      Syspar NON_DEEP_PARTIAL_SLOT_SEARCH can have 4
--                      different values to correspond to the 4 combinations
--                      of the search order.  There is not 6 bacause there is
--                      no need to search (A) after (B) because (B) would
--                      include (A).  The syspar values and the resulting
--                      search order are:
--                       Syspar
--                       Value  Search Order
--                       -----  ---------------------------------------------
--                         1    (A) (B) (C)
--                         2    (A) (C) (B)
--                         3    (B) (C)
--                         4    (C) (A) (B)
--
--                      Changed 'ANY_LOCATION' to 'ANY_NON_EMPTY_LOCATION'
--                      to better reflect what it means.
--                      Changed to used constants instead of 'OPEN',
--                      'ANY_NON_EMPTY_LOCATION', etc.
--
--                      Implement syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS
--                      which is used to designate if an attempt should
--                      be made to direct a pallet to the home slot for
--                      a soft fifo item and there is not quantity in
--                      reserve and the home slot has qoh.
--                      This required changes to function
--                      f_can_item_go_to_home_slot().
--
--    03/07/06 prpbcb   Oracle 8 rs239b swms9 DN 12072
--                      WAI changes.
--                      Increased the length of some of the l_message
--                      variables.
--
--    03/16/06 prpbcb   Oracle 8 rs239b swms9 DN 12072
--                      Fix issue when putaway is by inches and pallets are
--                      directed to occupied deep slots but there is no space
--                      in the slot.  Procedure
--                      direct_pallets_to_slots_inzone().
--
--    03/24/06 prpbcb   Oracle 8 rs239b swms9 DN 12078
--                      When receiving splits to the mini-loader induction
--                      location the inv.inv_uom was set to 0 instead of 1.
--
--    06/01/06 prpbcb   Oracle 8 rs239b swms9 DN 12087
--                      Change procedure get_putaway_syspars() to
--                      populate o_r_syspars.chk_float_cube_ge_lss_cube.
--                      It is not used for anything yet.
--
--    06/09/06 prpbcb   Oracle 8 rs239b swms9 DN 12097
--                      Test Direct Defect: 6559
--                      Bug found during SQ testing.  When receiving splits
--                      the pallet is not directed to the correct slot.
--                      RULE:
--                      For an item with a home slot:
--                         If the splits cannot go to the home slot then
--                         they need to always go to an empty slot regardless
--                         of any syspar setting.
--                      For a floating item:
--                         The splits always go to an empty slot regardless
--                         of any syspar setting.
--
--    08/10/06 prpbcb   Oracle 8 rs239b swms9 DN 12114
--                      Ticket: 182100
--                      Project: 182100-Direct Pallet for Floating Item
--                      Finish changes to use syspar
--                      CHK_FLOAT_CUBE_GE_LSS_CUBE.
--                      This syspar designates to check/not check that the
--                      floating slot cube is >= last ship slot cube when
--                      selecting candidate OPEN floating slots for a
--                      floating item.
--
--    05/01/07 prpbcb   DN 12235
--                      Ticket: 265200
--                      Project: 265200-Putaway By Inches Modifications
--
--                      Implement logic for pm.pallet_stack.  It was missed
--                      when pallet_label2.pc was converted to PL/SQL.
--                      pallet_stack is the maximum number of pallets that
--                      can go in a non-deep slot reserve slot when directing
--                      pallets of the item to a slot.  Pallets are not stacked
--                      in deep slots so pallet_stack is ignored.
--                      Example: Item 1234567 has pallet stack set to 1.
--                               When directing a pallet to non-deep open slots
--                               only 1 pallet will be directed to the slot
--                               regardless if other pallets will fit and the
--                               stackable setting allows stacking.
--                               A pallet of the item will not be directed to
--                               a slot that has any existing pallets.
--                      Example: Item 7654321 has pallet stack set to 2.
--                               When directing a pallet to non-deep open slots
--                               at most 2 pallets will be directed to the
--                               slot--there needs to be space for the 2nd
--                               pallet and the stackable setting must be > 0.
--                               A pallet of the item will not be directed to
--                               a slot that has more that 1 existing pallet.
--
--                      Change procedure get_putaway_syspars() to
--                      populate o_r_syspars.chk_float_hgt_ge_lss_hgt.
--                      This is a new syspar.
--
--                      Modified to ignore stackability for the home slot.
--                      Did this by either commenting out the code or
--                      changing stackable = 0 to stackable < 0.
--
--                      Start changing the pl_log messages to pass the
--                      application function and program name on the
--                      command line.
--
--    05/16/07 prpbcb   DN 12235
--                      Ticket: 265200
--                      Project: 265200-Putaway By Inches Modifications
--
--                      Fixing stuff.
--
--                      Rename procedure get_rsrv_float_slot_occ_cube()
--                      to get_slot_info()
--
--    06/25/07 prpbcb   DN 12235
--                      Ticket: 265200
--                      Project: 265200-Putaway By Inches Modifications
--
--                      Bug fixes.
--                      Finish changing the pl_log messages to pass the
--                      application function and program name on the
--                      command line.
--
--    06/26/08 prpbcb   DN 12393
--                      Project: 614893-Check Last Ship Slot Height
--                      The change for for this project was adding
--                      syspar CHK_FLOAT_CUBE_GE_LSS_CUBE as the logic
--                      was already added to this program some time ago.
--
--                      Other changes included under this project are:
--
--                      Changed
--               SELECT SUM(NVL(catch_weight, 0)),
--                      SUM(NVL(qty, 0))
--                INTO l_total_weight, l_total_cases
--                FROM erd_lpn
--               WHERE prod_id          = io_r_pallet.prod_id
--                 AND cust_pref_vendor = io_r_pallet.cust_pref_vendor
--                 AND sn_no            = io_r_pallet.erm_id;
--                      to
--              SELECT NVL(SUM(NVL(catch_weight, 0)) 0),
--                     NVL(SUM(NVL(qty, 0)), 0)
--                INTO l_total_weight, l_total_cases
--                FROM erd_lpn
--               WHERE prod_id          = io_r_pallet.prod_id
--                 AND cust_pref_vendor = io_r_pallet.cust_pref_vendor
--                 AND sn_no            = io_r_pallet.erm_id;
--                      in procedure insert_records() because the sums could
--                      result in NULL instead of 0.  Though we have not
--                      experieced any problems.
--
--                      Fix bug when syspar
--                      "Partial Plt Slot Search <area>" was set to 3
--                      and no slots were found.  The program was returning
--                      an error instead of '*'ing the pallet.  Added
--                      parameter o_exhausted_options_bln to procedure
--                      set_nondeep_partial_slotsearch().  In procedure
--                      direct_to_non_deep_slots() added argument
--                      l_exhausted_options_bln in the call to procedure
--                      set_nondeep_partial_slotsearch().
--
--    03/13/09 prpbcb   DN 12474
--                      Incident:
--                      Project: CRQ7373-Split SN pallet if over SWMS Ti Hi
--
--                      Implement logic to split RDC SN pallet if the qty is
--                      over the SWMS Ti Hi.  The qty on the SN pallet will be
--                      reduced to the SWMS Ti Hi and the quantity over the
--                      SWMS Ti Hi will be put on a new pallet when the qty
--                      on the SN pallet is greater than the SWMS Ti Hi.
--                      If the item is expiration date tracked and the new
--                      pallet is made up of cases from different SN pallets
--                      with different expiration then the oldest expiration
--                      date is used for the new pallet.  Same thing applies
--                      for a manufacturer date tracked item.
--                      Syspar SPLIT_RDC_SN_PALLET control this.
--
--                      Modified procedure get_putaway_syspars() to select
--                      syspar SPLIT_RDC_SN_PALLET.
--
--                      Modified procedure insert_records() to populate
--                      putawaylst.from_splitting_sn_pallet_flag.
--
--                      Note: This is a current project to receive a SN
--                            from a vendor.  There is another syspar
--                            call SPLIT_VENDOR_SN_PALLET for splitting
--                            the pallet an a vendor SN.  More work is
--                            required to the open po programs to
--                            implement splitting a SN pallet on a vendor
--                            SN.  This will be done later when we are
--                            further into the project.
--
--    10/20/09 ctvgg000	ASN to all OPCOs project
--			Include VSN in the erm_type if condition.
--			This is to process pallets in a VN similar to SN.
--			A pallet on a VSN can also be "*" because 
--			the qty was greater than SWMS Ti Hi. So include this
--			to the if condition where erm_type IN ('SN', 'VN')	
--
--    11/06/09 prpbcb   Added AUTHID CURRENT_USER so things work correctly
--                      when pre-receiving into the new warehouse for a
--                      warehouse move.
--
--                      Changed cube variable type from NUMBER to
--                      type pl_rcv_open_po_types.t_cube.
--                      We would sometimes see pallets not getting directed
--                      to a home slot where the pallet would fit.
--                      Did this in procedures:
--                         - direct_pallets_to_home_slot
--                              variable l_available_cube
--                         - direct_pallets_to_slots_inzone
--                              variable l_available_cube
--                              variable l_occupied_cube
--
--    12/17/09 prpbcb   DN 12533
--                      Removed AUTHID CURRENT_USER.  We found a problem in
--                      pl_rcv_open_po_cursors.f_get_inv_qty when using it.
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
--                       pallet qty is <= max qty then direct the receiving
--                       pallet to the home slot.
--
--                     NOTE: FIFO rules always apply
--
--                     Field "putaway_to_home_slot_method" in the item record
--                     designates if to putaway by the min/max qty.
--                     record:
--                     The values for field "putaway_to_home_slot_method" are
--                         Y - putaway by min/max qty
--                         N - Normal processing
--                         NULL  - Normal processing
--                     Field "pt_putaway_use_repl_threshold" in the item
--                     record will not be used anymore since the name is
--                     somewhat confusing.  But we will still take the value
--                     for "putaway_to_home_slot_method"
--                     from column PALLET_TYPE.PUTAWAY_USE_REPL_THRESHOLD.
--                     Maybe at some time we can change the column name
--                     from PUTAWAY_USE_REPL_THRESHOLD to something more
--                     in line with what it means.
--
--                     Populate PUTAWAYLST.ERM_LINE_ID with the pallet
--                     record erm_line_id.  The check-in screen now needs
--                     PUTAWAYLST.ERM_LINE_ID to always be populated.
--
--    01/29/13 prpbcb  TFS Issue 63
--                     Fix issue found in testing putaway by min/max qty.
--                     There was a stmt not dividing the qty by spc.
--                     In procedure direct_pallets_to_home_slot()
--                     changed
--          ELSIF ( ((l_home_slot_qty_in_splits / l_spc) + io_r_pallet_table(io_pallet_index).qty) <= l_max_qty)
--                     to
--          ELSIF ( ((l_home_slot_qty_in_splits / l_spc) + (io_r_pallet_table(io_pallet_index).qty / l_spc)) <= l_max_qty)
--
--
--    07-AUG-14  sray0453 600000054 - European Imports Crossdock project
--                      Cross dock pallets zone with rule_id =4 would be
--                       assumed as rule_id = 1 and rule_id = 2
--                       when set as NEXT_ZONE to regular PUT zones.  
--                      This would enable warehouse to use those locations
--                      for regular putaway as well. 
--		   Changed  direct_pallets_to_rsrv_float to invoke both 
--		  direct_to_floating_slots and 
--		  direct_to_bulk_rule_zone 
--		  for rule_id 4 which is Cross docking zone.
--  28-OCT-2014 spot3255  Charm# 6000003789 - Ireland Cubic values - Metric conversion project
--                          Increased length of below variables to hold Cubic centimetre.
--                          l_chk_rsrv_cube_ge_home_cube from varchar2(10) to varchar2(14)
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
--                     Added the syspars to procedure "get_putaway_syspars".
--                     Added the syspars to procedure "show_syspars".
--                     Added the syspars to procedure "log_syspars".
--
--    01/08/16 bben0556  Brian Bent
--                       TFS:
-- R30.4--WIB#599--Charm6000010886_Open_PO_Fix_infinite_loop_when_receiving_splits_and_item_has_no_split_home
--                       Incident: 3256249
--
--                       Fix bug.
--                       Procedure "direct_pallets_to_split_home()" got into an
--                       infinite loop creating thousands of log messages when
--                       the item did not have a split home slot.
--                       Added call to procedure "no_slot_found()" when the item 
--                       does not have a split home slot.  Ideally the item 
--                       should have a split home but if not then we "*" the
--                       "split" pallets.  This issue first appeared at
--                       OpCo 349 Ireland since they can/do receive splits.
--                       OpCo 349 had an item with one home slot with
--                       LOC.UOM = 2 (data setup issue)
--                       At the US broadline OpCos we do not receive splits.
--                       Asian foods can/does receive splits.
--
--                       Moved ""no_slot_found()" to near the top of the
--                       package body.
--
--                       Fri Jan  8 18:51:58 CST 2016
--                       In procedure "find_slot()" there was variable
--                       l_status that was not being used.  Removed it.
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/06/16 bben0556 Brian Bent
--                      Project:
--              R30.6--WIE#669--CRQ000000008118_Live_receiving_story_15_cron_open_PO
--
--                      General process flow when Live Receiving is active:
--                      1. Open PO. A putawaylst record is created for each LP.
--                         The dest_loc will be 'LR'. No inventory created at this time.
--                         The 'LR' is defined in this constant definition in
--                         pl_rcv_open_po_types.sql:
--                               ct_lr_dest_loc  CONSTANT VARCHAR2(2) := 'LR';
--
--                      2. The receiver checks in the pallets which now consists of
--                         finding the putaway slot for the putawaylst record which will
--                         update putawaylst.dest_loc, create the inventory and then the
--                         LP is printed on a belt printer.
--
--
--                      Add syspar enable_live_receving to procedure "get_putaway_syspars".
--                      Add syspar enable_live_receving to procedure "show_syspars".
--                      Add syspar enable_live_receving to procedure "log_syspars".
--
--                      Modified:
--                      - Procedure "insert_records()"
--                      - Procedure "find_slot()"
--                        Call procedure "pl_rcv_open_po_lr.create_putaway_task()"
--                        when Live Receiving is active.
--
--    09/15/16 bben0556 Brian Bent
--                      Project:
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_33_find_dest_loc
--
--                      Changed some of the procedures from private to public.
--
--                      Changed to use the pallet list record qty received
--                      instead of the qty.
--                      We want to use the actual qty on the pallet.
--                      This comes into play when checking-in a live
--                      receiving pallet on the RF.  Otherwise the pallet list
--                      record qty and qty_received are the same.  Several
--                      procedures changed.
--
--
--    11/11/16 bben0556 Brian Bent
--                      Project:
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_11_rcv_load_worksheet
--
--                      Clam bed tracked item not being flagged as clam bed
--                      needed in PUTAWAYLST table.
--                      Changed procedure "get_putaway_syspars" to always
--                      retrieve syspar CLAM_BED_TRACKED regardless of
--                      Live Receiving syspar setting.
--
--
--    02/06/17 bben0556 Brian Bent
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_276_lock_records_when_finding_putaway_dest_loc
--
--                      Modified to lock the "find slot" processing when
--                      starting the process of finding slots for a PO/SN or LP.
--                      This locking needed for Live Receiving since different
--                      Receivers can be find putaway slots at the same time
--                      for different LP's.
--
--                      Added procedure "lock_putaway_find_slot_process()"
--                      Modified procedure "find_slot()" to call "lock_putaway_find_slot_process()"
--                      before the logic that finds the putaway destination
--                      location.
--
--
--    02/06/17 bben0556 Brian Bent
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_1228_SN_bug_fix
--
--                      Bug fix.  Opening a SN with Live Receiving active
--                      set the dest_loc to "LR".  Live Receiving does not
--                      apply to a SN. The SN processing is not changing
--                      for Live Receiving.
--
--                      Changed procedure "get_putaway_syspars" 
--                      Changed procedure "find_slot" 
--
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
--  3/14/2018           Vkal9662 Changed Find_slot to include PO type 'TR' 
--
--  07/10/18 mpha8134   Meat Company Project - Jira 438:
--                          Add procedure "insert_records_multi_lp_parent"
--
--                          Add procedure "direct_pallets_to_cust_staging"
--
--                          Modified procedure "direct_pallets_to_slots_inzone":
--                              -Add a call to insert_records_multi_lp_parent if the PO
--                              is an internal PO.
--                      
--                              -Slight change in logic for the non_fifo_combine_plts_in_float
--                              syspar. Multiple pallets can go to a floating loc if the zone is the 
--                              item's primary PUT zone, and if the slot's cube is 999 exactly (magic number!)
--                              regardless of if the syspar is turned on/off.
-- 01/21/19 mpha8134 Change from cust_staging to pit_location.
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/11/22 bben0556 Brian Bent
--                      R50_0_DML_OPCOF-3872_BUG_Miniload_items_asterisk_when_directed_to_main_whse_reserve
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
--                      Changed procedure get_putaway_syspars() to populate:
--                         - o_r_syspars.extended_case_cube_cutoff_cube
--                      Changed procedure log_syspars
--                      Changed procedure show_syspars
--

---------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


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
--    find_slot
--
-- Description:
--    This procedure finds and assigns the putaway slots for a PO/SN.
---------------------------------------------------------------------------
PROCEDURE find_slot(i_erm_id                 IN     erm.erm_id%TYPE,
                    i_pallet_id              IN     putawaylst.pallet_id%TYPE DEFAULT NULL,
                    i_use_existing_tasks_bln IN     BOOLEAN DEFAULT FALSE,
                    io_error_bln             IN OUT BOOLEAN,
                    o_crt_msg                OUT    VARCHAR2);

---------------------------------------------------------------------------
-- Procedure:
--    find_slot
--
-- Description:
--    This procedure finds and assigns the putaway slots for a PO/SN
--    allowing syspars to be passed as a parameter.
---------------------------------------------------------------------------
PROCEDURE find_slot
            (i_erm_id      IN     erm.erm_id%TYPE,
             i_r_syspars   IN     pl_rcv_open_po_types.t_r_putaway_syspars,
             io_error_bln  IN OUT BOOLEAN,
             o_crt_msg     OUT    VARCHAR2);

---------------------------------------------------------------------------
-- Procedure:
--    insert_records
--
-- Description:
--    This procedure inserts the PUTAWAYLST record and if the destination
--    location is not '*' inserts the INV record if the destination location
--    is not a home slot otherwise the home slot is updated.
--
--    For an SN, any required changes to the information tracking fielda are
--    made here as well as validation of the data.
--
--    If a location was found for a pallet and processing an SN then
--    erd_lpn.pallet_assigned_flag is updated to Y.
---------------------------------------------------------------------------
PROCEDURE insert_records
           (i_r_item_info  IN            pl_rcv_open_po_types.t_r_item_info,
            io_r_pallet    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet);


---------------------------------------------------------------------------
--  Procedure:
--      insert_records_multi_lp_parent
--
--  Description:
--      This procedure calls the insert_records procedure N number of times
--      based on number of case-LPs N that are on the parent pallet.
--         
---------------------------------------------------------------------------
PROCEDURE insert_records_multi_lp_parent (
            i_r_item_info       IN              pl_rcv_open_po_types.t_r_item_info,
            io_r_pallet_table   IN OUT NOCOPY   pl_rcv_open_po_types.t_r_pallet_table,
            io_pallet_index     IN OUT          PLS_INTEGER
);



---------------------------------------------------------------------------
-- Procedure:
--    get_putaway_syspars
--
-- Description:
--    This procedure gets the syspars required for finding a putaway slot
--    for a pallet.
---------------------------------------------------------------------------
PROCEDURE get_putaway_syspars
           (i_erm_id             IN         erm.erm_id%TYPE,
            i_find_slots_bln     IN         BOOLEAN DEFAULT FALSE,
            o_r_syspars          OUT NOCOPY pl_rcv_open_po_types.t_r_putaway_syspars);


---------------------------------------------------------------------------
-- Procedure:
--    p_add_fg_demand_lp
--
-- Description:
--    This procedure creates a demand license plate for finish good POs
---------------------------------------------------------------------------
PROCEDURE p_add_fg_demand_lp(
   i_erm_id IN erm.erm_id%TYPE,
   i_prod_id IN pm.prod_id%TYPE,
   i_cust_pref_vendor IN pm.cust_pref_vendor%TYPE,
   i_qty IN inv.qoh%TYPE,
   i_uom IN erd.uom%TYPE,
   i_status IN inv.status%TYPE);            


---------------------------------------------------------------------------
-- Procedure:
--    show_syspars
--
-- Description:
--    This procedure outputs the values of the syspars.  Used for debugging.
--
-- Parameters:
---------------------------------------------------------------------------
PROCEDURE show_syspars(i_r_syspars  IN pl_rcv_open_po_types.t_r_putaway_syspars);


---------------------------------------------------------------------------
-- Procedure:
--   log_syspars
--
-- Description:
--    This procedure logs the setting of the syspars.  It will not log
--    the "psuedo" syspars.
---------------------------------------------------------------------------
PROCEDURE log_syspars
           (i_r_syspars   IN pl_rcv_open_po_types.t_r_putaway_syspars,
            i_erm_id      IN erm.erm_id%TYPE);


---------------------------------------------------------------------------
--  Procedure: 
--      open_internal_po
--
--  Description:
--      Calls TP_wk_sheet2 to open the internal production POs
--
--
---------------------------------------------------------------------------
PROCEDURE open_internal_po;


END pl_rcv_open_po_find_slot;  -- end package specification
/



CREATE OR REPLACE PACKAGE BODY swms.pl_rcv_open_po_find_slot
AS

---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_find_slot
--
-- Description:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Oracle 8 rs239b swms9 DN _____
--                      Created.
--                      Putaway by cube and inches have been combined
--                      into one set of packages.
--   09/18/14  vred5319 Modified show_syspars
--    07-AUG-14  sray0453 600000054 - European Imports Crossdock project
--                      Cross dock pallets zone with rule_id =4 would be
--                       assumed as rule_id = 1 and rule_id = 2
--                       when set as NEXT_ZONE to regular PUT zones.  
--                      This would enable warehouse to use those locations
--                      for regular putaway as well.
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------

--
-- This cursor selects the put zones to look for slots in.
-- The item primary put zone is first followed by the next zones.
--
CURSOR gl_c_zones (cp_primary_put_zone IN zone.zone_id%TYPE) IS
   SELECT -99999           sort,   -- Make sure the primary put zone is first
          z.zone_id        zone_id,
          z.rule_id        rule_id,
          'P'              what_zone   -- P for primary put zone
     FROM zone z
    WHERE z.zone_id = cp_primary_put_zone
      AND z.rule_id <> 3
   UNION
   SELECT sort             sort,       -- Next zones
          nz.next_zone_id  zone_id,
          z.rule_id        rule_id,
          'N'              what_zone  -- N for next put zone
     FROM zone z,
          next_zones nz
    WHERE z.zone_id  = nz.next_zone_id
      AND nz.zone_id = cp_primary_put_zone
    ORDER BY 1;


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------

e_record_locked  EXCEPTION;
PRAGMA EXCEPTION_INIT(e_record_locked, -54);

e_record_locked_after_waiting  EXCEPTION;
PRAGMA EXCEPTION_INIT(e_record_locked_after_waiting, -30006);


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_rcv_open_po_find_slot';  -- Package name.
                                             --  Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Procedure:
--    lock_putaway_find_slot_process (Private)
--
-- Description:
--    The procedure locks the "find slot" processing so that it is run
--    only by one process at at time.
--    It it called at the beginning of the logic that finds the putaway
--    task destination location.
--
--    The locking is done by selecting the 'FIND_PUTAWAY_SLOT' entry
--    in table PROCESS_LOCK.  PROCESS_lOCK is a new table created for
--    Live Receiving.
--
--    For Live Receiving multiple receivers can be working at the same time.
--    We do not want the find slot processing to find the same slot for
--    different pallets.  Before Live Receiving is was expected only one
--    person was opening PO's--keeping in mind if multiple people were 
--    opening PO's then it was possible the same slot could be found for
--    different pallets.
--
-- Parameters:
--    None
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    find_slot procedure
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/17 bben0556 Created for Live Receiving
---------------------------------------------------------------------------
PROCEDURE lock_putaway_find_slot_process
IS
   l_message        VARCHAR2(512);
   l_object_name    VARCHAR2(30) := 'lock_putaway_find_slot_process';

   l_process_name   process_lock.process_name%TYPE;
BEGIN
   --
   -- Log starting
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                  'Starting procedure.'
                  || '  This procedure locks the "find slot" processing so that it is run'
                  || ' only by one process at at time.'
                  || ' It it called at the beginning of the logic that finds the putaway'
                  || ' task destination location.',
                  NULL, NULL, pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   --
   -- Start a new block to trap exceptions
   --
   -- First specify FOR UPDATE NOWAIT and if lock not successful then log
   -- a message and specify FOR UPDATE.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Attempting to lock the putaway find slot processing with FOR UPDATE NOWAIT...',
                     NULL, NULL, pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
   BEGIN
      SELECT process_name
        INTO l_process_name
        FROM process_lock
       WHERE process_name = 'FIND_PUTAWAY_SLOT'
         FOR UPDATE NOWAIT;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Locked the putaway find slot processing with FOR UPDATE NOWAIT',
                     NULL, NULL, pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
   EXCEPTION
      WHEN e_record_locked THEN
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Locking the find slot processing with FOR UPDATE NOWAIT failed.'
                      || '  Another using locking the processing.  Attempting to lock the putaway find slot processing with FOR UPDATE...',
                     SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

         SELECT process_name
           INTO l_process_name
           FROM process_lock
          WHERE process_name = 'FIND_PUTAWAY_SLOT'
            FOR UPDATE;

         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Locked the putaway find slot processing with FOR UPDATE',
                        NULL, NULL, pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

      WHEN NO_DATA_FOUND THEN
         --
         -- 02/17/2017 Brian Bent  For this log a message but do
         -- not stop processing.  We will see how this turns out.
         --
         l_message :=  'TABLE=process_lock'
                  || '  KEY=[FIND_PUTAWAY_SLOT]'
                  || '  ACTION=SELECT FOR UPDATE'
                  || '  MESSAGE="Did not find the record so could not perform the process lock.'
                  || '  This will not stop processing but if Live Receiving is active'
                  || ' then pallets can be directed to the same slot and they will not fit.';

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
   END;

   --
   -- Log ending
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Ending procedure  Lock Acquired',
                  NULL, NULL, pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      l_message := 'TABLE=process_lock'
                  || '  KEY=[FIND_PUTAWAY_SLOT]'
                  || '  ACTION=SELECT FOR UPDATE'
                  || '  MESSAGE="Failed selecting the record';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);
     
END lock_putaway_find_slot_process;


---------------------------------------------------------------------------
-- Procedure:
--    log_pallet_message_home_slot
--
-- Description:
--    This procedure writes an aplog message with common data followed
--    by text passed in a parameter for a pallet directed to a home slot.
--    Several aplog messages where almost identical except for the ending
--    text so this procedure was created to avoid duplicating code.
--
-- Parameters:
--    i_message_type     - Type of message. INFO, FATAL, etc.
--    i_object_name      - Object creating the message.
--    i_r_item_info      - Item information.
--    i_r_pallet         - Pallet information.
--    i_home_slot_qty    - Home slot qoh + qty planned.
--    i_available_cube   - Available cube in home slot.
--    i_available_height - Available height in home slot.
--    i_r_case_home_slot - Case home slot record.
--    i_message          - Additional text to include in message.
--                         Limit to <= 256 characters.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error - Got an error.
--
-- Called By:
--    - Various procedures.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE log_pallet_message_home_slot
     (i_message_type      IN VARCHAR2,
      i_object_name       IN VARCHAR2,
      i_r_item_info       IN pl_rcv_open_po_types.t_r_item_info,
      i_r_pallet          IN pl_rcv_open_po_types.t_r_pallet,
      i_home_slot_qty     IN PLS_INTEGER,
      i_available_cube    IN NUMBER,
      i_available_height  IN NUMBER,
      i_r_case_home_slot pl_rcv_open_po_cursors.g_c_case_home_slots%ROWTYPE,
      i_message           IN VARCHAR2)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'log_pallet_message_home_slot';
BEGIN
   pl_log.ins_msg(i_message_type, i_object_name,
       'LP[' || i_r_pallet.pallet_id || ']'
       || '  Item[' || i_r_pallet.prod_id || ']'
       || '  CPV[' || i_r_pallet.cust_pref_vendor || ']'
       || '  PO/SN[' || i_r_pallet.erm_id || ']'
       || '  Type[' || i_r_pallet.erm_type || ']'
       || ' destination loc[' || i_r_pallet.dest_loc || ']'
       || '  Putaway by min/max qty['
       || i_r_item_info.putaway_to_home_slot_method || ']'
       || '  Min qty[' || TO_CHAR(i_r_item_info.min_qty) || ']'
       || '  Max qty[' || TO_CHAR(i_r_item_info.max_qty) || ']'
       || '  Qty on Pallet: '
       || TO_CHAR(TRUNC(i_r_pallet.qty / i_r_item_info.spc))
       || ' case(s), '
       || TO_CHAR (MOD(i_r_pallet.qty, i_r_item_info.spc))
       || ' split(s).'
       || '  Qty Received on Pallet: '
       || TO_CHAR(TRUNC(i_r_pallet.qty_received / i_r_item_info.spc))
       || ' case(s), '
       || TO_CHAR (MOD(i_r_pallet.qty_received, i_r_item_info.spc))
       || ' split(s).'
       || '  UOM[' || TO_CHAR(i_r_pallet.uom) || ']'
       || '  Home slot[' || i_r_case_home_slot.logi_loc || ']'
       || '  Cube[' || TO_CHAR(i_r_case_home_slot.cube) || ']'
       || '  Slot type[' || i_r_case_home_slot.slot_type || ']'
       || '  Pallet type[' || i_r_case_home_slot.pallet_type || ']'
       || '  Deep slot[' || i_r_case_home_slot.deep_ind || ']'
       || '  Deep positions['
       || TO_CHAR(i_r_case_home_slot.deep_positions) || ']'
       || '  QOH + qty planned for home slot is '
       || TO_CHAR(TRUNC(i_home_slot_qty / i_r_item_info.spc)) || ' case(s), '
       || TO_CHAR (MOD(i_home_slot_qty, i_r_item_info.spc)) || ' split(s).'
       || '  Available cube in home slot['
       || TO_CHAR(i_available_cube) || '].'
       || '  Pallet cube without skid['
       || TO_CHAR(i_r_pallet.cube_without_skid) || '].'
       || '  Pallet cube with skid['
       || TO_CHAR(i_r_pallet.cube_with_skid) || '].'
       || '  Pallet cube for home putaway['
       || TO_CHAR(i_r_pallet.cube_for_home_putaway) || '].'
       || '  Available height in home slot['
       || TO_CHAR(i_available_height) || ']'
       || '  Pallet height without skid['
       || TO_CHAR(i_r_pallet.pallet_height_without_skid) || ']'
       || '  Pallet height with skid['
       || TO_CHAR(i_r_pallet.pallet_height_with_skid) || '].'
       || '  Pallet height for home putaway['
       || TO_CHAR(i_r_pallet.pallet_height_for_home_putaway) || '].'
       || '  Partial Pallet[' || i_r_pallet.partial_pallet_flag || '].'
       || '  ' || i_message,
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
          || '  i_r_pallet.pallet_id[' || i_r_pallet.pallet_id || ']'
          || '  i_object_name[' || i_object_name || ']'
          || '  PO/SN[' || i_r_pallet.erm_id || ']'
          || '  i_message[' || i_message || ']';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);
END log_pallet_message_home_slot;


---------------------------------------------------------------------------
-- Procedure:
--    log_pallet_message_rsrv_float
--
-- Description:
--    This procedure writes an aplog message with common data followed
--    by text passed in a parameter for a pallet directed to a reserve
--    or floating slot.  Several aplog messages where almost identical
--    except for the ending text so this procedure was created to avoid
--    duplicating code.
--
-- Parameters:
--    i_message_type     - Type of message. INFO, FATAL, etc.
--    i_object_name      - Object creating the message.
--    io_r_item_info     - Item information.
--    i_r_pallet         - Pallet information.
--    i_r_slot           - The reserve/floating slot.
--    i_available_cube   - Available cube in the slot.
--    i_available_height - Available height in the slot.
--    i_message          - Additional text to include in message.
--                         Limit to <= 256 characters.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error - Got an error.
--
-- Called By:
--    - Various procedures.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE log_pallet_message_rsrv_float
     (i_message_type      IN VARCHAR2,
      i_object_name       IN VARCHAR2,
      i_r_item_info       IN pl_rcv_open_po_types.t_r_item_info,
      i_r_pallet          IN pl_rcv_open_po_types.t_r_pallet,
      i_r_slot            IN pl_rcv_open_po_types.t_r_location,
      i_available_cube    IN NUMBER,
      i_available_height  IN NUMBER,
      i_message           IN VARCHAR2)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'log_pallet_message_rsrv_float';
BEGIN
   pl_log.ins_msg(i_message_type, i_object_name,
       'LP[' || i_r_pallet.pallet_id || ']'
       || '  Item[' || i_r_pallet.prod_id || ']'
       || '  CPV[' || i_r_pallet.cust_pref_vendor || ']'
       || '  PO/SN[' || i_r_pallet.erm_id || ']'
       || '  Type[' || i_r_pallet.erm_type || ']'
       || '  Destination loc[' || i_r_pallet.dest_loc || ']'
       || '  Qty on pallet: '
       || TO_CHAR(TRUNC(i_r_pallet.qty / i_r_item_info.spc))
       || ' case(s), '
       || TO_CHAR (MOD(i_r_pallet.qty, i_r_item_info.spc))
       || ' split(s).'
       || '  Qty received on pallet: '
       || TO_CHAR(TRUNC(i_r_pallet.qty_received / i_r_item_info.spc))
       || ' case(s), '
       || TO_CHAR (MOD(i_r_pallet.qty_received, i_r_item_info.spc))
       || ' split(s).'
       || '  UOM[' || TO_CHAR(i_r_pallet.uom) || ']'
       || '  Slot[' || i_r_slot.logi_loc || ']'
       || '  Slot type[' || i_r_slot.slot_type || ']'
       || '  Pallet type[' || i_r_slot.pallet_type || ']'
       || '  Deep slot[' || i_r_slot.deep_ind || ']'
       || '  Deep positions['
       || TO_CHAR(i_r_slot.deep_positions) || ']'
       || '  Available cube in slot['
       || TO_CHAR(i_available_cube) || ']'
       || '  Pallet cube without skid['
       || TO_CHAR(i_r_pallet.cube_without_skid) || ']'
       || '  Pallet cube with skid['
       || TO_CHAR(i_r_pallet.cube_with_skid) || ']'
       || '  Pallet cube for home putaway['
       || TO_CHAR(i_r_pallet.cube_for_home_putaway) || '].'
       || '  Available height in slot['
       || TO_CHAR(i_available_height) || ']'
       || '  Pallet height without skid['
       || TO_CHAR(i_r_pallet.pallet_height_without_skid) || ']'
       || '  Pallet height with skid['
       || TO_CHAR(i_r_pallet.pallet_height_with_skid) || ']'
       || '  Pallet height for home putaway['
       || TO_CHAR(i_r_pallet.pallet_height_for_home_putaway) || '].'
       || '  Partial pallet[' || i_r_pallet.partial_pallet_flag || '].'
       || '  ' || i_message,
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
          || '(i_r_pallet.pallet_id[' || i_r_pallet.pallet_id || ']'
          || ',i_object_name[' || i_object_name || ']'
          || '  PO/SN[' || i_r_pallet.erm_id || ']'
          || ',i_message[' || i_message || '])';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);
END log_pallet_message_rsrv_float;


---------------------------------------------------------------------------
-- Procedure:
--    log_pallet_message
--
-- Description:
--    This procedure writes an aplog message with common data followed
--    by text passed in a parameter.  Several aplog messages where almost
--    identical except for the ending text so this procedure was created
--    to avoid duplicating code.
--
-- Parameters:
--    i_message_type - Type of message. INFO, FATAL, etc.
--    i_object_name  - Object creating the message.
--    i_r_pallet     - Pallet information.
--    i_message      - Additional text to include in message.
--                     Limit to <= 256 characters.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error - Got an error.
--
-- Called By:
--    - Various procedures.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE log_pallet_message
              (i_message_type  IN VARCHAR2,
               i_object_name   IN VARCHAR2,
               i_r_item_info   IN pl_rcv_open_po_types.t_r_item_info,
               i_r_pallet      IN pl_rcv_open_po_types.t_r_pallet,
               i_message       IN VARCHAR2)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'log_pallet_message';
BEGIN
   pl_log.ins_msg(i_message_type, i_object_name,
       'LP[' || i_r_pallet.pallet_id || ']'
       || '  Item[' || i_r_pallet.prod_id || ']'
       || '  CPV[' || i_r_pallet.cust_pref_vendor || ']'
       || '  PO/SN[' || i_r_pallet.erm_id || ']'
       || '  Type[' || i_r_pallet.erm_type || ']'
       || ' destination loc[' || i_r_pallet.dest_loc || ']'

       || '  Qty on pallet: '
       || TO_CHAR(TRUNC(i_r_pallet.qty / i_r_item_info.spc))
       || ' case(s), '
       || TO_CHAR (MOD(i_r_pallet.qty, i_r_item_info.spc))
       || ' split(s).'
       || '  Qty received on pallet: '
       || TO_CHAR(TRUNC(i_r_pallet.qty_received / i_r_item_info.spc))
       || ' case(s), '
       || TO_CHAR (MOD(i_r_pallet.qty_received, i_r_item_info.spc))
       || ' split(s).'
       || '  UOM[' || TO_CHAR(i_r_pallet.uom) || ']'
       || '  Pallet cube without skid['
       || TO_CHAR(i_r_pallet.cube_without_skid) || ']'
       || '  Pallet cube with skid['
       || TO_CHAR(i_r_pallet.cube_with_skid) || ']'
       || '  Pallet height without skid['
       || TO_CHAR(i_r_pallet.pallet_height_without_skid) || ']'
       || '  Pallet height with skid['
       || TO_CHAR(i_r_pallet.pallet_height_with_skid) || ']'
       || '  Partial pallet[' || i_r_pallet.partial_pallet_flag || '].'
       || '  ' || i_message,
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
          || '(i_r_pallet.pallet_id[' || i_r_pallet.pallet_id || ']'
          || ',i_object_name[' || i_object_name || ']'
          || '  PO/SN[' || i_r_pallet.erm_id || ']'
          || ',i_message[' || i_message || '])';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
               gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);
END log_pallet_message;


---------------------------------------------------------------------------
-- Procedure:
--    no_slot_found
--
-- Description:
--    This procedure will "*" the pallets for the item being processed.
--    This happens when no slots could be found for some or all of the
--    pallets for the item.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_r_item_info        - Record of current item.
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--                           This will be incremented by the number of pallets
--                           "*".
--    o_status             - Status of "*"ing the pallets for the item.
--                           The value will be one of the following:
--                             - ct_no_pallets_left - All the pallets have been
--                                                    processed.
--                             - ct_new_item        - The next pallet to process
--                                                    is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE no_slot_found
  (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
   i_r_item_info         IN     pl_rcv_open_po_types.t_r_item_info,
   io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
   io_pallet_index       IN OUT PLS_INTEGER,
   o_status              IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'no_slot_found';

   l_previous_prod_id   pm.prod_id%TYPE;   -- The first item processed.  Used
                                           -- to check when the next pallet is
                                           -- for a different item or uom.

   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE;  -- The first CPV
                                           -- processed.  Used to check when
                                           -- the next pallet is for a
                                           -- different item or uom.

   l_previous_uom  erd.uom%TYPE;   -- The first uom processed.  Used to check
                                   -- when the next pallet is for a different
                                   -- item or uom.

   l_previous_partial_pallet_flag  VARCHAR2(1); -- The first value.  Used to
                                           -- check when the next pallet is for
                                           -- a different item or uom.

   l_num_pallets            PLS_INTEGER;  -- Number of pallets "*".
   l_original_pallet_index  PLS_INTEGER;  -- Used to save the initial value of
                                          -- io_pallet_index.  It is used in
                                          -- an aplog message.
BEGIN
   --
   -- Initialization
   --
   l_previous_prod_id := io_r_pallet_table(io_pallet_index).prod_id;
   l_previous_cust_pref_vendor :=
                        io_r_pallet_table(io_pallet_index).cust_pref_vendor;
   l_previous_uom := io_r_pallet_table(io_pallet_index).uom;
   l_previous_partial_pallet_flag :=
                        io_r_pallet_table(io_pallet_index).partial_pallet_flag;
   l_original_pallet_index := io_pallet_index;
   l_num_pallets := 0;
   o_status := pl_rcv_open_po_types.ct_same_item;

   --
   -- "*" the pallets for the item.
   --
   WHILE (o_status = pl_rcv_open_po_types.ct_same_item) LOOP

      io_r_pallet_table(io_pallet_index).dest_loc := '*';

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
       || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
       || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
       || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || ' destination loc[' || io_r_pallet_table(io_pallet_index).dest_loc
       || ']  No slot was found for this pallet.  "*" the pallet.',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      IF (io_r_pallet_table(io_pallet_index).dest_loc = '*' AND
         pl_putaway_utilities.f_is_pallet_in_pit_location(io_r_pallet_table(io_pallet_index).pallet_id) = 'Y') THEN
         -- Don't do anything if the pallet was auto-confirmed to the PIT location, and if no location was found during find_slot
         NULL;

      ELSE -- Normal logic
         insert_records(i_r_item_info, io_r_pallet_table(io_pallet_index));
      END IF;

      --
      -- Keep total number of pallets "*" for the item.  It is used in
      -- an aplog message.
      --
      l_num_pallets := l_num_pallets + 1;

      --
      -- See if the last pallet was processed.
      --

      IF (io_pallet_index = io_r_pallet_table.LAST) THEN
         o_status := pl_rcv_open_po_types.ct_no_pallets_left;
      ELSE
         --
         -- Advance to the next pallet.
         --
         io_pallet_index := io_r_pallet_table.NEXT(io_pallet_index);

         --
         -- If the next pallet to process is for a different item or uom
         -- then the processing is done for the current item.
         --
         IF (   l_previous_prod_id != io_r_pallet_table(io_pallet_index).prod_id
             OR l_previous_cust_pref_vendor !=
                    io_r_pallet_table(io_pallet_index).cust_pref_vendor
             OR l_previous_uom !=
                    io_r_pallet_table(io_pallet_index).uom
             OR l_previous_partial_pallet_flag !=
                    io_r_pallet_table(io_pallet_index).partial_pallet_flag) THEN
            --
            -- The next pallet is for a different item or uom.
            --
            o_status := pl_rcv_open_po_types.ct_new_item;
         ELSE
            --
            -- The next pallet is for the same item and uom.
            --
            NULL;
         END IF;
      END IF;
   END LOOP;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'Item[' || io_r_pallet_table(l_original_pallet_index).prod_id || ']'
       || '  CPV['
       || io_r_pallet_table(l_original_pallet_index).cust_pref_vendor || ']'
       || '  PO/SN[' || io_r_pallet_table(l_original_pallet_index).erm_id || ']'
       || '  This item had ' || TO_CHAR(l_num_pallets) || ' pallet(s)'
       || ' not assigned a slot.'
       || '  o_status[' || TO_CHAR(o_status) || '].',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,i_r_item_info,io_r_pallet_table,io_pallet_index'
         || 'o_status)'
         || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END no_slot_found;


---------------------------------------------------------------------------
-- Function:
--    f_can_item_go_to_home_slot
--
-- Description:
--    This function determines if an item is allowed to go to its
--    home slot.  If it cannot not then a aplog record is written
--    and FALSE returned otherwise TRUE is returned.
--
--    An aging item never goes to the home slot so FALSE is always returned.
--
-- Parameters:
--    i_r_syspars        - Putaway syspars.
--    i_check_type       - Type of check to make.  The valid values are:
--                            - FIFO  This designates to make the FIFO check
--                                    which will look for any inventory for
--                                    the item.
--                            - QTY   This designates to perform checks that
--                                    depend on the home slot have qty.
--    i_r_item_info      - Item information record
--    i_r_pallet         - Pallet record being processed.  Used in aplog
--                         messages.
--    i_r_case_home_slot - Case home record.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_home_slot
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/25/05 prpbcb   Created
--    03/01/06 prpbcb   Modified to check syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS
--                      which is used to designate if an attempt should
--                      be made to direct a pallet to the home slot for
--                      a soft fifo item when there is no quantity in
--                      reserve and the home slot has qoh.
--                      Before a soft fifo item could only go to the home slot
--                      if there was no inventory for the item.
--                      Added parameter i_r_syspars.
---------------------------------------------------------------------------
FUNCTION f_can_item_go_to_home_slot
     (i_r_syspars        IN pl_rcv_open_po_types.t_r_putaway_syspars,
      i_check_type       IN VARCHAR2,
      i_r_item_info      IN pl_rcv_open_po_types.t_r_item_info,
      i_r_pallet         IN pl_rcv_open_po_types.t_r_pallet,
      i_r_case_home_slot IN pl_rcv_open_po_cursors.g_c_case_home_slots%ROWTYPE)
RETURN BOOLEAN
IS
   l_message      VARCHAR2(512);    -- Message buffer
   l_object_name  VARCHAR2(30) := 'f_can_item_go_to_home_slot';

   l_buf               VARCHAR2(256);  -- Work area.
   l_inv_qty_found_bln BOOLEAN;        -- Value of cursor %FOUND.
   l_return_value      BOOLEAN := TRUE;

   e_bad_parameter  EXCEPTION;  -- Bad parameter.

   --
   -- This cursor sums the qoh and qty planned in the home slot(s) and reserve
   -- slot(s) for an item.  This is part of the information used in determining
   -- if a pallet can be directed to the home slot.
   --
   CURSOR c_inv_qty(cp_prod_id           inv.prod_id%TYPE,
                    cp_cust_pref_vendor  inv.cust_pref_vendor%TYPE) IS
      SELECT SUM(i.qoh + i.qty_planned) total_qty,
             SUM(DECODE(l.prod_id, NULL, 0, i.qoh + i.qty_planned)) home_qty,
             SUM(DECODE(l.prod_id, NULL, i.qoh + i.qty_planned, 0)) reserve_qty
        FROM loc l,
             inv i,
             lzone lz,
             zone z
       WHERE i.prod_id              = cp_prod_id
         AND i.cust_pref_vendor     = cp_cust_pref_vendor
         AND l.logi_loc (+)         = i.plogi_loc
         AND l.prod_id (+)          = i.prod_id
         AND l.cust_pref_vendor (+) = i.cust_pref_vendor
         AND i.plogi_loc             = lz.logi_loc
         AND lz.zone_id             = z.zone_id                         -- Zone/rule_id check added for the meat company changes. 
         AND z.rule_id              NOT IN ('9', '10', '11', '13', '14')  -- Inv in the zones should not be considered reserve for putaway logic.
       GROUP BY i.prod_id;

   r_inv_qty c_inv_qty%ROWTYPE;

BEGIN
   --
   -- An aging item never goes to the home slot.
   --
   IF (i_r_item_info.aging_item = 'Y') then
      l_return_value := FALSE;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
               'Item[' || i_r_item_info.prod_id || ']'
               || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
               || '  PO/SN[' || i_r_pallet.erm_id || ']'
               || '  This item is an aging item therefore no pallets will'
               || ' be directed to the home slot.',
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   ELSIF (i_check_type = 'FIFO') THEN
      --
      -- Make FIFO check.
      -- The rules are:
      -- If it is an absolute FIFO item and the item has any inventory then
      -- a pallet will not be directed to the home slot.
      -- If it is a soft FIFO item and syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS
      -- is set to 'N' and the item has any inventory then a pallet will not be
      -- directed to the home slot.
      -- If it is a soft FIFO item and syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS
      -- is set to 'Y' and there is inventory in reserve for the item then
      -- a pallet will not be directed to the home slot.
      --
      IF (i_r_item_info.fifo_trk IN ('A', 'S')) THEN
         --
         -- FIFO item.
         --
         -- Get the qty in inventory for the item.
         --
         OPEN c_inv_qty(i_r_item_info.prod_id,
                        i_r_item_info.cust_pref_vendor);
         FETCH c_inv_qty INTO r_inv_qty;
         l_inv_qty_found_bln := c_inv_qty%FOUND;  -- Save if rec found.
         CLOSE c_inv_qty;

         --
         -- Should always find a record since this function should be
         -- called only for an item with a home slot.
         --
         IF (l_inv_qty_found_bln) THEN
            --
            -- Log the innvetory qty.
            --
               pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Item[' || i_r_item_info.prod_id || ']'
                  || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
                  || '  PO/SN[' || i_r_pallet.erm_id || ']'
                  || '  FIFO track[' || i_r_item_info.fifo_trk || ']'
                  || '  QOH + qty planned in home slot(s): '
                  || TO_CHAR(TRUNC(r_inv_qty.home_qty / i_r_item_info.spc))
                  || ' case(s), '
                  || TO_CHAR(MOD(r_inv_qty.home_qty, i_r_item_info.spc))
                  || ' split(s),'
                  || '  QOH + qty planned in reserve slot(s): '
                  || TO_CHAR(TRUNC(r_inv_qty.reserve_qty / i_r_item_info.spc))
                  || ' case(s), '
                  || TO_CHAR(MOD(r_inv_qty.reserve_qty, i_r_item_info.spc))
                  || ' split(s),',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            IF (i_r_item_info.fifo_trk = 'A' AND r_inv_qty.total_qty > 0) THEN
               --
               -- Absolute fifo item and the item has inventory.  No pallets
               -- will be directed to the home slot.
               --
               l_return_value := FALSE;
               l_buf := 'Absolute fifo item and the item has inventory.'
                        || '  No pallets will be directed to the home slot.';
            ELSIF (i_r_item_info.fifo_trk = 'S' AND
                   i_r_syspars.putaway_to_home_if_fifo_allows = 'N' AND
                   r_inv_qty.total_qty > 0) THEN
               --
               -- Soft fifo item, syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS is
               -- N and the item has inventory.  No pallets will be directed
               -- to the home slot.
               --
               l_return_value := FALSE;
               l_buf := 'Soft fifo item, the item has inventory,'
                        || ' and syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS is'
                        || ' N.'
                        || '  No pallets will be directed to the home slot.';
            ELSIF (i_r_item_info.fifo_trk = 'S' AND
                   i_r_syspars.putaway_to_home_if_fifo_allows = 'Y' AND
                   r_inv_qty.reserve_qty > 0) THEN
               --
               -- Soft fifo item, syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS is
               -- Y and the item has inventory in reserve.  No pallets will
               -- be directed to the home slot.
               --
               l_return_value := FALSE;
               l_buf := 'Soft fifo item, the item has inventory in reserve,'
                        || ' and syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS is'
                        || ' Y.'
                        || '  No pallets will be directed to the home slot.';
            END IF;

            --
            -- Write aplog message if pallets will not be directed to the
            -- home slot.
            --
            IF (l_return_value = FALSE) THEN
               pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Item[' || i_r_item_info.prod_id || ']'
                  || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
                  || '  PO/SN[' || i_r_pallet.erm_id || ']'
                  || '  FIFO track[' || i_r_item_info.fifo_trk || ']'
                  || '  Syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS['
                  || i_r_syspars.putaway_to_home_if_fifo_allows || ']'
                  || '  ' || l_buf,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
            END IF;
         ELSE
            --
            -- The inventvory qty cursor found no record.  Ideally this should
            -- not happen but it will not stop processing.  Write an aplog
            -- message and return FALSE.

            l_return_value := FALSE;

            pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
               'Item[' || i_r_item_info.prod_id || ']'
               || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
               || '  PO/SN[' || i_r_pallet.erm_id || ']'
               || '  No record found when calculating the home slot qty'
               || ' and reserve qty for the item.  This should not happen.'
               || '  Returning FALSE.  Processing will continue.',
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
         END IF;
      ELSE
         --
         -- Item not fifo tracked.
         --
         NULL;
      END IF;
   ELSIF (i_check_type = 'QTY') THEN
      --
      -- Make qty check.
      --
      -- If the home slot has qoh and/or qty planned then the stackable and
      -- lot tracked can prevent a pallet from going to the home slot.
      --
      IF (i_r_case_home_slot.qoh + i_r_case_home_slot.qty_planned > 0) THEN
         --
         -- The home slot has qty.
         --
         -- Check the stackable.
         -- 05/05/07 Brian Bent Ignore stackability for home slot.
         --          Comment out the code.
         /*
         IF (i_r_item_info.stackable = 0) THEN
            --
            -- Item is not stackable and the home slot has qoh/qty planned.
            -- A pallet cannot go to the home slot.
            --
            l_return_value := FALSE;

            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Item[' || i_r_item_info.prod_id || ']'
               || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
               || '  Home Slot[' || i_r_case_home_slot.logi_loc || ']'
               || '  PO/SN[' || i_r_pallet.erm_id || ']'
               || '  Home slot has QOH or qty planned and the item has'
               || ' stackable of [' || TO_CHAR(i_r_item_info.stackable) || ']'
               || ' therefore no pallets will be directed to the home slot.',
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
         END IF;
         */

         --
         -- Check lot tracked.
         --
         IF (i_r_item_info.lot_trk = 'Y') THEN
            --
            -- Item is lot tracked and the home slot has qoh/qty planned.
            -- A pallet cannot go to the home slot.
            --
            l_return_value := FALSE;

            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Item[' || i_r_item_info.prod_id || ']'
               || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
               || '  PO/SN[' || i_r_pallet.erm_id || ']'
               || '  Item has QOH or qty planned to slot(s) and is'
               || ' lot tracked therefore no pallets'
               || ' will be directed to the home slot.',
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
         END IF;
      END IF;
   ELSE
      -- i_check_type has an unhandled value.  This is an error.
      RAISE e_bad_parameter;
   END IF;

   RETURN(l_return_value);

EXCEPTION
   WHEN e_bad_parameter THEN
      l_message := 'i_check_type[' || i_check_type || ']'
          || ' has an unhandled value.'
          || '  Item[' || i_r_item_info.prod_id || ']'
          || '  CPV[' || i_r_item_info.cust_pref_vendor || '].'
          || '  Home Slot[' || i_r_case_home_slot.logi_loc || '].'
          || '  PO/SN[' || i_r_pallet.erm_id || ']'
          || '  This stops processing.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

   WHEN OTHERS THEN
      l_message := l_object_name || '(i_check_type['
         || i_check_type || '],i_r_item_info,i_r_case_home_slot)'
         || '  Item[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || '].'
         || '  Home Slot[' || i_r_case_home_slot.logi_loc || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_can_item_go_to_home_slot;


---------------------------------------------------------------------------
-- Procedure:
--    set_put_path_values
--
-- Description:
--    This procedure sets the put_aisle, put_slot and put_level.
--
--    Candidate putaway slots in a zone are selected closest to the
--    put_aisle, put_slot and put_level.
--    The put_aisle, put_slot and put_level can be assigned different
--    values in the processing of the pallets for an item depending on if
--    the item has a case home slot in a next zone when processing an item
--    with a home slot or if a floating item has inventory in the zone.
--    Initially put_aisle, put_slot and put_level will be that of the
--    items rank 1 case home for a slotted item and the last ship_slot
--    for a floating item.  If there is not a last ship slot then the
--    values will be 0.  When a floating item is being processed and the
--    item exists in the zone being processed then the values will be
--    changed to the location the item is in based on ordering by
--    i.exp_date, i.qoh, i.logi_loc.
--
--    For an item with a home slot then procedure should only be called
--    when processing a next zone.
--
-- Parameters:
--    io_r_item_info  - Item record being processed.
--    i_r_zone        - zone record being processed.
--    i_erm_id        - PO/SN being processed.  Used in aplog messages.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_to_non_deep_slots
--    - direct_to_deep_slots
--    - direct_to_floating_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    xx/xx/xx prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE set_put_path_values
           (io_r_item_info  IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info,
            i_r_zone        IN     gl_c_zones%ROWTYPE,
            i_erm_id        IN     erm.erm_id%TYPE)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'set_put_path_values';

    --
    -- This cursor looks for a case home slot for the specified item in the
    -- specified zone.
    --
    CURSOR c_case_home (cp_prod_id           pm.prod_id%TYPE,
                        cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE,
                        cp_zone_id           zone.zone_id%TYPE) IS
       SELECT l.put_aisle, l.put_slot, l.put_level
         FROM lzone lz,
              loc   l
        WHERE l.logi_loc         = lz.logi_loc
          AND lz.zone_id         = i_r_zone.zone_id
          AND l.prod_id          = cp_prod_id
          AND l.cust_pref_vendor = cp_cust_pref_vendor
          AND l.perm             = 'Y'
          AND l.uom              IN (0, 2)
        ORDER BY l.rank;

    --
    -- This cursor looks for inventory for the specified item in the
    -- specified zone.  This is for a floating item.
    --
    CURSOR c_inv(cp_prod_id           pm.prod_id%TYPE,
                 cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE,
                 cp_zone_id           zone.zone_id%TYPE) IS
       SELECT l.put_aisle, l.put_slot, l.put_level
         FROM lzone lz,
              loc   l,
              inv   i
        WHERE l.logi_loc         = lz.logi_loc
          AND lz.zone_id         = i_r_zone.zone_id
          AND i.prod_id          = cp_prod_id
          AND i.cust_pref_vendor = cp_cust_pref_vendor
          AND i.plogi_loc        = l.logi_loc
        ORDER BY i.exp_date, i.qoh, i.logi_loc;

   r_case_home   c_case_home%ROWTYPE;
   r_inv         c_inv%ROWTYPE;
BEGIN
   IF (io_r_item_info.has_home_slot_bln = TRUE) THEN
      --
      -- The item has a home slot.
      --
      -- Look for a case home slot in the zone.
      --
      OPEN c_case_home(io_r_item_info.prod_id,
                       io_r_item_info.cust_pref_vendor,
                       i_r_zone.zone_id);
      FETCH c_case_home INTO r_case_home;

      IF (c_case_home%FOUND) THEN
         --
         -- The item has a case home slot in the zone.  Search for slots
         -- closest to this slot.
         --
         io_r_item_info.put_aisle := r_case_home.put_aisle;
         io_r_item_info.put_slot := r_case_home.put_slot;
         io_r_item_info.put_level := r_case_home.put_level;
      END IF;

      CLOSE c_case_home;

   ELSE
      --
      -- The item is a floating item.
      --
      -- Look for the item in the zone.  The zone should be a floating zone
      -- but may not be if a floating zone is next zoned to a non-floating
      -- zone for some unknown reason.
      --
      OPEN c_inv(io_r_item_info.prod_id,
                 io_r_item_info.cust_pref_vendor,
                 i_r_zone.zone_id);
      FETCH c_inv INTO r_inv;

      IF (c_inv%FOUND) THEN
         --
         -- The item has inventory in the zone.  Search for slots closest
         -- to the first slot with inventory.
         --
         io_r_item_info.put_aisle := r_inv.put_aisle;
         io_r_item_info.put_slot := r_inv.put_slot;
         io_r_item_info.put_level := r_inv.put_level;
      END IF;

      CLOSE c_inv;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
            || '(io_r_item_info, i_r_zone)'
            || '  Item[' || io_r_item_info.prod_id || ']'
            || '  CPV[' || io_r_item_info.cust_pref_vendor || ']'
            || '  Zone[' || i_r_zone.zone_id || ']'
            || '  PO/SN[' || i_erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END set_put_path_values;


---------------------------------------------------------------------------
-- Procedure:
--    get_slot_info
--
-- Description:
--    This procedure determines the cube occupied, positions used and qty
--    (qoh + qty planned) in a slot.  It is designed to be used for reserve
--     or floating slots and not home slots.
--
--    If the item on the putaway pallet currently being processed already
--    exists in the slot then we want to use the same case cube as what was
--    used for the putaway pallet.
--    Example:
--       1 pallet of item 1234567 to putaway.
--       Extended case cube is active.
--       The case cube is 2.  Extended case cube is 2.2.
--       Slot DA01A4 is selected as a candiate putaway slot.
--       Slot DA01A4 has 1 full pallet of item 1234567.
--       When calculating the cube occupied the case cube used for the
--       pallet already in the slot will be 2.2.
--
--    For the skid cube the items pallet type is used if it is not 0
--    otherwise the skid cube of the pallet type for the location is used.
--    The cube of a pallet is round to the nearest Ti unless specified
--    otherwise by parameter i_cp_round_cube_to_nearest_ti.
--
-- Parameters:
--    i_logi_loc         - The slot to find the occupied cube, positions used..
--    i_r_item_info      - Item record being processed.
--    i_erm_id           - PO/SN being processed.  Used in aplog messages.
--    o_occupied_cube    - Cube occupied in the slot.
--    o_positions_used   - Positions used in the slot.  This is also the
--                         number of pallets in the slot.  The value will
--                         be used for deep slots.
--    o_qty_in_slot      - QOH + qty planned (in splits)   Used when processing
--                                             floating slots and the same
--                                             item can be combined in the
--                                             slot.  For anything else this
--                                             value should be ignored.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots_inzone
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
--    08/12/05 prpbcb   Changed from a function to a procedure.
--    09/27/05 prpbcb   Changed to pass the case cube as a parameter and
--                      changed the cursor c_slot to use this parameter.
--    09/30/05 prpbcb   Changed to pass the item info record as a parameter.
--                      Fix bug that used the current item case cube as the
--                      cube for all the pallets in the slot.  This resulted
--                      in an incorrect occupied cube if the slot had
--                      different items.
--    11/29/05 prpbcb   Changed to use
--                      i_r_item_info.round_inv_cube_up_to_ti_flag.
--                      Removed parameter i_cp_round_cube_to_nearest_ti.
--    05/20/07 prpbcb   Added o_qty_in_slot.
---------------------------------------------------------------------------
PROCEDURE get_slot_info
     (i_logi_loc                     IN  loc.logi_loc%TYPE,
      i_r_item_info                  IN  pl_rcv_open_po_types.t_r_item_info,
      i_erm_id                       IN  erm.erm_id%TYPE,
      o_occupied_cube                OUT NUMBER,
      o_positions_used               OUT PLS_INTEGER,
      o_qty_in_slot                  OUT PLS_INTEGER)

IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'get_slot_info';

   --
   -- This cursor determines the cube occupied in a slot.  For the skid cube,
   -- the items pallet type is used if it is not 0 otherwise the skid cube
   -- of the pallet type for the location is used.  The cube of a pallet is
   -- round to the nearest ti unless otherwise specified.
   --
   -- The qty_in_slot is the qty (in splits) in the slot of the same item as
   -- the receiving pallet.  It is used when processing floating items and the
   -- same item can be combined in the slot.  For anything else this value
   -- should be ignored.
   --
   CURSOR c_slot
               (cp_logi_loc                  loc.logi_loc%TYPE,
                cp_prod_id                   pm.prod_id%TYPE,
                cp_cpv                       pm.cust_pref_vendor%TYPE,
                cp_case_cube                 NUMBER,
                cp_round_cube_to_nearest_ti  VARCHAR2) IS
      SELECT SUM(DECODE(SIGN(i.qoh + i.qty_planned),
                             0, 0,   -- Slot is empty so no skid cube.
                             DECODE(pt1.skid_cube,
                                    0, pt2.skid_cube,
                                    pt1.skid_cube)) +
              DECODE(cp_round_cube_to_nearest_ti,
                     'Y', CEIL(((i.qoh + i.qty_planned) / pm.spc) / pm.ti) *
                          pm.ti * DECODE(i.prod_id || i.cust_pref_vendor,
                                         cp_prod_id || cp_cpv, cp_case_cube,
                                         pm.case_cube),
                     CEIL((i.qoh + i.qty_planned) / pm.spc) *
                       DECODE(i.prod_id || i.cust_pref_vendor,
                              cp_prod_id || cp_cpv, cp_case_cube,
                              pm.case_cube)))     occupied_cube,
             COUNT(*) positions_used,
             SUM(DECODE(i.prod_id || i.cust_pref_vendor,
                     i_r_item_info.prod_id || i_r_item_info.cust_pref_vendor,
                     i.qoh + i.qty_planned,
                     0)) qty_in_slot
        FROM pallet_type pt1,
             pallet_type pt2,
             pm,
             inv i,
             loc loc     -- To get the pallet type of the location
       WHERE pt1.pallet_type      = pm.pallet_type
         AND pt2.pallet_type      = loc.pallet_type
         AND pm.prod_id           = i.prod_id
         AND pm.cust_pref_vendor  = i.cust_pref_vendor
         AND i.plogi_loc          = cp_logi_loc
         AND loc.logi_loc         = cp_logi_loc
       GROUP BY loc.logi_loc;
BEGIN
   OPEN c_slot(i_logi_loc,
               i_r_item_info.prod_id,
               i_r_item_info.cust_pref_vendor,
               i_r_item_info.case_cube_for_calc,
               i_r_item_info.round_inv_cube_up_to_ti_flag);

   FETCH c_slot INTO o_occupied_cube, o_positions_used, o_qty_in_slot;

   IF (c_slot%NOTFOUND) then
      --
      -- Slot is empty.
      --
      o_occupied_cube  := 0;
      o_positions_used := 0;
      o_qty_in_slot    := 0;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Slot[' || i_logi_loc || ']'
         || '  Item being processed[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || i_erm_id || ']'
         || '  Slot is empty.  Setting the program variables occupied cube,'
         || ' positions used and qty in slot to 0.',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   ELSE
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Slot[' || i_logi_loc || ']'
         || '  Occupied cube[' || TO_CHAR(o_occupied_cube) || ']'
         || '  Number of pallets in slot[' || TO_CHAR(o_positions_used) || ']'
         || '  Item being processed[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || i_erm_id || ']'
         || '  Rounding the qty on the pallet(s) in inventory to a full'
         || ' Ti when calculating the occupied cube is set to ['
         || i_r_item_info.round_inv_cube_up_to_ti_flag || ']',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   END IF;

   CLOSE c_slot;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
            || '(i_logi_loc[' || i_logi_loc || ']'
            || ',i_r_item_info.prod_id[' || i_r_item_info.prod_id || ']'
            || ',i_r_item_info.cust_pref_vendor['
            || i_r_item_info.cust_pref_vendor || ']'
            || 'i_erm_id[' || i_erm_id || ']'
            || ',o_occupied_cube,o_positions_used)';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END get_slot_info;


---------------------------------------------------------------------------
-- Procedure:
--    override_syspars
--
-- Description:
--    Override the syspars with those passed as a parameter.
--
-- Parameters:
--    i_erm_id      - PO/SN being processed.  Only used in aplog messages.
--    i_r_syspars   - Record of syspars.  What we want to use.
--    io_r_syspars  - Record of syspars that will be overwritten with
--                    what is in i_r_syspars.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - find_slot
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/07/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE override_syspars
      (i_erm_id     IN     erm.erm_id%TYPE,
       i_r_syspars  IN     pl_rcv_open_po_types.t_r_putaway_syspars,
       io_r_syspars IN OUT NOCOPY pl_rcv_open_po_types.t_r_putaway_syspars)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'override_syspars';

BEGIN
   --
   -- HOME_PUTAWAY
   --
   IF (    i_r_syspars.home_putaway IS NOT NULL
       AND i_r_syspars.home_putaway != io_r_syspars.home_putaway) THEN

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  HOME_PUTAWAY changed from [' || io_r_syspars.home_putaway || ']'
          || ' to [' || i_r_syspars.home_putaway || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.home_putaway := i_r_syspars.home_putaway;
   END IF;

   --
   -- MIXPROD_2D3D_FLAG
   --
   IF (    i_r_syspars.mixprod_2d3d_flag IS NOT NULL
       AND i_r_syspars.mixprod_2d3d_flag != io_r_syspars.mixprod_2d3d_flag)
   THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  MIXPROD_2D3D_FLAG changed from ['
          || io_r_syspars.mixprod_2d3d_flag || ']'
          || ' to [' || i_r_syspars.mixprod_2d3d_flag || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.mixprod_2d3d_flag := i_r_syspars.mixprod_2d3d_flag;
   END IF;

   --
   -- MIX_PROD_BULK_AREA
   --
   IF (    i_r_syspars.mix_prod_bulk_area IS NOT NULL
       AND i_r_syspars.mix_prod_bulk_area != io_r_syspars.mix_prod_bulk_area)
   THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  MIX_PROD_BULK_AREA changed from ['
          || io_r_syspars.mix_prod_bulk_area || ']'
          || ' to [' || i_r_syspars.mix_prod_bulk_area || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.mix_prod_bulk_area := i_r_syspars.mix_prod_bulk_area;
   END IF;

   --
   -- MIX_SAME_PROD_DEEP_SLOT
   --
   -- Mix like items with different receive dates in the same deep slot.
   --
   IF (    i_r_syspars.mix_same_prod_deep_slot IS NOT NULL
       AND i_r_syspars.mix_same_prod_deep_slot !=
                                   io_r_syspars.mix_same_prod_deep_slot) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  mix_same_prod_deep_slot changed from ['
          || io_r_syspars.mix_same_prod_deep_slot || ']'
          || ' to [' || i_r_syspars.mix_same_prod_deep_slot || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.mix_prod_bulk_area := i_r_syspars.mix_prod_bulk_area;
   END IF;

   --
   -- PALLET_TYPE_FLAG
   --
   IF (    i_r_syspars.pallet_type_flag IS NOT NULL
       AND i_r_syspars.pallet_type_flag != io_r_syspars.pallet_type_flag) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  pallet_type_flag changed from ['
          || io_r_syspars.pallet_type_flag || ']'
          || ' to [' || i_r_syspars.pallet_type_flag || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.pallet_type_flag := i_r_syspars.pallet_type_flag;
   END IF;

   --
   -- PUTAWAY_DIMENSION
   --
   IF (    i_r_syspars.putaway_dimension IS NOT NULL
       AND i_r_syspars.putaway_dimension != io_r_syspars.putaway_dimension) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  putaway_dimension changed from ['
          || io_r_syspars.putaway_dimension || ']'
          || ' to [' || i_r_syspars.putaway_dimension || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.putaway_dimension := i_r_syspars.putaway_dimension;
   END IF;

   --
   -- CLAM_BED_TRACKED
   --
   IF (    i_r_syspars.clam_bed_tracked IS NOT NULL
       AND i_r_syspars.clam_bed_tracked != io_r_syspars.clam_bed_tracked) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  clam_bed_tracked changed from ['
          || io_r_syspars.clam_bed_tracked || ']'
          || ' to [' || i_r_syspars.clam_bed_tracked || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.clam_bed_tracked := i_r_syspars.clam_bed_tracked;
   END IF;

   --
   -- NON_FIFO_COMBINE_PLTS_IN_FLOAT
   --
   IF (    i_r_syspars.non_fifo_combine_plts_in_float IS NOT NULL
       AND i_r_syspars.non_fifo_combine_plts_in_float !=
                          io_r_syspars.non_fifo_combine_plts_in_float) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'PO/SN[' || i_erm_id || ']'
          || '  non_fifo_combine_plts_in_float changed from ['
          || io_r_syspars.non_fifo_combine_plts_in_float || ']'
          || ' to [' || i_r_syspars.non_fifo_combine_plts_in_float || ']',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      io_r_syspars.non_fifo_combine_plts_in_float :=
                                 i_r_syspars.non_fifo_combine_plts_in_float;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
          || '  PO/SN[' || i_erm_id || ']'
          || '  Failed to override the syspars.';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message);

END override_syspars;




---------------------------------------------------------------------------
-- Procedure:
--    set_nondeep_partial_slotsearch
--
-- Description:
--    This procedure defines the slots to search when processing a
--    partial pallet going to a non-deep reserve slot.
--
--    Syspars
--       PARTIAL_NONDEEPSLOT_SEARCH_CLR
--       PARTIAL_NONDEEPSLOT_SEARCH_FRZ
--       PARTIAL_NONDEEPSLOT_SEARCH_DRY
--    control the search order of the slots for a partial pallet based on
--    the area of the item.
--    (02/20/06 prpbcb) The search order was fixed at the following:
--       1.  Non-open non-deep slots that have at least
--           one pallet of the item.                   (A)
--       2.  Any non-empty non-deep slot, any product. (B)
--       3.  Open non-deep slots.                      (C)
--    Now the syspars control it.
--
--    When the item information is being retrieved field
--    "partial_nondeepslot_search" in the item info record is set to the
--    appropriate syspar value as determined by the area of the item.
--    For documentation purposes the three different searches above are
--    labeled with (A), (B) and (C).  The syspars can have 4 different values
--    to correspond to the 4 combinations of the search order.  There is not
--    6 bacause there is no need to search (A) after (B) because (B) would
--    include (A).  The syspar values and the resulting search order are:
--       Syspar
--       Value  Search Order
--       -----  ---------------------------------------------
--         1    (A) (B) (C)
--         2    (A) (C) (B)
--         3    (B) (C)       Because there are only two search options
--                            o_exhausted_options_bln comes into play
--                            as it will tell the calling program when
--                            all the search options have been reached.
--                            For 1, 2 and 4 the calling program keeps track
--                            since they all have three search options.
--         4    (C) (A) (B)
--
--    Parameter io_what_slots_to_check will be set to one of the following
--    (package constants are used) depending on what the value is in item
--    info field partial_nondeepslot_search.
--    were last checked.
--       - SAME_ITEM              For (A)
--       - ANY_NON_EMPTY_LOCATION For (B)
--       - OPEN                   For (C)
--
-- Parameters:
--    i_r_item_info          - Item information.
--    i_r_pallet             - Pallet information.
--    io_what_slots_to_check - What slots to check which will be set to a
--                             package constant to indicate one of the
--                             following:
--                                - Slots with the same item being received.
--                                - Any non-empty slots.
--                                - Open slots.
--    o_processing_occupied_slots  - Indicates if the slots to check are
--                                   occupied.
--    o_message               - Used by calling program for an aplog message.
--    o_exhausted_options_bln - Set to TRUE if all the options of
--                              i_r_item_info.partial_nondeepslot_search
--                              have been exhausted.  Otherwise it is set
--                              to FALSE.  Note it is only used when
--                         i_r_item_info.partial_nondeepslot_search is '3'.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error     - A parameter has an unhandled value.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called By:
--    - direct_to_non_deep_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/20/06 prpbcb   Created
--    06/14/06 prpbcb   Changed to set io_what_slots_to_check to check
--                      open slots when
--                      i_r_item_info.direct_only_to_open_slot_bln is TRUE.
--    06/26/08          Added parameter o_exhausted_options_bln.  It is set
--                      to TRUE if all the options of
--                      i_r_item_info.partial_nondeepslot_search have been
--                      exhausted.  Otherwise it is set to FALSE.  Note it is
--                      only used when i_r_item_info.partial_nondeepslot_search
--                      is '3' because this only has two search options while
--                      anything other than '3' has three seach options
--                      which the calling program keeps track of.
---------------------------------------------------------------------------
PROCEDURE set_nondeep_partial_slotsearch
    (i_r_item_info               IN     pl_rcv_open_po_types.t_r_item_info,
     i_r_pallet                  IN     pl_rcv_open_po_types.t_r_pallet,
     io_what_slots_to_check      IN OUT VARCHAR2,
     o_processing_occupied_slots OUT    BOOLEAN,
     o_message                   OUT    VARCHAR2,
     o_exhausted_options_bln     OUT    BOOLEAN)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'set_nondeep_partial_slotsearch';

   e_unhandled_slot_search   EXCEPTION;  -- Unhandled slot search.
   e_unhandled_what_loc      EXCEPTION;  -- Unhandled value in
                                         -- io_what_slots_to_check.
BEGIN

   l_message :=
         'Starting function  Item[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_r_item_info.partial_nondeepslot_search['
         || i_r_item_info.partial_nondeepslot_search || ']'
         || '  io_what_slots_to_check[' || io_what_slots_to_check || ']';
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

   --
   -- Initialization.
   --
   o_exhausted_options_bln := FALSE;

   --
   -- Set the slots to search.
   --
   IF (i_r_pallet.direct_only_to_open_slot_bln = FALSE) THEN
      IF (i_r_item_info.partial_nondeepslot_search = '1') THEN
         --***************************************************
         -- Search option 1
         --***************************************************
         IF (io_what_slots_to_check IS NULL) THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_same_item_slot;
            o_processing_occupied_slots := TRUE;
            o_message := 'Partial pallet.  Directing pallets to non-deep slots'
                         || ' with the same item.';
         ELSIF (io_what_slots_to_check = pl_rcv_open_po_types.ct_same_item_slot)
                                                                         THEN
            io_what_slots_to_check :=
                               pl_rcv_open_po_types.ct_any_non_empty_slot;
            o_processing_occupied_slots := TRUE;
            o_message := 'Partial pallet.  Directing pallets to any available'
                         || ' occupied non-deep slots.';
         ELSIF (io_what_slots_to_check =
                              pl_rcv_open_po_types.ct_any_non_empty_slot) THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_open_slot;
            o_processing_occupied_slots := FALSE;
            o_message := 'Partial pallet.  Directing pallets to open non-deep'
                         || ' slots.';
         ELSE
            --
            -- io_what_slots_to_check has an unhandled value.
            --
            RAISE e_unhandled_what_loc;
         END IF;
      ELSIF (i_r_item_info.partial_nondeepslot_search = '2') THEN
         --***************************************************
         -- Search option 2
         --***************************************************
         IF (io_what_slots_to_check IS NULL) THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_same_item_slot;
            o_processing_occupied_slots := TRUE;
            o_message := 'Partial pallet.  Directing pallets to non-deep slots'
                         || ' with the same item.';
         ELSIF (io_what_slots_to_check = pl_rcv_open_po_types.ct_same_item_slot)
                                                                           THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_open_slot;
            o_processing_occupied_slots := FALSE;
            o_message := 'Partial pallet.  Directing pallets to open non-deep'
                         || ' slots.';
         ELSIF (io_what_slots_to_check = pl_rcv_open_po_types.ct_open_slot) THEN
            io_what_slots_to_check :=
                                   pl_rcv_open_po_types.ct_any_non_empty_slot;
            o_processing_occupied_slots := TRUE;
            o_message := 'Partial pallet.  Directing pallets to any available'
                         || ' occupied non-deep slots.';
         ELSE
            --
            -- io_what_slots_to_check has an unhandled value.
            --
            RAISE e_unhandled_what_loc;
         END IF;
      ELSIF (i_r_item_info.partial_nondeepslot_search = '3') THEN
         --***************************************************
         -- Search option 3
         --***************************************************
         IF (io_what_slots_to_check IS NULL) THEN
            io_what_slots_to_check :=
                               pl_rcv_open_po_types.ct_any_non_empty_slot;
            o_processing_occupied_slots := TRUE;
            o_message := 'Partial pallet.  Directing pallets to any available'
                         || ' occupied non-deep slots.';
         ELSIF (io_what_slots_to_check =
                               pl_rcv_open_po_types.ct_any_non_empty_slot) THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_open_slot;
            o_processing_occupied_slots := FALSE;
            o_message := 'Partial pallet.  Directing pallets to open non-deep'
                         || ' slots.';

         ELSIF (io_what_slots_to_check =
                               pl_rcv_open_po_types.ct_open_slot) THEN
            o_exhausted_options_bln := TRUE;
         ELSE
            --
            -- io_what_slots_to_check has an unhandled value.
            --
            RAISE e_unhandled_what_loc;
         END IF;
      ELSIF (i_r_item_info.partial_nondeepslot_search = '4') THEN
         --***************************************************
         -- Search option 4
         --***************************************************
         IF (io_what_slots_to_check IS NULL) THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_open_slot;
            o_processing_occupied_slots := FALSE;
            o_message := 'Partial pallet.  Directing pallets to open non-deep'
                         || ' slots.';
         ELSIF (io_what_slots_to_check = pl_rcv_open_po_types.ct_open_slot) THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_same_item_slot;
            o_processing_occupied_slots := TRUE;
            o_message := 'Partial pallet.  Directing pallets to non-deep slots'
                         || ' with the same item.';
         ELSIF (io_what_slots_to_check = pl_rcv_open_po_types.ct_same_item_slot)
                                                                          THEN
            io_what_slots_to_check := pl_rcv_open_po_types.ct_any_non_empty_slot;
            o_processing_occupied_slots := TRUE;
            o_message := 'Partial pallet.  Directing pallets to any available'
                         || ' occupied non-deep slots.';
         ELSE
            --
            -- io_what_slots_to_check has an unhandled value.
            --
            RAISE e_unhandled_what_loc;
         END IF;
      ELSE
         --
         -- i_r_syspars.non_deep_partial_slot_search has an unhandled value.
         --
         RAISE e_unhandled_slot_search;

      END IF;
   ELSE
      --
      -- The flag is set for the pallet to direct the pallet only to
      -- open slots.
      --
      io_what_slots_to_check := pl_rcv_open_po_types.ct_open_slot;
      o_processing_occupied_slots := FALSE;
      o_message := 'Partial pallet.  Directing pallets to open non-deep'
                         || ' slots.';
   END IF;  -- end IF (i_r_pallet.direct_only_to_open_slot_bln = FALSE)

   l_message :=
         'Ending function  Item[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_r_item_info.partial_nondeepslot_search['
         || i_r_item_info.partial_nondeepslot_search || ']'
         || '  io_what_slots_to_check[' || io_what_slots_to_check || ']'
         || '  o_exhausted_options_bln[' ||
                 pl_common.f_boolean_text(o_exhausted_options_bln) || ']';
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN e_unhandled_slot_search THEN
      l_message :=
         'Item[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_r_item_info.partial_nondeepslot_search['
         || i_r_item_info.partial_nondeepslot_search || ']'
         || '  io_what_slots_to_check[' || io_what_slots_to_check || ']'
         || '  i_r_item_info.partial_nondeepslot_search'
         || ' has an unhandled value.  This stop processing.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                              l_object_name || ': ' || SQLERRM);

   WHEN e_unhandled_what_loc THEN
      l_message :=
         'Item[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_r_item_info.partial_nondeeplslot_search['
         || i_r_item_info.partial_nondeepslot_search || ']'
         || '  io_what_slots_to_check[' || io_what_slots_to_check || ']'
         || '  io_what_slots_to_check has an unhandled value.'
         || '  This stop processing.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                              l_object_name || ': ' || SQLERRM);

   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_item_info,i_r_pallet,io_what_slots_to_check,'
         || 'o_processing_occupied_slots,o_message)'
         || '  Item[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || i_r_pallet.erm_id || ']'
         || '  i_r_item_info.partial_nondeepslot_search['
         || i_r_item_info.partial_nondeepslot_search || ']'
         || '  io_what_slots_to_check[' || io_what_slots_to_check || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END set_nondeep_partial_slotsearch;


---------------------------------------------------------------------------
-- Procedure:
--    validate_set_sn_data_capture
--
-- Description:
--    This procedure validates/sets the data capture values for a SN.
--
--    Expiration Date Validation:
--       If the expiration date is more than 10 years in the future or <= the
--       current date or is null then the sysdate will be used as the
--       value in the tables and putawaylst.exp_date_trk will be set to
--       'Y' to force data collection.
--
--    Catch Weight Processing:
--       If the item is catch weight tracked and the catch weight is <= 0
--       or is null then the putawaylst.catch_wt is set to 'Y' to force
--       data collection.
--
-- Parameters:
--    i_r_item_info       - Item information record.
--    io_r_pallet         - Pallet record to process.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called By:
--    - insert_records
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
--    10/18/05 prpbcb   Changed procedure to force data collection of the
--                      lot id if processing a SN, the item is lot tracked
--                      on SWMS, and the lot id that was in ERD_LPN starts
--                      with a P (upper or lower).  WMS is putting the PO
--                      number in the lot id field on the SN with the value
--                      starting with a P.  If the WMS puts in a lot id that
--                      does not start with a P and the item is lot tracked
--                      on SWMS then this will be considered a valid lot id
--                      on SWMS.
---------------------------------------------------------------------------
PROCEDURE validate_set_sn_data_capture
           (i_r_item_info  IN            pl_rcv_open_po_types.t_r_item_info,
            io_r_pallet    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'validate_set_sn_data_capture';
BEGIN
   --
   -- Validate the exp date.
   --
   IF (i_r_item_info.exp_date_trk = 'N') THEN
      --
      -- Item not exp date tracked on SWMS.
      --
      io_r_pallet.collect_exp_date := 'N';
      io_r_pallet.exp_date := TRUNC(SYSDATE);
   ELSE
      --
      -- The item is exp date tracked on SWMS.
      -- If the exp date is one of the following then force the exp date
      -- to be collected.
      --    - The exp date is more than 10 years in the future,
      --    - The exp date is less than or equal to the current date.
      --    - The exp date is null.
      --
      IF (io_r_pallet.exp_date IS NULL) THEN
         --
         -- The item is exp date tracked and the exp date on the SN is null.
         -- Force data collection.
         --
         io_r_pallet.collect_exp_date := 'Y';
         io_r_pallet.exp_date := TRUNC(SYSDATE);

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              io_r_pallet,
              'This item is expiration date tracked.  The expiration date'
              || ' on the SN is null so forcing the expiration date'
              || ' to be collected.');
      ELSIF (io_r_pallet.exp_date > (SYSDATE + 3650)) THEN
         --
         -- The item is exp date tracked and the exp date on the SN is more
         -- than 10 years in the future.  Force data collection.
         --
         io_r_pallet.collect_exp_date := 'Y';
         io_r_pallet.exp_date := TRUNC(SYSDATE);

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              io_r_pallet,
              'This item is expiration date tracked.  The expiration date ['
              || TO_CHAR(io_r_pallet.exp_date, 'MM-DD-YYYY') || ']'
              || ' on the SN is more than 10 years in the future so forcing'
              || ' the expiration date to be collected.');
      ELSIF (io_r_pallet.exp_date <= TRUNC(SYSDATE)) THEN
         --
         -- The item is exp date tracked and the exp date on the SN is less
         -- than or equal to the current date.  Force data collection.
         --
         io_r_pallet.collect_exp_date := 'Y';
         io_r_pallet.exp_date := TRUNC(SYSDATE);

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              io_r_pallet,
              'This item is expiration date tracked.  The expiration date ['
              || TO_CHAR(io_r_pallet.exp_date, 'MM-DD-YYYY') || ']'
              || ' on the SN is less than or equal to the current date'
              || ' so forcing the expiration date to be collected.');
      ELSE
         --
         -- The item is exp date tracked and the exp date on the SN is
         -- valid.  Flag the exp date as collected.
         --
         io_r_pallet.collect_exp_date := 'C';
      END IF;
   END IF;  -- end exp date tracked

   --
   -- Validate the mfg date.
   --
   IF (i_r_item_info.mfg_date_trk = 'N') THEN
      --
      -- Item not mfg date tracked on SWMS.
      --
      io_r_pallet.collect_mfg_date := 'N';
      io_r_pallet.mfg_date := NULL;
   ELSE
      --
      -- The item is mfg date tracked on SWMS.
      -- If the mfg date is null then force data collection.
      --
      IF (io_r_pallet.mfg_date IS NULL) THEN
         --
         -- The item is mfg date tracked and the mfg date on the SN is null.
         -- Force data collection.
         --
         io_r_pallet.collect_mfg_date := 'Y';
         io_r_pallet.mfg_date := NULL;

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              io_r_pallet,
              'This item is manufacturer date tracked.  The manufacturer date'
              || ' on the SN is null so forcing the manufacturer date'
              || ' to be collected.');
      ELSE
         --
         -- The item is mfg date tracked and the mfg date on the SN is
         -- valid.  Flag the mfg date as collected and set the exp date.
         --
         io_r_pallet.collect_mfg_date := 'C';
         io_r_pallet.exp_date := io_r_pallet.mfg_date +
                                           i_r_item_info.mfr_shelf_life;

      END IF;
   END IF; -- end mfg date tracked

   --
   -- Validate the lot id.
   --
   IF (i_r_item_info.lot_trk = 'N') THEN
      --
      -- Item not lot tracked on SWMS.
      --
      io_r_pallet.collect_lot_id := 'N';
      io_r_pallet.lot_id := NULL;
   ELSE
      --
      -- Item is lot tracked on SWMS.
      --
      -- If the lot id on the SN is null or starts with a P (upper or lower)
      -- then force data collection.
      --
      IF (io_r_pallet.lot_id IS NULL) THEN
         --
         -- The item is lot tracked on SWMS and the lot id on the SN
         -- is null.  Force data collection.
         --
         io_r_pallet.collect_lot_id := 'Y';

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
             io_r_pallet,
             'This item is lot tracked.  The lot id on the SN'
             || ' is null so forcing the lot id to be collected.');
      ELSIF (UPPER(io_r_pallet.lot_id) LIKE 'P%') THEN
         --
         -- The item is lot tracked on SWMS and the lot id on the SN
         -- is not a valid lot id.  Force data collection.
         --
         io_r_pallet.collect_lot_id := 'Y';

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
             io_r_pallet,
             'This item is lot tracked.  The lot id on the SN ['
             || io_r_pallet.lot_id || '] is not valid so forcing the lot id'
             || ' to be collected.');

         --
         -- Clear the lot id.
         --
         io_r_pallet.lot_id := NULL;
      ELSE
         --
         -- The item is lot tracked on SWMS and the lot id on the SN is
         -- populated.  Flag the lot id as collected.
         --
         io_r_pallet.collect_lot_id := 'C';
      END IF;
   END IF;

   --
   -- Validate the catch weight.
   --
   -- If a catch weight item and the catch weight is null or <= 0 then force
   -- the catch weight to be collected.
   --
   IF (i_r_item_info.catch_wt_trk = 'N') THEN
      --
      -- Item not catch weight tracked on SWMS.
      --
      io_r_pallet.collect_catch_wt := 'N';
      io_r_pallet.catch_weight := NULL;
   ELSE
      --
      -- Item is catch weight tracked on SWMS.
      --
      -- If the catch weight on the SN is null or <= 0 then force data
      -- collection.
      --
      IF (io_r_pallet.catch_weight IS NULL) THEN
         --
         -- The item is catch weight tracked and the catch weight on the SN
         -- is null.  Force data collection.
         --
         io_r_pallet.collect_catch_wt := 'Y';

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
             io_r_pallet,
             'This item is catch weight tracked.  The catch weight on the SN'
             || ' is null so forcing the catch weight date to be collected.');
      ELSIF (io_r_pallet.catch_weight <= 0) THEN
         --
         -- The item is catch weight tracked and the catch weight on the SN
         -- is <= 0.  Force data collection.
         --
         io_r_pallet.collect_catch_wt := 'Y';

         --
         -- Write aplog message to note this.
         --
         log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              io_r_pallet,
              'This item is catch weight tracked.  The catch weight ['
              || TO_CHAR(io_r_pallet.catch_weight) || ']'
              || ' on the SN is not valid so forcing the catch weight to be'
              || ' collected.');
      ELSE
         --
         -- The item is catch weight tracked and the catch weight on the SN is
         -- valid.  Flag the catch weight as collected.
         --
         io_r_pallet.collect_catch_wt := 'C';
      END IF;
   END IF;  -- end catch weight tracked

   --
   -- Assign tracking flags that are not designated on the SN.
   --
   io_r_pallet.collect_temp      := i_r_item_info.temp_trk;
   io_r_pallet.collect_clam_bed  := i_r_item_info.clam_bed_trk;
   io_r_pallet.collect_tti       := i_r_item_info.tti_trk;
   io_r_pallet.collect_cool      := i_r_item_info.cool_trk;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_item_info,io_r_pallet)'
         || '  Item[' || i_r_item_info.prod_id || ']'
         || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
         || '  LP[' || io_r_pallet.pallet_id || ']'
         || '  PO/SN[' || io_r_pallet.erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END validate_set_sn_data_capture;


---------------------------------------------------------------------------
-- Procedure:
--    move_partial_to_end_of_list
--
-- Description:
--    This procedure moves the partial pallet for an item to the end of
--    the list for the item.  An item is identifed by the prod_id, CPV and
--    the uom.
--
--    Before directing pallets to reserve/floating slots the partial pallet,
--    if there is one to process, is moved to the end of the pallet list for
--    the item.  Partial pallets need to be processed last for the item.
--
--    09/29/05 prpbcb Moving the partial pallet to the end is not the most
--                    efficient way to do things since the entire item
--                    record is being moved.  Another way is to have a
--                    separate array which has the order to process the
--                    pallets and to rearrange this array.  This approach
--                    would require changes to several other procedures.
--
-- Parameters:
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_rsrv_float
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE move_partial_to_end_of_list
    (io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     i_pallet_index        IN     PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'move_partial_to_end_of_list';

   l_pallets_moved_bln    BOOLEAN;  -- To flag when pallets have been moved
   l_pallet_index               PLS_INTEGER;              -- Index
   l_previous_prod_id           pm.prod_id%TYPE;          -- Previous item.
   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE; -- Previous CPV.
   l_previous_uom               erd.uom%TYPE;             -- Previous uom.
   l_prior_index                PLS_INTEGER;              -- Prior record index
   l_r_pallet                   pl_rcv_open_po_types.t_r_pallet;
BEGIN
   IF (io_r_pallet_table(i_pallet_index).partial_pallet_flag = 'Y'
       AND i_pallet_index != io_r_pallet_table.LAST) THEN
      --
      -- Move the partial pallet to the end.
      --
      -- Find the position of the last pallet.
      --
      l_previous_prod_id := io_r_pallet_table(i_pallet_index).prod_id;
      l_previous_cust_pref_vendor :=
                          io_r_pallet_table(i_pallet_index).cust_pref_vendor;
      l_previous_uom := io_r_pallet_table(i_pallet_index).uom;
      l_pallet_index := i_pallet_index;
      l_prior_index := l_pallet_index;
      l_pallets_moved_bln := FALSE;

      LOOP
         EXIT WHEN l_pallet_index = io_r_pallet_table.LAST;
         l_pallet_index := io_r_pallet_table.NEXT(l_pallet_index);
         EXIT WHEN l_previous_prod_id !=
                          io_r_pallet_table(l_pallet_index).prod_id
                   OR l_previous_cust_pref_vendor !=
                         io_r_pallet_table(l_pallet_index).cust_pref_vendor
                   OR l_previous_uom != io_r_pallet_table(l_pallet_index).uom;
         IF (l_pallets_moved_bln = FALSE) THEN
            l_r_pallet := io_r_pallet_table(l_prior_index);
         END IF;

         io_r_pallet_table(l_prior_index) := io_r_pallet_table(l_pallet_index);
         l_prior_index := l_pallet_index;
         l_pallets_moved_bln := TRUE;
      END LOOP;

      IF (l_pallets_moved_bln = TRUE) THEN
         io_r_pallet_table(l_prior_index) := l_r_pallet;
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name || '(io_r_pallet_table, i_pallet_index)'
          || ' io_r_pallet_table( ' || TO_CHAR(i_pallet_index) || ')'
          || '.pallet_id['
          || io_r_pallet_table(i_pallet_index).pallet_id || ']'
          || '  PO/SN[' || io_r_pallet_table(i_pallet_index).erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END move_partial_to_end_of_list;



---------------------------------------------------------------------------
-- Procedure:
--    direct_pallets_to_home_slot
--
-- Description:
--    This procedure assigns pallets of an item to the case home slot if
--    the rules allow it.
--
--    The rules for directing pallets to the home slot are:
--
--       If the item is an absolute FIFO item and there is qoh or qty planned
--       for any slot for the item then do not direct a pallet to the home slot.
--
--       If the item is soft FIFO and syspar PUTAWAY_TO_HOME_IF_FIFO_ALLOWS
--       is Y then a pallet can be directed to the home slot if there are no
--       pallets in reserve even if the home slot has qoh or qty planned.
--       If the syspar is N then the behavior is the same as an absolute
--       FIFO item.
--
--       If item has stackable = 0 and the home slot has qoh or qty planned
--       then do not direct a pallet to the home slot.
--       05/05/07 Brian Bent Stackability is now ignored for a home slot.
--
--       Stackability takes precedence over putaway by max qty.
--       05/05/07 Brian Bent Stackability is now ignored for a home slot.
--
--       If the item is lot tracked and the home slot has qoh or qty planned
--       then do not direct a pallet to the home slot.
--
--       If processing a full pallet and the home slot is empty and putaway
--       is by cube then direct the pallet to the home slot without checking
--       if it fits.
--
--       Partial pallets will go to the home slot before full pallets.
--       The partial pallets need to be before the full pallets in the
--       pallet list.
--
--       A full pallet will not be directed to the home slot if a partial
--       pallet was first directed to an empty home slot and the stackable
--       is 0.  Even though a partial pallet is expected to be handstacked
--       stackable 0 does not allow handstacking on top of a pallet.
--       05/05/07 Brian Bent Stackability is now ignore for a home slot.
--
--       Only the first partial pallet directed to the slot is treated as
--       a partial pallet.  A PO can have only one partial pallet per item.
--       For a SN it is possible to have multiple partial pallets for an
--       item but only the first partial pallet will be treated as a partial
--       pallet.
--
--       The skid cube of the partial pallet is not considered if the home
--       slot is empty or when a partial pallet is directed to the home slot
--       then a full pallet is directed to the home slot.  It is expected the
--       partial pallet qty will be handstacked into the home slot.
--       Note: pallet_label2.pc was ignoring the skid cube of the
--             second pallet when two full pallets were directed
--             to the home slot.  Now the skid cube is always
--             considered for full pallets.
--
--    For deep slots pallets will not be stacked.  Or put another way,
--    pallets will be directed to the home slot until the number of deep
--    positions is reached.
--
--    A pallet will '*' if processing a SN and the SN qty is > SWMS Ti Hi.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_r_item_info_table  - Table of item information records.  The pallet
--                           list (i_r_pallet_table) has a field that has the
--                           index of the item in i_r_item_info_table.
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--                           This will be incremented by the number of pallets
--                           assigned to the home slot.
--    o_status             - Status of finding slots for the item.  The value
--                           will be one of the following:
--                             - ct_same_item     - Not all the pallets for the
--                                                  item were directed to the
--                                                  current bunch of candidate
--                                                  putaway slots.
--                                                  The next step is to direct
--                                                  pallets to the next bunch
--                                                  of candidate slots.
--                             - ct_no_pallets_left - All the pallets have been
--                                                    processed.
--                             - ct_new_item        - The next pallet to process
--                                                    is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
--    09/28/05 prpbcb   Fixed bug that was checking if the number of
--                      positions in the slot was reached instead of the
--                      max qty when putaway was by max qty and it was a
--                      deep slot.  Non-deep slots were OK.
--    05/05/05 prpbcb   Modified to ignore stackability for the home slot.
--                      Did this by either commenting out the code or
--                      changing stackable = 0 to stackable < 0.
--
--                      Modified to use fields "cube_for_home_putaway" and
--                      "pallet_height_for_home_putaway" in the pallet record.
--                      These are new fields populated in
--                      pl_rcv_open_po_pallet_list.sql.
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
--                       pallet qty is <= max qty then direct the receiving
--                       pallet to the home slot.
--
--                     NOTE: FIFO rules always apply
--
--                     In some of the "IF" statements took the "OR" conditions
--                     and put in a separate "ELSIF" to allow specific log
--                     messages to be created.
---------------------------------------------------------------------------
PROCEDURE direct_pallets_to_home_slot
   (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info_table   IN     pl_rcv_open_po_types.t_r_item_info_table,
    io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
    io_pallet_index       IN OUT PLS_INTEGER,
    o_status              IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_pallets_to_home_slot';

   l_attempt_to_direct_tohome_bln BOOLEAN := TRUE;  -- Flag
   l_available_cube   pl_rcv_open_po_types.t_cube;  -- The available cube
                                 -- in the home slot.
                                 -- Used for putaway by cube.

   l_available_height   NUMBER;  -- The available height in the home slot.
                                 -- Used for putaway by inches.

   l_done_bln           BOOLEAN := FALSE;   -- Flag when done with the
                                            -- home slot.

   l_item_index         PLS_INTEGER;  -- Index of item in PL/SQL table.
   l_home_slot_qty_in_splits      PLS_INTEGER;  -- QOH + qty planned + qty on pallets
                                      -- directed to the home slot.  In splits.

   /*
   ** Items min qty and max qty.  Used if putaway to the home slot is by the min/max qty.
   */
   l_min_qty            pm.max_qty%TYPE;     -- Items min qty in cases
   l_max_qty            pm.max_qty%TYPE;     -- Items max qty in cases.

   l_num_pallets_assigned_slot PLS_INTEGER := 0;  -- Number of pallets assigned
                                                  -- to the home slot.

   l_previous_pallet_partial_bln  BOOLEAN; -- Designates if the previous pallet
                                           -- directed to the home slot was a
                                           -- partial pallet.

   l_positions_occupied PLS_INTEGER;  -- Number of positions occupied for a
                                      -- deep slot.  Only has significance when
                                      -- processing a deep slot.

   l_previous_prod_id    pm.prod_id%TYPE;  -- Initial item processed.
   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE; -- Initial CPV
                                                          -- processed.

   l_previous_uom        erd.uom%TYPE;     -- Initial uom processed.

   l_putaway_to_home_slot_method   pallet_type.putaway_use_repl_threshold%TYPE;
   l_spc                pm.spc%TYPE;   -- SPC for the item being processed.
                                       -- Used in messages.

   l_r_case_home_slot  pl_rcv_open_po_cursors.g_c_case_home_slots%ROWTYPE;
                                                       -- Home slot record.

   l_direct_pallet_to_home_bln BOOLEAN; -- Flag used in the processing

   l_work_buffer  VARCHAR2(200);  -- Area used to build log message

BEGIN
   log_pallet_message(pl_log.ct_info_msg, l_object_name,
      i_r_item_info_table(io_r_pallet_table(io_pallet_index).item_index),
      io_r_pallet_table(io_pallet_index), 'Starting procedure.');

   --
   -- If the putaway to home syspar is Y then attempt to direct pallets to
   -- the home slot.
   --
   IF (i_r_syspars.home_putaway = 'Y') THEN
      --
      -- Store some values in local variables to make things easier to read.
      --
      l_item_index := io_r_pallet_table(io_pallet_index).item_index;
      l_min_qty := i_r_item_info_table(l_item_index).min_qty;
      l_max_qty := i_r_item_info_table(l_item_index).max_qty;
      l_putaway_to_home_slot_method :=
              i_r_item_info_table(l_item_index).putaway_to_home_slot_method;
      l_spc := i_r_item_info_table(l_item_index).spc;

      --
      -- If it is a FIFO item and the item has inventory then a pallet cannot
      -- be directed to the home slot.  Check for this.
      --
      IF (f_can_item_go_to_home_slot(i_r_syspars,
                                     'FIFO',
                                     i_r_item_info_table(l_item_index),
                                     io_r_pallet_table(io_pallet_index),
                                     l_r_case_home_slot) = FALSE) THEN
         l_attempt_to_direct_tohome_bln := FALSE; -- Item cannot go to the
                                                  -- home slot.
         o_status := pl_rcv_open_po_types.ct_check_reserve;  -- The next step
                                                       -- is to check reserve.
      END IF;

      --
      -- If it is OK to attempt to direct pallets to the home slot then do so.
      --
      IF (l_attempt_to_direct_tohome_bln = TRUE) THEN
         --
         -- It is OK to attempt to direct pallets to the home slot.
         --
         -- Initialization
         --
         l_previous_prod_id := io_r_pallet_table(io_pallet_index).prod_id;
         l_previous_cust_pref_vendor :=
                           io_r_pallet_table(io_pallet_index).cust_pref_vendor;
         l_previous_uom := io_r_pallet_table(io_pallet_index).uom;
         o_status := pl_rcv_open_po_types.ct_same_item;  -- Need to initialize
                               -- o_status in case no case home slot is found.

         --
         -- Get the case home slot.
         --
         OPEN pl_rcv_open_po_cursors.g_c_case_home_slots
                                       (i_r_item_info_table(l_item_index));

         --
         -- NOTE:  07/29/05 prpbcb Cursor g_c_case_home_slots will only select
         -- the rank 1 case home slot so only one pass through the loop is
         -- made.  If in the future the cursor is changed to select all the
         -- case home slots then changes will need to be made in the loop logic.
         --

         <<case_home_loop>>
         LOOP
            FETCH pl_rcv_open_po_cursors.g_c_case_home_slots INTO
                                                      l_r_case_home_slot;
            EXIT case_home_loop WHEN
                         pl_rcv_open_po_cursors.g_c_case_home_slots%NOTFOUND;

            --
            -- Determine if a pallet can be directed to the home slot
            -- based on the home slot having qty.
            --
            IF (f_can_item_go_to_home_slot(i_r_syspars,
                                           'QTY',
                                           i_r_item_info_table(l_item_index),
                                           io_r_pallet_table(io_pallet_index),
                                           l_r_case_home_slot) = FALSE) THEN
               o_status := pl_rcv_open_po_types.ct_check_reserve; -- Next step
                                                        -- is to check reserve.
               EXIT case_home_loop;  -- Item cannot go to the home slot.
            END IF;

            --
            -- Initialization
            --
            --
            -- Determine the available cube in the home slot.  For a
            -- non-deep home the skid cube is added only once regardless
            -- of the qty in the slot.
            --
            IF (l_r_case_home_slot.deep_ind = 'N') THEN
               --
               -- Home slot is not a deep slot.
               --
               IF (l_r_case_home_slot.qty_occupied_cube = 0) THEN
                  --
                  -- Non deep home slot is empty.
                  --
                  l_available_cube := l_r_case_home_slot.cube;
               ELSE
                  --
                  -- Non deep home slot is not empty.  Add in skid cube once
                  -- as cube occupied in the home slot.
                  --
                  l_available_cube := l_r_case_home_slot.cube -
                     (l_r_case_home_slot.qty_occupied_cube +
                     (1 * i_r_item_info_table(l_item_index).pt_skid_cube));
               END IF;
            ELSE
               l_available_cube := l_r_case_home_slot.cube -
                     (l_r_case_home_slot.qty_occupied_cube +
                     (l_r_case_home_slot.skids_in_slot *
                      i_r_item_info_table(l_item_index).pt_skid_cube));
            END IF;

            l_available_height := l_r_case_home_slot.available_height;
            l_home_slot_qty_in_splits := l_r_case_home_slot.qoh +
                                         l_r_case_home_slot.qty_planned;
            l_positions_occupied := l_r_case_home_slot.positions_occupied;
            l_done_bln := FALSE;

            --
            -- Direct pallets to the home slot until full.
            --
            <<pallet_loop>>
            WHILE (NOT l_done_bln) LOOP
               l_direct_pallet_to_home_bln := FALSE;

               --
               -- If the pallet is on a SN and the pallet qty is >= Ti Hi then
               -- "*" the pallet.
               --
               IF ((io_r_pallet_table(io_pallet_index).erm_type = 'SN') AND
                   (io_r_pallet_table(io_pallet_index).qty_received >
                   i_r_item_info_table(l_item_index).full_pallet_qty_in_splits))
               THEN
                  --
                  -- The pallet is on a SN and the pallet qty is >= Ti Hi.
                  -- "*" the pallet.
                  --
                  io_r_pallet_table(io_pallet_index).dest_loc := '*';
                  insert_records(i_r_item_info_table(l_item_index),
                                 io_r_pallet_table(io_pallet_index));
               ELSE
                  --
                  -- If the home slot is empty and has nothing planned then
                  -- direct the pallet to the home slot without checking if it
                  -- fits or not.  The not checking if it fits is by design.
                  --
                  IF (l_home_slot_qty_in_splits = 0) THEN
                     -- ********************************
                     -- The home slot is empty.
                     -- ********************************
                     --
                     -- The home slot is empty and has nothing planned.
                     --
                     -- Direct the pallet to the home slot without checking if
                     -- it fits or not.  The not checking if it fits is by
                     -- design.
                     --
                     log_pallet_message_home_slot(pl_log.ct_info_msg,
                         l_object_name, i_r_item_info_table(l_item_index),
                         io_r_pallet_table(io_pallet_index),
                         l_home_slot_qty_in_splits, l_available_cube, l_available_height,
                         l_r_case_home_slot,
                           'Home slot is empty so direct pallet to home'
                           || ' slot.  Ignore if pallet fits or not.');

                     io_r_pallet_table(io_pallet_index).dest_loc :=
                                                  l_r_case_home_slot.logi_loc;
                   io_r_pallet_table(io_pallet_index).dest_loc_is_home_slot_bln
                                                       := TRUE;

                     --
                     -- Procedure insert_records inserts/updates INV
                     -- and creates the PUTAWAYLST record.
                     --
                     insert_records(i_r_item_info_table(l_item_index),
                                    io_r_pallet_table(io_pallet_index));

                     IF (io_r_pallet_table(io_pallet_index).partial_pallet_flag
                                                              = 'Y') THEN
                        l_previous_pallet_partial_bln := TRUE;
                     ELSE
                        l_previous_pallet_partial_bln := FALSE;
                     END IF;
                  ELSE
                     -- ********************************
                     -- The home slot is not empty.
                     -- ********************************
                     --
                     -- For non-deep home slots direct the pallet to the home
                     -- slot if stackable allows it and it fits.
                     --
                     -- For deep home slots direct the pallet to the home slot
                     -- if positions are available and it fits.  If putaway is
                     -- by max qty and stackable is 0 then a pallet will not
                     -- be directed to the slot is there are no open positions.
                     -- Stackability takes precedence over max qty.
                     -- For deep home slots pallets will not be stacked.
                     --
                     -- 05/05/07
                     -- READ THIS ABOUT STACKABILITY CHANGES
                     -- Brian Bent Stackability is now ignored for a
                     -- home slot.  Changed = 0 to < 0 to ignore it.
                     -- 11/29/2012
                     -- Brian Bent Removed the code looking at stackability.
                     --
                     IF (l_r_case_home_slot.deep_ind = 'Y' AND
                            l_positions_occupied >=
                                      l_r_case_home_slot.deep_positions AND
                            l_putaway_to_home_slot_method = 'N')
                     THEN
                        --
                        -- Deep home slot, not empty, no positions are open
                        -- and putaway is not by min/max qty
                        --
                        --  A pallet cannot be directed to the home slot.
                        --
                        log_pallet_message_home_slot(pl_log.ct_info_msg,
                           l_object_name, i_r_item_info_table(l_item_index),
                           io_r_pallet_table(io_pallet_index), l_home_slot_qty_in_splits,
                           l_available_cube, l_available_height,
                           l_r_case_home_slot,
                           'No positions available in the deep home slot.'
                            || '  The pallet will not be directed to the home slot.');

                        l_done_bln := TRUE;
                        -- Next step is to check reserve slots.
                        o_status := pl_rcv_open_po_types.ct_check_reserve;
                     ELSE
                        --
                        -- The home slot is not empty.
                        -- Direct the pallet to the home slot if it fits.
                        -- This depends on the min/max qty if the pallet type is
                        -- designated to use min/max qty or will be by cube or
                        -- inches.
                        --
                        -- If putaway by min/max qty then direct the pallet
                        -- to the home slot if the requirements are meet.
                        --
-- xxxxxxxxxxx
                        IF   (l_putaway_to_home_slot_method = 'Y') THEN
                           --
                           -- Putaway is by min/max qty.
                           -- Direct the pallet to the home slot if the home
                           -- slot qty is <= min qty
                           -- or if the qty on the
                           -- pallet + qty in the home slot is <= max qty.
                           --
                           --
                           -- Build common part of the message used in some
                           -- of the aplog messages.
                           --
                           l_work_buffer :=
                                 'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
                                    || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
                                    || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
                                    || '  FIFO track[' || i_r_item_info_table(l_item_index).fifo_trk || ']'
                                    || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

                           pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 l_work_buffer
                                    || '  Putaway is by min/max qty.'
                                    || '  Direct the pallet to the home slot if the home'
                                    || ' slot qty is <= min qty or if the qty on the'
                                    || ' pallet + qty in the home slot is <= max qty.'
                                    || '  Following FIFO rules.',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                           IF ((l_home_slot_qty_in_splits / l_spc) <= l_min_qty)
                           THEN
                              --
                              -- The home slot qty is <= min qty therefore 
                              -- direct the pallet to the home slot.
                              --
                              pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 l_work_buffer
                                    || '  Putaway is by min/max qty and the home slot qty of '
                                    || TO_CHAR(TRUNC(l_home_slot_qty_in_splits / l_spc))
                                    || ' case(s) and '
                                    || TO_CHAR(MOD(l_home_slot_qty_in_splits, l_spc))
                                    || ' split(s) is less than or equal to the items min qty of '
                                    || TO_CHAR(l_min_qty) || '.  Direct the pallet to the home slot',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                              l_direct_pallet_to_home_bln := TRUE;
                           ELSIF ( ((l_home_slot_qty_in_splits / l_spc) + (io_r_pallet_table(io_pallet_index).qty_received / l_spc)) <= l_max_qty)
                           THEN
                              --
                              -- The qty on the pallet + home slot qty is
                              -- <= max qty therefore direct the pallet
                              -- to the home slot.
                              --
                              pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 l_work_buffer
                                    || '  Putaway is by min/max qty and the qty on the pallet of '
                                    || TO_CHAR(TRUNC(io_r_pallet_table(io_pallet_index).qty_received / l_spc))
                                    || ' case(s) and '
                                    || TO_CHAR(MOD(io_r_pallet_table(io_pallet_index).qty_received, l_spc))
                                    || ' split(s) plus the qty in the home slot of '
                                    || TO_CHAR(TRUNC(l_home_slot_qty_in_splits / l_spc))
                                    || ' case(s) and '
                                    || TO_CHAR(MOD(l_home_slot_qty_in_splits, l_spc))
                                    || ' split(s) is less than or equal to the items max qty of '
                                    || TO_CHAR(l_max_qty) || '.  Direct the pallet to the home slot',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                              l_direct_pallet_to_home_bln := TRUE;
                           ELSE
                              pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 l_work_buffer
                                    || '  Putaway is by min/max qty and the qty on the pallet of '
                                    || TO_CHAR(TRUNC(io_r_pallet_table(io_pallet_index).qty_received / l_spc))
                                    || ' case(s) and '
                                    || TO_CHAR(MOD(io_r_pallet_table(io_pallet_index).qty_received, l_spc))
                                    || ' split(s) and the qty in the home slot of '
                                    || TO_CHAR(TRUNC(l_home_slot_qty_in_splits / l_spc))
                                    || ' case(s) and '
                                    || TO_CHAR(MOD(l_home_slot_qty_in_splits, l_spc))
                                    || ' split(s) and the items min qty of ' || TO_CHAR(l_min_qty)
                                    || ' and the max qty of ' ||  TO_CHAR(l_max_qty)
                                    ||  ' do not allow the pallet to be directed to the home slot',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
                              l_direct_pallet_to_home_bln := FALSE;
                           END IF;
                        --
                        --
                        -- Check if pallet fits if putaway by cube. 
                        --
                        ELSIF (i_r_syspars.putaway_dimension = 'C') THEN
                           IF (l_available_cube >=
                                   io_r_pallet_table(io_pallet_index).cube_for_home_putaway)
                           THEN
                              pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 'Putaway is by cube and the pallet will fit in the home slot.  Direct the pallet to the home slot',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                              l_direct_pallet_to_home_bln := TRUE;
                           ELSE
                              pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 'Putaway is by cube and the pallet will NOT fit in the home slot.  Do not direct the pallet to the home slot',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                              l_direct_pallet_to_home_bln := FALSE;
                           END IF;
                        --
                        --
                        -- Check if pallet fits if putaway by inches. 
                        --
                        ELSIF (i_r_syspars.putaway_dimension = 'I') THEN
                           IF (l_available_height >=
                                 io_r_pallet_table(io_pallet_index).pallet_height_for_home_putaway
                              AND l_r_case_home_slot.slot_height >=
                                    io_r_pallet_table(io_pallet_index).pallet_height_for_home_putaway)
                           THEN
                              pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 'Putaway is by inches and the pallet will fit in the home slot.  Direct the pallet to the home slot',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                              l_direct_pallet_to_home_bln := TRUE;
                           ELSE
                              pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
                                 'Putaway is by inches and the pallet will NOT fit in the home slot.  Do not direct the pallet to the home slot',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                              l_direct_pallet_to_home_bln := FALSE;
                           END IF;
                        ELSE
                            --
                            -- If this point reached then we have an unhandled condition.
                            -- Write a log message.  Do no stop processing.
                            -- Do not direct the pallet to the home slot.
                            --
                            pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name, 
                                 'Unhandled value',
                                 NULL, NULL, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                            l_direct_pallet_to_home_bln := FALSE;
                        END IF;


                        IF (l_direct_pallet_to_home_bln = TRUE) THEN
                           --
                           -- The pallet will fit in the home slot.
                           --
                           log_pallet_message_home_slot(pl_log.ct_info_msg,
                              l_object_name, i_r_item_info_table(l_item_index),
                              io_r_pallet_table(io_pallet_index),
                              l_home_slot_qty_in_splits, l_available_cube,
                              l_available_height, l_r_case_home_slot,
                              'The pallet will fit in the home slot.'
                              || '  Send the pallet to the home slot.');

                           io_r_pallet_table(io_pallet_index).dest_loc :=
                                               l_r_case_home_slot.logi_loc;
                  io_r_pallet_table(io_pallet_index).dest_loc_is_home_slot_bln
                                                            := TRUE;
                           insert_records(i_r_item_info_table(l_item_index),
                                          io_r_pallet_table(io_pallet_index));

                           --
                           -- Only the first partial pallet directed to the
                           -- slot is treated as a partial pallet.  A PO will
                           -- only have one partial pallet per item.  For a SN
                           -- it is possible to have multiple partial pallets
                           -- for an item???
                           --
                           IF (io_r_pallet_table(io_pallet_index).partial_pallet_flag
                                                              = 'Y'
                               AND l_num_pallets_assigned_slot = 0) THEN
                              l_previous_pallet_partial_bln := TRUE;
                           ELSE
                              l_previous_pallet_partial_bln := FALSE;
                           END IF;
                        ELSE
                           --
                           -- The pallet will not fit in the home slot.
                           --
                           log_pallet_message_home_slot(pl_log.ct_info_msg,
                              l_object_name, i_r_item_info_table(l_item_index),
                              io_r_pallet_table(io_pallet_index),
                              l_home_slot_qty_in_splits, l_available_cube,
                              l_available_height, l_r_case_home_slot,
                              'The pallet will not fit in the home slot.');

                           l_done_bln := TRUE;
                           o_status := pl_rcv_open_po_types.ct_check_reserve;

                        END IF;  -- end if pallet will fit

                     END IF;  -- end if stackable = 0
                  END IF;   -- end if l_home_slot_qty_in_splits = 0
               END IF;   -- end if SN and SN qty > Ti Hi

               IF (l_done_bln = FALSE) THEN
                  --
                  -- See if the last pallet was processed.
                  --
                  IF (io_pallet_index = io_r_pallet_table.LAST) THEN
                     l_done_bln := TRUE;
                     o_status := pl_rcv_open_po_types.ct_no_pallets_left;
                  ELSE
                     --
                     -- Update the running totals if the pallet was directed
                     -- to a location.
                     -- (09/20/05 prpbcb  Updates unnecessarily when the
                     -- next pallet is for a different item)
                     --
                     IF (io_r_pallet_table(io_pallet_index).dest_loc != '*')
                     THEN
                        l_num_pallets_assigned_slot :=
                                        l_num_pallets_assigned_slot + 1;
                        l_available_cube := l_available_cube -
                      io_r_pallet_table(io_pallet_index).cube_for_home_putaway;
                        l_available_height := l_available_height -
            io_r_pallet_table(io_pallet_index).pallet_height_for_home_putaway;
                        l_home_slot_qty_in_splits := l_home_slot_qty_in_splits +
                                        io_r_pallet_table(io_pallet_index).qty_received;
                        l_positions_occupied := l_positions_occupied + 1;
                     END IF;

                     --
                     -- Get the next pallet
                     --
                     io_pallet_index := io_r_pallet_table.NEXT(io_pallet_index);

                     --
                     -- If the next pallet to process is for a different item
                     -- or uom then the processing is done for the current
                     -- item/uom.  A change in the uom even if it is the same
                     -- item requires different processing.
                     --
                     IF (   l_previous_prod_id !=
                                  io_r_pallet_table(io_pallet_index).prod_id
                         OR l_previous_cust_pref_vendor !=
                            io_r_pallet_table(io_pallet_index).cust_pref_vendor
                         OR l_previous_uom !=
                                  io_r_pallet_table(io_pallet_index).uom) THEN
                        l_done_bln := TRUE;
                        o_status := pl_rcv_open_po_types.ct_new_item;
                     END IF;
                  END IF;
               END IF;

            END LOOP pallet_loop;  -- end LP loop

         END LOOP case_home_loop;

         CLOSE pl_rcv_open_po_cursors.g_c_case_home_slots;

      END IF;
   ELSE
      --
      -- Home putaway syspar is N so no pallets will be directed to the
      -- home slot.  Write an aplog message noting this.
      --
      o_status := pl_rcv_open_po_types.ct_check_reserve;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
         || '  Syspar "Home Putaway" is N so no pallets will'
         || ' be directed to the home slot.',
         NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   END IF;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
      'Leaving procedure.'
      || '  io_pallet_index[' || TO_CHAR(io_pallet_index) || ']'
      || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
      || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
      || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
      || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
      || '  Number of pallets assigned to the home slot['
      || TO_CHAR(l_num_pallets_assigned_slot) || ']'
      || '  o_status[' || TO_CHAR(o_status) || ']',
      NULL, NULL,
      pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      -- Cursor cleanup.
      IF (pl_rcv_open_po_cursors.g_c_case_home_slots%ISOPEN) THEN
         CLOSE pl_rcv_open_po_cursors.g_c_case_home_slots;
      END IF;

      l_message := l_object_name
         || '(i_r_syspars,i_r_item_info_table,io_r_pallet_table'
         || ',io_pallet_index,o_status)'
         || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_pallets_to_home_slot;


---------------------------------------------------------------------------
-- Procedure:
--    direct_pallets_to_split_home
--
-- Description:
--    This procedure directs pallets to the rank 1 split home.  This occurs
--    when receiving splits for an item with a home slot and the item is
--    not an aging item.
--
--    The rule is when receivng splits for an item with a home slot the splits
--    will always be directed to the rank 1 split home regardless of FIFO,
--    if they fit, etc. except if it is an aging item.
--
--    Not all the parameters may be used.  This procedure was patterned after
--    procedure direct_pallets_to_home_slot().
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_r_item_info_table  - Table of item information records.  The pallet
--                           list (i_r_pallet_table) has a field that has the
--                           index of the item in i_r_item_info_table.
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--                           This will be incremented by the number of pallets
--                           assigned to the home slot.
--    o_status             - Status of finding slots for the item.  The value
--                           will be one of the following:
--                             - ct_same_item   - Will happen when no split
--                                                home slot was found for the
--                                                item.
--                             - ct_no_pallets_left - All the pallets have been
--                                                    processed.
--                             - ct_new_item    - The next pallet to process
--                                                is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_pallets_to_split_home
   (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
    i_r_item_info_table   IN     pl_rcv_open_po_types.t_r_item_info_table,
    io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
    io_pallet_index       IN OUT PLS_INTEGER,
    o_status              IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_pallets_to_split_home';

   l_done_bln           BOOLEAN := FALSE;   -- Flag when done with the
                                            -- home slot.

   l_item_index         PLS_INTEGER;  -- Index of item in PL/SQL table.
   l_num_pallets_assigned_slot PLS_INTEGER;  -- Number of pallets assigned
                                             -- to the split home slot.

   l_previous_prod_id    pm.prod_id%TYPE;  -- Initial item processed.
   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE; -- Initial
                                                          -- CPV processed.

   l_previous_uom        erd.uom%TYPE;     -- Initial uom processed.

   l_spc                pm.spc%TYPE;   -- SPC for the item being processed.
                                       -- Used in messages.


   --
   -- This cursor selects the rank 1 split home slot for an item.
   --
   CURSOR c_split_home_slot(cp_prod_id           inv.prod_id%TYPE,
                            cp_cust_pref_vendor  inv.cust_pref_vendor%TYPE) IS
      SELECT l.logi_loc
        FROM loc l
       WHERE l.prod_id          = cp_prod_id
         AND l.cust_pref_vendor = cp_cust_pref_vendor
         AND l.perm             = 'Y'
         AND l.uom              IN (0, 1)
       ORDER BY l.rank;

   r_split_home_slot  c_split_home_slot%ROWTYPE; -- Split home slot record.

BEGIN
   log_pallet_message(pl_log.ct_info_msg, l_object_name,
      i_r_item_info_table(io_r_pallet_table(io_pallet_index).item_index),
      io_r_pallet_table(io_pallet_index), 'Starting procedure.');

   -- Store some values in local variables to make things easier to read.
   l_item_index := io_r_pallet_table(io_pallet_index).item_index;
   l_spc := i_r_item_info_table(l_item_index).spc;

   --
   -- Initialization
   --
   l_previous_prod_id := io_r_pallet_table(io_pallet_index).prod_id;
   l_previous_cust_pref_vendor :=
                        io_r_pallet_table(io_pallet_index).cust_pref_vendor;
   l_previous_uom := io_r_pallet_table(io_pallet_index).uom;
   l_num_pallets_assigned_slot := 0;
   l_done_bln := FALSE;
   o_status := pl_rcv_open_po_types.ct_same_item;  -- Need to initialize
                               -- o_status in case no split home slot is found.

   --
   -- Get the rank 1 split home slot for the item.
   --
   OPEN c_split_home_slot
              (io_r_pallet_table(io_pallet_index).prod_id,
               io_r_pallet_table(io_pallet_index).cust_pref_vendor);
   FETCH c_split_home_slot INTO r_split_home_slot;
   --
   -- If no split home was found then processing is done.  What will
   -- happen is the pallet will '*' out.
   --
   IF (c_split_home_slot%NOTFOUND) THEN
      l_done_bln := TRUE;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
         || '  Destination loc[' || io_r_pallet_table(io_pallet_index).dest_loc
         || ']  Receiving splits.  This item has a case home slot but no'
         || ' split home slot was found.  The pallet will "*".',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      --
      -- 01/05/1016  Brian Bent
      -- Fix bug.  Added call to "no_slot_found".  The program got into an
      -- infinite loop creating thousands of log messages when the item did
      -- not have a split home slot.  Ideally the item should have a split home
      -- but if not then we "*" the pallets.
      -- The infinite loop was between "direct_pallets_to_slots" and
      -- "direct_pallets_to_split_home".
      --
      no_slot_found(i_r_syspars,
                    i_r_item_info_table(l_item_index),
                    io_r_pallet_table,
                    io_pallet_index,
                    o_status);
   END IF;

   CLOSE c_split_home_slot;

   --
   -- Direct pallets to the split home slot.
   --
   WHILE (NOT l_done_bln) LOOP

      io_r_pallet_table(io_pallet_index).dest_loc := r_split_home_slot.logi_loc;
      io_r_pallet_table(io_pallet_index).dest_loc_is_home_slot_bln := TRUE;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
         || '  Destination loc[' || io_r_pallet_table(io_pallet_index).dest_loc
         || ']  Receiving splits.  Always direct the pallet to the rank'
         || ' 1 split home slot.',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      --
      -- Procedure insert_records inserts/updates INV
      -- and creates the PUTAWAYLST record.
      --
      insert_records(i_r_item_info_table(l_item_index),
                                 io_r_pallet_table(io_pallet_index));


      --
      -- Update the running totals.
      --
      l_num_pallets_assigned_slot := l_num_pallets_assigned_slot + 1;

      --
      -- See if the last pallet was processed.
      --
      IF (io_pallet_index = io_r_pallet_table.LAST) THEN
         l_done_bln := TRUE;
         o_status := pl_rcv_open_po_types.ct_no_pallets_left;
      ELSE
         --
         -- Get the next pallet
         --
         io_pallet_index := io_r_pallet_table.NEXT(io_pallet_index);

         --
         -- If the next pallet to process is for a different item
         -- or uom then the processing is done for the current
         -- item/uom.  A change in the uom even if it is the same
         -- item requires different processing.
         --
         IF (   l_previous_prod_id !=
                            io_r_pallet_table(io_pallet_index).prod_id
             OR l_previous_cust_pref_vendor !=
                            io_r_pallet_table(io_pallet_index).cust_pref_vendor
             OR l_previous_uom !=
                            io_r_pallet_table(io_pallet_index).uom) THEN
            l_done_bln := TRUE;
            o_status := pl_rcv_open_po_types.ct_new_item;
         END IF;
      END IF;
   END LOOP;  -- end LP loop

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
      'Leaving procedure.'
      || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
      || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
      || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
      || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
      || '  io_pallet_index[' || TO_CHAR(io_pallet_index) || ']'
      || '  o_status[' || TO_CHAR(o_status) || ']'
      || '  Number of pallets assigned a slot['
      || TO_CHAR(l_num_pallets_assigned_slot) || ']',
      NULL, NULL,
      pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      -- Cursor cleanup.
      IF (c_split_home_slot%ISOPEN) THEN
         CLOSE c_split_home_slot;
      END IF;

      l_message := l_object_name || '(i_r_syspars,i_r_item_info_table,'
         || 'io_r_pallet_table, io_pallet_index, o_status)'
         || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_pallets_to_split_home;


---------------------------------------------------------------------------
-- Procedure:
--    direct_pallets_to_slots_inzone
--
-- Description:
--    This procedure directs pallets for a specified item to slots in a
--    specified zone.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_r_item_info        - Current item.
--    i_r_zone             - Zone to direct pallets to.
--    i_curvar_locations   - Cursor variable pointing to cursor of the
--                           candidate locations in the zone.
--    i_occupied_slots_bln - Designates if the candidate slots have current
--                           inventory.  If this is TRUE and putaway is by
--                           cube then the occupied cube is needed and will
--                           be calculated.
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--                           This will be incremented by the number of pallets
--                           assigned to the slots.
--    io_num_slots_with_item_in_zone - The number of slots in the zone that
--                                      have a pallet of the item.
--    o_status             - Status of finding slots for the item.  The value
--                           will be one of the following:
--                             - ct_same_item       - There are still pallets
--                                                    of the item to find
--                                                    slots for.
--                             - ct_new_item        - The next pallet to process
--                                                    is for a different item.
--                             - ct_no_pallets_left - All the pallets have been
--                                                    processed.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_to_non_deep_slots
--    - direct_to_deep_slots
--    - direct_to_floating_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/05 prpbcb   Created
--    10/11/05 prpbcb   Modified how non-empty deep slots are handled.
--                      See the modification history for the file dated
--                      10/11/05 for additional information.
--    03/16/06 prpbcb   When putaway is by inches and processing occupied
--                      deep slots pallets are being directed to slots have
--                      no positions available.  Resolved this by calling
--                      procedure get_slot_info() for putaway
--                      by inches in addition to putaway by cube.  Before it
--                      was called only for putaway by cube.  This procedure
--                      will determine the positions used in the slot which
--                      is the key information needed.  It calculates the
--                      occupied cube too and while this is not needed for
--                      putaway by inches it is not a bad idea to have the
--                      occupied cube since the log messages show the cube.
--    05/14/07 prpbcb   Modified to handle directing floating items to
--                      slots using the max qty.  This is new functionality
--                      that allows the user to putaway floating items
--                      using the item's max qty.  It is set at the pallet
--                      type level. 
--
--                      Added variables:
--                         l_qty_in_slot PLS_INTEGER;
--                         l_pallet_will_fit_in_slot_bln  BOOLEAN
--
--                      Changed name from direct_pallets_to_zone to
--                      direct_pallets_to_slots_inzone
--
--    07/10/18 mpha8134 Add a call to insert_records_multi_lp_parent if the PO
--                      is an internal PO.
--                      
--                      Slight change in logic for the non_fifo_combine_plts_in_float
--                      syspar. Multiple pallets can go to a floating loc if the zone is the 
--                      item's primary PUT zone, and if the slot's cube is 999 exactly (magic number!)
--                      regardless of if the syspar is turned on/off.
--                          
---------------------------------------------------------------------------
PROCEDURE direct_pallets_to_slots_inzone
 (i_r_syspars               IN     pl_rcv_open_po_types.t_r_putaway_syspars,
  i_r_item_info             IN     pl_rcv_open_po_types.t_r_item_info,
  i_r_zone                  IN     gl_c_zones%ROWTYPE,
  i_curvar_locations        IN     pl_rcv_open_po_types.t_refcur_location,
  i_occupied_slots_bln      IN     BOOLEAN,
  io_r_pallet_table         IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
  io_pallet_index           IN OUT PLS_INTEGER,
  io_num_slots_with_item_in_zone IN OUT PLS_INTEGER,
  o_status                  IN OUT PLS_INTEGER)
IS
    l_message       VARCHAR2(512);    -- Message buffer
    l_object_name   VARCHAR2(30) := 'direct_pallets_to_slots_inzone';

    l_available_cube      pl_rcv_open_po_types.t_cube;  -- The available cube
                                    -- in the home slot.
                                    -- Used for putaway by cube.

    l_available_height    NUMBER;   -- The available height in the home slot.
                                    -- Used for putaway by inches.

    l_done_with_slot_bln  BOOLEAN := FALSE; -- Work area
    l_occupied_cube        pl_rcv_open_po_types.t_cube;     -- Cube occupied in
                                                            -- slot.
    l_previous_prod_id   pm.prod_id%TYPE;   -- The first item processed.  Used
                                            -- to check when the next pallet is
                                            -- for a different item or uom.

    l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE;  -- The first CPV
                                            -- processed.  Used to check when
                                            -- the next pallet is for a
                                            -- different item or uom.
    
    l_previous_order_id erd.order_id%TYPE;  -- The first order_id processed. Used
                                            -- To check when next pallet has a 
                                            -- different order_id (Added for meat
                                            -- company changes)

    l_previous_partial_pallet_flag  VARCHAR2(1); -- The first value.  Used to
                                                -- check when the next pallet
                                                -- is for a different item or
                                                -- uom or partial pallet.

    l_previous_uom  erd.uom%TYPE;   -- The first uom processed.  Used to check
                                    -- when the next pallet is for a different
                                    -- item or uom.

    l_num_slots_processed PLS_INTEGER;  -- Number of slots processed before
                                        -- running of of slots to check,
                                        -- new item occurred or ran out
                                        -- of pallets.

    l_num_pallets_assigned_slot PLS_INTEGER;-- Number of pallets assigned
                                            -- to a slot.

    l_num_positions_used PLS_INTEGER;       -- Number of positions used in the
                                            -- slot.  Used only when processing
                                            -- deep slots.

    l_pallet_directed_to_slot_bln  BOOLEAN; -- Indicates if a pallet was
                                            -- directed to the slot being
                                            -- processed.

    l_pallet_will_fit_in_slot_bln  BOOLEAN; -- Flag to indicate if the
                                            -- pallet will fit in the slot.

    l_qty_in_slot PLS_INTEGER;              -- QOH + qty planned (in splits)
                                            -- for a slot.
                                            -- Used when putaway floating item
                                            -- by max qty is Y.  It will be
                                            -- incremented by the qty on the
                                            -- pallet when a pallet is directed
                                            -- to the slot.

    r_slot    pl_rcv_open_po_types.t_r_location; -- Reserve/floating slot record.

BEGIN
    log_pallet_message(pl_log.ct_info_msg, l_object_name,
            i_r_item_info, io_r_pallet_table(io_pallet_index),
            'Processing pallet.  Zone[' || i_r_zone.zone_id || ']');

    --
    -- Initialization
    --
    l_previous_prod_id := io_r_pallet_table(io_pallet_index).prod_id;
    l_previous_cust_pref_vendor :=
                           io_r_pallet_table(io_pallet_index).cust_pref_vendor;
    l_previous_uom := io_r_pallet_table(io_pallet_index).uom;
    l_previous_partial_pallet_flag :=
                        io_r_pallet_table(io_pallet_index).partial_pallet_flag;
    l_previous_order_id := io_r_pallet_table(io_pallet_index).order_id;
    l_num_slots_processed := 0;
    l_num_pallets_assigned_slot := 0;
    o_status := pl_rcv_open_po_types.ct_same_item;

    --
    -- Count the number of slots in the zone that have a pallet of the
    -- item but only if the count is 0.  This procedure can be called multiple
    -- times for a zone for the same item with different locations to check.
    -- A running count of the slots in the zone that have a pallet(s)
    -- of the item is kept and checked against the maximum number of slots
    -- that item can have in the zone as designated by pm.max_slot and
    -- pm.max_slot_per.  Once the maximum is reached for a zone then the
    -- next zone is processed
    -- prpbcb 08/15/05  Only max slot per zone is implemented.
    --                  Max slots per aisle is ignored for now.
    --
    IF (io_num_slots_with_item_in_zone = 0) THEN
      SELECT COUNT(DISTINCT i.plogi_loc)
        INTO io_num_slots_with_item_in_zone
        FROM lzone lz, inv i
       WHERE lz.zone_id = i_r_zone.zone_id
         AND lz.logi_loc = i.plogi_loc
         AND i.prod_id = io_r_pallet_table(io_pallet_index).prod_id
         AND i.cust_pref_vendor =
                        io_r_pallet_table(io_pallet_index).cust_pref_vendor;
    END IF;

    --
    -- Loop through the candidate locations in the zone assigning pallet(s) to
    -- the location.
    --
    <<candidate_slot_loop>>
    LOOP
        --
        -- Exit loop when the maximum number of slots in the zone that can
        -- have a pallet of the item is reached or there are no pallets left
        -- or it is a new item.
        --
        IF (io_num_slots_with_item_in_zone >= i_r_item_info.max_slot AND
            i_r_item_info.max_slot_per = 'Z')
        THEN
            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                'Item[' || i_r_item_info.prod_id || ']'
                || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
                || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
                || '  Put zone[' || i_r_zone.zone_id || ']'
                || '  Number of slots that have a pallet of the item['
                || TO_CHAR(io_num_slots_with_item_in_zone) || ']'
                || '  Max slots per zone[' || TO_CHAR(i_r_item_info.max_slot) || ']'
                || '  Reached the maximum number of slots per zone for the item.'
                || '  No more pallets will be directed to this zone for this item.',
                NULL, NULL,
                pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            EXIT candidate_slot_loop;
        END IF;

        EXIT candidate_slot_loop WHEN o_status IN
                                   (pl_rcv_open_po_types.ct_no_pallets_left,
                                    pl_rcv_open_po_types.ct_new_item);

        FETCH i_curvar_locations INTO r_slot;

        EXIT candidate_slot_loop WHEN i_curvar_locations%NOTFOUND;

        l_num_slots_processed := l_num_slots_processed + 1;

        pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Processing slot[' || r_slot.logi_loc || ']'
            || '  Slot type[' || r_slot.slot_type || ']'
            || '  Pallet type[' || r_slot.pallet_type || ']'
            || '  Put zone[' || r_slot.put_zone_id || ']'
            || '  Location cube[' || TO_CHAR(r_slot.cube) || ']'
            || '  Slot height[' || TO_CHAR(r_slot.slot_height) || ']'
            || '  Occupied height[' || TO_CHAR(r_slot.occupied_height) || ']'
            || '  Available height[' || TO_CHAR(r_slot.available_height) || ']'
            || '  Deep slot[' || r_slot.deep_ind || ']'
            || '  Deep positions[' || TO_CHAR(r_slot.deep_positions) || ']'
            || '  Position cube[' || TO_CHAR(r_slot.position_cube) || ']'
            || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']',
            NULL, NULL,
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

        --
        -- Initialization
        --
        l_available_height            := r_slot.available_height;
        l_done_with_slot_bln          := FALSE;
        l_pallet_directed_to_slot_bln := FALSE;
        l_num_positions_used          := 0;
        l_qty_in_slot                 := 0;

        --
        -- If processing occupied slots then find the occupied cube and positions
        -- used in the slot.  When putaway is by cube the occupied cube is used
        -- to calculate the available cube.  The positions used is needed for
        -- deep slots.
        --
        -- 08/25/05 prpbcb  Initially the calculation of the occupied cube was
        -- in the candidate locations select statement
        -- (in pl_rcv_open_po_cursors.sql) using a view but I was not
        -- able to get decent performance because of a full table scan on
        -- the loc table.  Maybe it is better to calculate it only when
        -- necessary because it is possible for the select statement to select
        -- many locations but only a small number of the locations are processed.
        --
        IF (i_occupied_slots_bln = TRUE) THEN
            --
            -- Processing occupied slots or may be occupied so retrieve info
            -- about the slot.
            --
            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'occ slot bln = TRUE',
            NULL, null, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            get_slot_info(r_slot.logi_loc,
                        i_r_item_info,
                        io_r_pallet_table(io_pallet_index).erm_id,
                        l_occupied_cube,
                        l_num_positions_used,
                        l_qty_in_slot);
            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'l_qty_in_slot[' || to_char(l_qty_in_slot) || ']',
            NULL, null, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            --
            -- Calculate the availabe cube in the slot.
            --
            l_available_cube := r_slot.cube - l_occupied_cube;

            --
            -- Check for open positions in deep slots.  If no open positions
            -- then do not attempt to direct any pallets to the slot.
            -- General rule and bulk rule zones are treated the same.
            --
            IF (   (r_slot.deep_ind = 'Y' AND
                          l_num_positions_used >= r_slot.deep_positions AND
                          i_r_zone.rule_id != 2)
             OR (r_slot.deep_ind = 'Y' AND
                          l_num_positions_used >= r_slot.deep_positions AND
                          i_r_zone.rule_id = 2)
            ) THEN
                l_done_with_slot_bln := TRUE;
            END IF;
        ELSE
            --
            -- The candidate slots are empty.
            --
            l_available_cube := r_slot.cube;
        END IF;

        --
        -- Direct pallet(s) to the reserve/floating location based on
        -- stackability, if it is a deep slot and the max number of pallets
        -- of the item that are allowed per zone or aisle.
        --
        -- For non-deep deep slots pallets will be directed to the slot
        -- until the slot is full following stackability logic.
        -- Pallets can be stacked in non-deep slots.
        --
        -- For deep slots pallets are directed to the slot until the number
        -- of deep positions are reached if starting with an empty slot.
        -- If the slot starts off non-empty the direct pallets to the slot
        -- until full ignoring stackability (see the modification history
        -- for the file data 10/11/05).
        -- NOTE: Pallets will not be stacked in deep slots.
        --
        -- If io_r_pallet_table().direct_only_to_open_slot_bln is TRUE then
        -- this procedure would have been called only with empty slots and only
        -- one pallet will be directed to a slot.  An example of a pallet that
        -- needs to go to an open slot is when receiving splits.
        --
        -- If floating items are being putaway by max qty then pallets of the
        -- same item will be directed to the same slot as long as the qoh +
        -- qty received <= max qty and the item is not fifo tracked and syspar
        -- "Combine Pallets in Float Slot" is set to Y.  Stackability is ignored.
        --
        -- If the pallet is on a SN and the pallet qty is >= Ti Hi then
        -- "*" the pallet.  This is the rule.
        --
        <<pallet_loop>>
        WHILE (l_done_with_slot_bln = FALSE
            AND o_status NOT IN (pl_rcv_open_po_types.ct_no_pallets_left,
                                pl_rcv_open_po_types.ct_new_item)) LOOP

            log_pallet_message_rsrv_float(pl_log.ct_info_msg, l_object_name,
                i_r_item_info, io_r_pallet_table(io_pallet_index), r_slot,
                l_available_cube, l_available_height,
                'Processing pallet.');

            --
            -- If the pallet is on a SN and the pallet qty is > Ti Hi then
            -- "*" the pallet.
            --
            IF ((io_r_pallet_table(io_pallet_index).erm_type = 'SN') AND
                (io_r_pallet_table(io_pallet_index).qty_received >
                    i_r_item_info.full_pallet_qty_in_splits)) THEN
                --
                -- The pallet is on a SN and the pallet qty is > Ti Hi.
                -- "*" the pallet.  This is the rule.
                --
                io_r_pallet_table(io_pallet_index).dest_loc := '*';
                insert_records(i_r_item_info,io_r_pallet_table(io_pallet_index));
            ELSE
                --
                -- Direct the pallet to the slot if it fits.
                -- (Brian Bent   We could put the check in a function)
                --
                IF (i_r_item_info.has_home_slot_bln = TRUE) THEN
                    --
                    -- Home slot item.
                    --
                    IF (  (    i_r_syspars.putaway_dimension = 'C'
                            AND l_available_cube >=
                                    io_r_pallet_table(io_pallet_index).cube_with_skid)
                        OR
                            (    i_r_syspars.putaway_dimension = 'I'
                            AND l_available_height >=
                            io_r_pallet_table(io_pallet_index).pallet_height_with_skid
                            AND r_slot.slot_height >=
                            io_r_pallet_table(io_pallet_index).pallet_height_with_skid)
                        ) THEN
                        l_pallet_will_fit_in_slot_bln := TRUE;
                    ELSE
                        l_pallet_will_fit_in_slot_bln := FALSE;
                    END IF;
                ELSE
                    --
                    -- Floating item.
                    --
                    -- See if the pallet will fit.
                    --
                    IF (i_r_item_info.pt_putaway_floating_by_max_qty = 'N') THEN
                        --
                        -- Floating item and NOT putaway by max qty.
                        --
                        IF (  (    i_r_syspars.putaway_dimension = 'C'
                                AND l_available_cube >=
                                    io_r_pallet_table(io_pallet_index).cube_with_skid)
                            OR
                                (    i_r_syspars.putaway_dimension = 'I'
                                AND l_available_height >=
                            io_r_pallet_table(io_pallet_index).pallet_height_with_skid
                                AND r_slot.slot_height >=
                            io_r_pallet_table(io_pallet_index).pallet_height_with_skid)
                            OR
                                ( -- Meat changes, If this is the catch-all floating zone, don't care about cube/height
                                    i_r_zone.rule_id = 1
                                    AND r_slot.cube = 999
                                )
                            ) THEN
                            l_pallet_will_fit_in_slot_bln := TRUE;
                        ELSE
                            l_pallet_will_fit_in_slot_bln := FALSE;
                        END IF;
                    ELSE
                        pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                        'AAAA floating and putawy by max qty',
                        NULL, null, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
                        --
                        -- Floating item and putaway by max qty.
                        --
                        IF (i_r_item_info.max_qty_in_splits  >=
                            (io_r_pallet_table(io_pallet_index).qty_received + l_qty_in_slot))
                        THEN
                            --
                            -- The pallet of the floating item will fit in the
                            -- slot based on the max qty.
                            --
                            l_pallet_will_fit_in_slot_bln := TRUE;
                        ELSE
                            --
                            -- The pallet of the floating item will NOT fit in the
                            -- slot based on the max qty.
                            --
                            l_pallet_will_fit_in_slot_bln := FALSE;
                        END IF;
                    END IF;
                END IF;

                IF (l_pallet_will_fit_in_slot_bln = TRUE) THEN
                    --
                    -- The pallet will fit in the slot.
                    --
                    io_r_pallet_table(io_pallet_index).dest_loc := r_slot.logi_loc;

                    log_pallet_message_rsrv_float(pl_log.ct_info_msg,
                        l_object_name, i_r_item_info,
                        io_r_pallet_table(io_pallet_index), r_slot,
                        l_available_cube, l_available_height,
                        'The pallet will fit in the reserve/floating slot.'
                        || '  Direct the pallet to the slot.');
                    
                    insert_records(i_r_item_info, io_r_pallet_table(io_pallet_index));

                    l_num_pallets_assigned_slot := l_num_pallets_assigned_slot + 1;

                    --
                    -- Keep running total of available cube, available height,
                    -- positions used, qty in slot.
                    --
                    l_available_cube := l_available_cube -
                        io_r_pallet_table(io_pallet_index).cube_with_skid;
                    l_available_height := l_available_height -
                        io_r_pallet_table(io_pallet_index).pallet_height_with_skid;

                    l_pallet_directed_to_slot_bln := TRUE;
                    l_num_positions_used := l_num_positions_used + 1;
                    l_qty_in_slot := io_r_pallet_table(io_pallet_index).qty_received;
                ELSE
                    --
                    -- The pallet will not fit in the slot.
                    --
                    l_done_with_slot_bln := TRUE;
                END IF;
            END IF;   -- end * the pallet

            IF (l_done_with_slot_bln = FALSE) THEN
                --
                -- See if the last pallet was processed.
                --
                IF (io_pallet_index = io_r_pallet_table.LAST) THEN
                    --
                    -- No more pallets to process.
                    --
                    l_done_with_slot_bln := TRUE;
                    o_status := pl_rcv_open_po_types.ct_no_pallets_left;
                ELSE
                    --
                    -- Position at the next pallet.
                    --
                    io_pallet_index := io_r_pallet_table.NEXT(io_pallet_index);

                    --
                    -- If the next pallet to process is for a different item or uom
                    -- then the procoessing is done for the current item.
                    -- A change in the uom even if it is the same item requires
                    -- different processing.
                    --
                    IF (   l_previous_prod_id !=
                                io_r_pallet_table(io_pallet_index).prod_id
                        OR l_previous_cust_pref_vendor !=
                                io_r_pallet_table(io_pallet_index).cust_pref_vendor
                        OR l_previous_uom !=
                                io_r_pallet_table(io_pallet_index).uom
                        OR l_previous_partial_pallet_flag !=
                                io_r_pallet_table(io_pallet_index).partial_pallet_flag
                        OR (pl_common.f_is_internal_production_po(io_r_pallet_table(io_pallet_index).erm_id) AND 
                            l_previous_order_id != io_r_pallet_table(io_pallet_index).order_id
                        )
                    )
                    THEN
                        l_done_with_slot_bln := TRUE;
                        o_status := pl_rcv_open_po_types.ct_new_item;
                    ELSE
                        --
                        -- The next pallet is for the same item.
                        --
                        -- Check stackability and deep positions to see if an attempt
                        -- should be made to direct the pallet to the slot.
                        -- See the modification history for the file dated
                        -- 10/11/05 for information on how deep slots are handled.
                        --
                        IF (  (i_r_item_info.has_home_slot_bln = TRUE OR
                                (i_r_item_info.has_home_slot_bln = FALSE AND
                                i_r_item_info.pt_putaway_floating_by_max_qty = 'N'))
                            AND (i_r_item_info.stackable = 0 AND r_slot.deep_ind = 'N')
                                OR (r_slot.deep_ind = 'Y' AND
                                    l_num_positions_used >= r_slot.deep_positions AND
                                    i_r_zone.rule_id != 2)
                                OR (r_slot.deep_ind = 'Y' AND
                                    l_num_positions_used >= r_slot.deep_positions AND
                                    i_r_zone.rule_id = 2)
                            ) THEN
                            l_done_with_slot_bln := TRUE;
                        END IF;

                        --
                        -- Check if a pallet can be directed only to open slots (a
                        -- pallet has just been put in the slot so it is no longer
                        -- open)
                        --
                        IF (l_done_with_slot_bln = FALSE AND
                            io_r_pallet_table(io_pallet_index).direct_only_to_open_slot_bln
                                                                            = TRUE)
                        THEN
                                l_done_with_slot_bln := TRUE;
                        END IF;

                        --
                        -- For a floating item, check if pallets of the same item
                        -- can be combined in floating slots
                        -- Regardless of if non_fifo_combine_plts_in_float syspar is 'Y',
                        -- we will combine pallets in the floating slot if the slot 
                        -- has exactly 999 cube and the zone's rule_id = 1'
                        --
                        IF (l_done_with_slot_bln = FALSE AND
                            i_r_item_info.has_home_slot_bln = FALSE) THEN
                        
                            IF i_r_syspars.non_fifo_combine_plts_in_float = 'Y' OR 
                                (i_r_zone.rule_id = 1 AND r_slot.cube = 999) THEN
                                
                                l_done_with_slot_bln := FALSE;
                            ELSE
                                l_done_with_slot_bln := TRUE;
                            END IF;
                        END IF;

                    END IF;
                END IF;  -- end if checking if different item
            END IF;  -- end IF (l_done_with_slot_bln = FALSE)
        END LOOP pallet_loop;

        --
        -- If a pallet was assigned to the slot just processed then
        -- show the item occupies another slot in the zone.
        --
        IF (l_pallet_directed_to_slot_bln = TRUE) THEN
            io_num_slots_with_item_in_zone := io_num_slots_with_item_in_zone + 1;
        END IF;

    END LOOP candidate_slot_loop;

    pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
        'Leaving procedure.  i_r_zone.zone_id[' || i_r_zone.zone_id || ']'
        || '  io_pallet_index[' || TO_CHAR(io_pallet_index) || ']'
        || '  o_status[' || TO_CHAR(o_status) || ']'
        || '  Number of pallets assigned a slot['
        || TO_CHAR(l_num_pallets_assigned_slot) || ']'
        || '  Number of slots processed[' || TO_CHAR(l_num_slots_processed)
        || ']'
        || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']',
        NULL, NULL,
        pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
    WHEN OTHERS THEN
        l_message := l_object_name
            || '(i_r_syspars,i_r_item_info,i_r_zone,i_curvar_locations'
            || ',i_occupied_slots_bln,io_r_pallet_table,io_pallet_index'
            || ',io_num_slots_with_item_in_zone,o_status)'
            || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
            || '  Item[' || i_r_item_info.prod_id || ']'
            || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
            || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';
        pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
        RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_pallets_to_slots_inzone;


---------------------------------------------------------------------------
-- Procedure:
--    direct_to_non_deep_slots
--
-- Description:
--    This procedure directs pallets for an item with a home slot to
--    non-deep reserve slots in the specified zone.
--
--    Slots are checked in this order:
--       Full Pallet
--         1.  Open non-deep slots.
--
--             The slot cube needs to be >= home slot cube to be
--             considered a candidate slot if pseudo syspar
--             chk_reserve_cube_ge_home_cube is 'Y' which it is.
--             If receiving splits then this rule does not apply.
--             08/20/05 prpbcb Pseudo syspar chk_reserve_cube_ge_home_cube
--                             default value is Y.
--         2.  Non-open non-deep slots that have at least one pallet of
--             the item.  The slot can have other items.
--         3.  Any non-deep with existing inventory, any product.
--      Partial Pallet
--         The order the slots are checked depend on syspars:
--            PARTIAL_NONDEEPSLOT_SEARCH_CLR
--            PARTIAL_NONDEEPSLOT_SEARCH_FRZ
--            PARTIAL_NONDEEPSLOT_SEARCH_DRY
--         See procedure set_nondeep_partial_slotsearch() for more info.
--         When receiving splits, uom = 1, the pallet will always be directed
--         to an open slot.  The above syspars are ignored.
--
--    This procedure will be called if receiving splits for an aging item.
--    When this happens only opens slots are checked.  Splits of an aging
--    item will not go to a slot with existing inventory.
--
-- Parameters:
--    i_r_syspars        - Syspars
--    io_r_item_info     - Item information record.
--    i_r_zone           - Putaway zone to direct pallets to.
--    io_r_pallet_table  - Table of pallet records to find slots for.
--    io_pallet_index    - The index of the pallet to process.
--                         This will be incremented by the number of pallets
--                         assigned to the slots.
--    o_status           - Status of finding slots for the item.  The value
--                         will be one of the following:
--                           - ct_no_pallets_left - All the pallets have been
--                                                  processed for the item.
--                           - ct_new_item        - The next pallet to process
--                                                  is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_rsrv_float
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/05 prpbcb   Created
--    10/06/05 prpbcb   Rearrange things to cut down on the lines of code.
--    02/22/06 prpbcb   Changed to call procedure
--                      set_nondeep_partial_slotsearch() to set the slot
--                      search order when processing a partial pallet.
---------------------------------------------------------------------------
PROCEDURE direct_to_non_deep_slots
    (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
     io_r_item_info        IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info,
     i_r_zone              IN     gl_c_zones%ROWTYPE,
     io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     io_pallet_index       IN OUT PLS_INTEGER,
     o_status              IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_to_non_deep_slots';

   /* Charm# 6000003789: changed data type from VARCHAR2(10) to VARCHAR2(14) */
   l_chk_rsrv_cube_ge_home_cube VARCHAR2(14);  /*was 10*/ -- Designates if to select
                                  -- candidate slots with a cube >= home
                                  -- slot cube when putaway is by cube.  It
                                  -- is passed to the procedure
                                  -- that sends back the REF CURSOR pointing
                                  -- to the candidate locations.  Note that
                                  -- not all the cursors will be using it.
                                  -- Valid values are Y or N.

   l_chk_rsrv_hgt_ge_home_hgt  VARCHAR2(10);  -- Designates if to select
                                  -- candidate slots with a true slot height
                                  -- >= home slot true slot height when putaway
                                  -- is by inches.  It
                                  -- is passed to the procedure
                                  -- that sends back the REF CURSOR pointing
                                  -- to the candidate locations.  Note that
                                  -- not all the cursors will be using it.
                                  -- Valid values are Y or N.

   l_exhausted_options_bln BOOLEAN;  -- Have all the options looking for slots
                                     -- been exhausted?  It is set when
                                     -- processing a partial pallet. There are
                                     -- syspars (For cooler, freezer, and dry)
                                     -- the user can set to control the order
                                     -- the slots are checked for a partial
                                     -- pallet.

   l_num_slots_with_item_in_zone PLS_INTEGER;  -- The number of slots in a zone
                                           -- that has a pallet of the item
                                           -- being processed.  It is used with
                                           -- pm.max_slot and pm.max_slot_per
                                           -- to limit the number of slots
                                           -- in a zone with a pallet of the
                                           -- item.

   l_processing_occupied_slots BOOLEAN;    -- Used to designate when the
                                           -- candidate putaway slots are
                                           -- occupied or could be occupied.

   l_what_slots_to_check VARCHAR2(30) := NULL; -- Set to what slots to check.

   l_curvar_locations  pl_rcv_open_po_types.t_refcur_location;
BEGIN
   --
   -- Initialization.
   --
   l_num_slots_with_item_in_zone := 0;
   o_status := pl_rcv_open_po_types.ct_same_item;
   l_exhausted_options_bln := FALSE;  -- This needs to start off FALSE.

   --
   -- Set the put_aisle, put_slot and put_level if the item has a home slot in
   -- the zone being processed.  Candidate slots are selected closest to these
   -- put values.
   --
   set_put_path_values(io_r_item_info,
                       i_r_zone,
                       io_r_pallet_table(io_pallet_index).erm_id);

   --
   -- If receiving splits then do not check if the candidate open slot cube
   -- (or height if putaway by inches)
   -- is >= home slot cube (or height) otherwise use the syspar.
   --
   IF (io_r_pallet_table(io_pallet_index).uom = 1) THEN
      l_chk_rsrv_cube_ge_home_cube := 'N';
      l_chk_rsrv_hgt_ge_home_hgt := 'N';
   ELSE
      l_chk_rsrv_cube_ge_home_cube := i_r_syspars.chk_reserve_cube_ge_home_cube;
      l_chk_rsrv_hgt_ge_home_hgt := i_r_syspars.chk_reserve_hgt_ge_home_hgt;
   END IF;


   --
   -- Direct the pallets to slots.
   --
   -- The order of checking slots is different for a full pallet and a
   -- partial pallet.
   --
   -- If a full pallet then check open slots.
   -- If a partial pallet then check slots based on the syspars.
   --
   IF (io_r_pallet_table(io_pallet_index).partial_pallet_flag = 'N') THEN
      --
      -- Full pallet.  Check open slots.
      --
      l_what_slots_to_check := pl_rcv_open_po_types.ct_open_slot;
      l_processing_occupied_slots := FALSE;
      l_message := '  Directing pallets to open non-deep slots.';
   ELSE
      --
      -- Partial pallet.
      -- Determine what slots to check based on syspars.
      --
      -- Note: If direct_only_to_open_slot_bln for the pallet is true then
      -- set_nondeep_partial_slotsearch will set to check open slots.
      --
      set_nondeep_partial_slotsearch
                          (io_r_item_info,
                           io_r_pallet_table(io_pallet_index),
                           l_what_slots_to_check,
                           l_processing_occupied_slots,
                           l_message,
                           l_exhausted_options_bln);
   END IF;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
            || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
            || ']'
            || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
            || '  l_what_slots_to_check[' || l_what_slots_to_check || ']'
            || '  ' || l_message
            || '  Note:  Only reserve slots with a cube >= the home slot'
            || ' cube will be considered when directing pallets to open'
            || ' non-deep slots except when receiving splits.',
            NULL, NULL,
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

   IF (l_exhausted_options_bln = FALSE) THEN
      pl_rcv_open_po_cursors.non_deep_slots
                 (l_what_slots_to_check,
                  i_r_syspars,
                  io_r_item_info,
                  io_r_pallet_table(io_pallet_index),
                  i_r_zone.zone_id,
                  l_chk_rsrv_cube_ge_home_cube,
                  l_chk_rsrv_hgt_ge_home_hgt,
                  l_curvar_locations);

      direct_pallets_to_slots_inzone
                                 (i_r_syspars,
                                  io_r_item_info,
                                  i_r_zone,
                                  l_curvar_locations,
                                  l_processing_occupied_slots,
                                  io_r_pallet_table,
                                  io_pallet_index,
                                  l_num_slots_with_item_in_zone,
                                  o_status);

      CLOSE l_curvar_locations;
   END IF;

   --
   -- If there are still pallets of the item to find slots for and the pallet
   -- does not have to go to an empty slot then check the appropriate slots.
   --
   IF (o_status = pl_rcv_open_po_types.ct_same_item
       AND io_r_pallet_table(io_pallet_index).direct_only_to_open_slot_bln =
                                                                       FALSE
       AND l_exhausted_options_bln = FALSE) THEN
      --
      -- If this point reached then still look for slots.
      --
      -- If a full pallet then direct pallets to slots with the same item.
      -- If a partial pallet then check slots based on the syspars.
      --
      IF (io_r_pallet_table(io_pallet_index).partial_pallet_flag = 'N') THEN
         --
         -- Full pallet.  Check slots with the same item.
         --
         l_what_slots_to_check := pl_rcv_open_po_types.ct_same_item_slot;
         l_processing_occupied_slots := TRUE;
         l_message := 'There are still pallets of the item to find slots for.'
              || ' Directing pallets to non-deep slots with the same item.';
      ELSE
         --
         -- Partial pallet.
         --
         set_nondeep_partial_slotsearch
                          (io_r_item_info,
                           io_r_pallet_table(io_pallet_index),
                           l_what_slots_to_check,
                           l_processing_occupied_slots,
                           l_message,
                           l_exhausted_options_bln);
      END IF;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
               'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
               || '  CPV['
               || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
               || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
               || '  l_what_slots_to_check[' || l_what_slots_to_check || ']'
               || '  ' || l_message,
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      IF (l_exhausted_options_bln = FALSE) THEN
         pl_rcv_open_po_cursors.non_deep_slots
                  (l_what_slots_to_check,
                   i_r_syspars,
                   io_r_item_info,
                   io_r_pallet_table(io_pallet_index),
                   i_r_zone.zone_id,
                   l_chk_rsrv_cube_ge_home_cube,
                   l_chk_rsrv_hgt_ge_home_hgt,
                   l_curvar_locations);

         direct_pallets_to_slots_inzone
                  (i_r_syspars,
                   io_r_item_info,
                   i_r_zone,
                   l_curvar_locations,
                   l_processing_occupied_slots,
                   io_r_pallet_table,
                   io_pallet_index,
                   l_num_slots_with_item_in_zone,
                   o_status);

         CLOSE l_curvar_locations;
      END IF;  -- end IF (l_exhausted_options_bln = FALSE)
   END IF;


   --
   -- If there are still pallets of the item to find slots for and the pallet
   -- does not have to go to an empty slot then check the appropriate slots.
   --
   IF (    o_status = pl_rcv_open_po_types.ct_same_item
       AND io_r_pallet_table(io_pallet_index).direct_only_to_open_slot_bln =
                                                                       FALSE
       AND l_exhausted_options_bln = FALSE) THEN
      --
      -- If this point reached then still look for slots.
      --
      -- If a full pallet then direct pallets to any available slot.
      -- For partial pallets direct to slots based on syspars.
      --
      IF (io_r_pallet_table(io_pallet_index).partial_pallet_flag = 'N') THEN
         --
         -- Full pallet.  Check any available slot.
         --
         l_what_slots_to_check := pl_rcv_open_po_types.ct_any_non_empty_slot;
         l_processing_occupied_slots := TRUE;
         l_message := 'There are still pallets of the item to find slots for.'
           || ' Directing pallets to any available non-empty non-deep slots.';
      ELSE
         --
         -- Partial pallet.  Check open slots.
         --
         set_nondeep_partial_slotsearch
                          (io_r_item_info,
                           io_r_pallet_table(io_pallet_index),
                           l_what_slots_to_check,
                           l_processing_occupied_slots,
                           l_message,
                           l_exhausted_options_bln);
      END IF;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
               'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
               || '  CPV['
               || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
               || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
               || '  l_what_slots_to_check[' || l_what_slots_to_check || ']'
               || '  ' || l_message,
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      IF (l_exhausted_options_bln = FALSE) THEN
         pl_rcv_open_po_cursors.non_deep_slots
                  (l_what_slots_to_check,
                   i_r_syspars,
                   io_r_item_info,
                   io_r_pallet_table(io_pallet_index),
                   i_r_zone.zone_id,
                   l_chk_rsrv_cube_ge_home_cube,
                   l_chk_rsrv_hgt_ge_home_hgt,
                   l_curvar_locations);

         direct_pallets_to_slots_inzone
                  (i_r_syspars,
                   io_r_item_info,
                   i_r_zone,
                   l_curvar_locations,
                   l_processing_occupied_slots,
                   io_r_pallet_table,
                   io_pallet_index,
                   l_num_slots_with_item_in_zone,
                   o_status);

         CLOSE l_curvar_locations;
      END IF;
   END IF;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'Leaving procedure.'
       || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || '  o_status[' || TO_CHAR(o_status) || '].',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,io_r_item_info,i_r_zone,io_r_pallet_table,'
         || 'io_pallet_index,o_status)'
         || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_item_info.prod_id || ']'
         || '  CPV[' || io_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_to_non_deep_slots;


---------------------------------------------------------------------------
-- Procedure:
--    direct_to_deep_slots
--
-- Description:
--    This procedure directs pallets for an item to deep reserve
--    slots in the specified zone.
--
--    Slots are checked in this order:
--       1.  Non-open slots that only have the same item in the slot.
--           Syspar MIX_SAME_PROD_DEEP_SLOT controls if to allow or not
--           allow putting away like items with different receive dates
--           to the same deep slot.
--       2.  Open deep slots.
--       3.  Any deep slot if syspar 2D3D_MIXPROD_FLAG is Y.
--           At this point the available slots will be occupied slots
--           with different items and could have a pallet of the same item.
--           If the slot has the same item then syspar
--           MIX_SAME_PROD_DEEP_SLOT controls if a pallet will be directed
--           to the slot.
--
--    This procedure will be called if receiving splits for an aging item.
--    When this happens only opens slots are checked.  Splits of an aging
--    item will not go to a slot with existing inventory.
--
--    An aging item will always go to an empty slot.
--
--
-- Parameters:
--    i_r_syspars        - Syspars
--    io_r_item_info     - Item information record.
--    i_r_zone           - Putaway zone to direct pallets to.
--    io_r_pallet_table  - Table of pallet records to find slots for.
--    io_pallet_index    - The index of the pallet to process.
--                         This will be incremented by the number of pallets
--                         assigned to the slots.
--    o_status           - Status of finding slots for the item.  The value
--                         will be one of the following:
--                           - ct_no_pallets_left - All the pallets have been
--                                                  processed for the item.
--                           - ct_new_item        - The next pallet to process
--                                                  is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_to_deep_slots
    (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
     io_r_item_info        IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info,
     i_r_zone              IN     gl_c_zones%ROWTYPE,
     io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     io_pallet_index       IN OUT PLS_INTEGER,
     o_status              IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_to_deep_slots';

   l_buf               VARCHAR2(20);       -- Work area
   l_num_slots_with_item_in_zone PLS_INTEGER;  -- The number of slots in a zone
                                           -- that has a pallet of the item
                                           -- being processed.  It is used with
                                           -- pm.max_slot and pm.max_slot_per
                                           -- to limit the number of slots
                                           -- in a zone with a pallet of the
                                           -- item.

   l_processing_occupied_slots BOOLEAN;    -- Used to designate when the
                                           -- candidate putaway slots are
                                           -- occupied or could be occupied.

   l_curvar_locations  pl_rcv_open_po_types.t_refcur_location;
BEGIN
   --
   -- Initialization.
   --
   l_num_slots_with_item_in_zone := 0;
   o_status := pl_rcv_open_po_types.ct_same_item;

   --
   -- Direct pallets to deep slots with the same item if the pallet does not
   -- have to go to an empty slot.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
       || ' CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
       || ']'
       || ' PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || ' Directing pallets to deep slots with the same item.',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

   --
   -- Set the put_aisle, put_slot and put_level if the item has a home slot in
   -- the zone being processed.
   --
   set_put_path_values(io_r_item_info, i_r_zone,
                       io_r_pallet_table(io_pallet_index).erm_id);

   IF (io_r_pallet_table(io_pallet_index).direct_only_to_open_slot_bln =
                                                                 FALSE) THEN


      pl_rcv_open_po_cursors.deep_slots
                  (pl_rcv_open_po_types.ct_same_item_slot,
                   i_r_syspars,
                   io_r_item_info,
                   io_r_pallet_table(io_pallet_index),
                   i_r_zone.zone_id,
                   l_curvar_locations);

      l_processing_occupied_slots := TRUE;

      direct_pallets_to_slots_inzone
                  (i_r_syspars,
                   io_r_item_info,
                   i_r_zone,
                   l_curvar_locations,
                   l_processing_occupied_slots,
                   io_r_pallet_table,
                   io_pallet_index,
                   l_num_slots_with_item_in_zone,
                   o_status);

      CLOSE l_curvar_locations;
   ELSE
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
          || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
          || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
          || ']'
          || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
          || '  Pallet has to go to an open slot.',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   END IF;

   --
   -- If there are still pallets of the item to find slots for
   -- then direct the pallets to open deep slots.
   --
   IF (o_status = pl_rcv_open_po_types.ct_same_item) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
         || '  There are still pallets of the item to find slots for.'
         || '  Directing pallets to open deep slots.',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      pl_rcv_open_po_cursors.deep_slots
                (pl_rcv_open_po_types.ct_open_slot,
                 i_r_syspars,
                 io_r_item_info,
                 io_r_pallet_table(io_pallet_index),
                 i_r_zone.zone_id,
                 l_curvar_locations);

      l_processing_occupied_slots := FALSE;

      direct_pallets_to_slots_inzone
                (i_r_syspars,
                 io_r_item_info,
                 i_r_zone,
                 l_curvar_locations,
                 l_processing_occupied_slots,
                 io_r_pallet_table,
                 io_pallet_index,
                 l_num_slots_with_item_in_zone,
                 o_status);

      CLOSE l_curvar_locations;
   END IF;

   --
   -- If there are still pallets of the item to find slots for and the
   -- pallet does not have to go to an empty slot then direct the pallets
   -- to deep slots with different items if the syspar allows this.
   --
   IF (    o_status = pl_rcv_open_po_types.ct_same_item
       AND io_r_pallet_table(io_pallet_index).direct_only_to_open_slot_bln =
                                                             FALSE
       AND i_r_syspars.mixprod_2d3d_flag = 'Y') THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
             'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
             || ' CPV['
             || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
             || ' PO/SN['
             || io_r_pallet_table(io_pallet_index).erm_id || ']'
             || ' Type[' || io_r_pallet_table(io_pallet_index).erm_type
             || ']'
             || '  There are still pallets of the item to find slots for.'
             || '  Directing pallets to deep slots with different items.',
             NULL, NULL,
             pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      pl_rcv_open_po_cursors.deep_slots
                (pl_rcv_open_po_types.ct_different_item_slot,
                 i_r_syspars,
                 io_r_item_info,
                 io_r_pallet_table(io_pallet_index),
                 i_r_zone.zone_id,
                 l_curvar_locations);

      l_processing_occupied_slots := TRUE;

      direct_pallets_to_slots_inzone
                (i_r_syspars,
                 io_r_item_info,
                 i_r_zone,
                 l_curvar_locations,
                 l_processing_occupied_slots,
                 io_r_pallet_table,
                 io_pallet_index,
                 l_num_slots_with_item_in_zone,
                 o_status);

      CLOSE l_curvar_locations;
   END IF;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'Leaving procedure.'
       || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || '  o_status[' || TO_CHAR(o_status) || '].',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,io_r_item_info,i_r_zone,io_r_pallet_table,'
         || 'io_pallet_index,o_status)'
         || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_item_info.prod_id || ']'
         || '  CPV[' || io_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_to_deep_slots;


---------------------------------------------------------------------------
-- Procedure:
--    direct_to_floating_slots
--
-- Description:
--    This procedure directs pallets for an item to floating slots in the
--    specified zone.
--
--    Slots are checked in this order:
--       1.  Open slots.  But if syspar NON_FIFO_COMBINE_PLTS_IN_FLOAT is Y
--           and it is not a FIFO item then the pallet can to a slot
--           occupied with only pallets of that item.
--
--           Splits for a floating item will always be directed to an empty
--           floating slot regardless of the setting of syspar
--           NON_FIFO_COMBINE_PLTS_IN_FLOAT.
--
--
-- Parameters:
--    i_r_syspars        - Syspars
--    io_r_item_info     - Item information record.
--    i_r_zone           - Putaway zone to direct pallets to.
--    io_r_pallet_table  - Table of pallet records to find slots for.
--    io_pallet_index    - The index of the pallet to process.
--                         This will be incremented by the number of pallets
--                         assigned to the slots.
--    o_status           - Status of finding slots for the item.  The value
--                         will be one of the following:
--                           - ct_no_pallets_left - All the pallets have been
--                                                  processed for the item.
--                           - ct_new_item        - The next pallet to process
--                                                  is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_rsrv_float
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_to_floating_slots
    (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
     io_r_item_info        IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info,
     i_r_zone              IN     gl_c_zones%ROWTYPE,
     io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     io_pallet_index       IN OUT PLS_INTEGER,
     o_status              OUT    PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_to_floating_slots';

   l_buf               VARCHAR2(20);       -- Work area
   l_direct_only_to_open_slot   VARCHAR2(1);  -- Designates if to direct the
                                               -- pallet only to empty floating
                                               -- slots.

   l_num_slots_with_item_in_zone PLS_INTEGER;  -- The number of slots in a zone
                                           -- that has a pallet of the item
                                           -- being processed.  It is used with
                                           -- pm.max_slot and pm.max_slot_per
                                           -- to limit the number of slots
                                           -- in a zone with a pallet of the
                                           -- item.

   l_processing_occupied_slots BOOLEAN;    -- Used to designate when the
                                           -- candidate putaway slots are
                                           -- occupied or could be occupied.

   l_curvar_locations  pl_rcv_open_po_types.t_refcur_location;
BEGIN
   --
   -- Initialization.
   --
   l_num_slots_with_item_in_zone := 0;

   --
   -- Direct pallets to floating slots.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
      'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
      || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
      || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
      || '  Zone[' || i_r_zone.zone_id || ']'
      || ' Directing pallets to floating slots.',
      NULL, NULL,
      pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

   --
   -- Set the put_aisle, put_slot and put_level if the item exists in
   -- the zone being processed.
   --
   set_put_path_values(io_r_item_info, i_r_zone,
                       io_r_pallet_table(io_pallet_index).erm_id);

   IF (io_r_pallet_table(io_pallet_index).direct_only_to_open_slot_bln =
                                                                TRUE) THEN
      l_direct_only_to_open_slot := 'Y';
   ELSE
      l_direct_only_to_open_slot := 'N';
   END IF;

   pl_rcv_open_po_cursors.floating_slots
                 (i_r_syspars,
                  io_r_item_info,
                  io_r_pallet_table(io_pallet_index),
                  i_r_zone.zone_id,
                  l_direct_only_to_open_slot,
                  l_curvar_locations);

   --
   -- Make or do not make procedure direct_pallets_to_slots_inzone calculate the
   -- occupied cube in the candidate slots.  The candidate putaway slots
   -- selected by procedure pl_rcv_open_po_cursors will either be all open
   -- or could be occupied depending on the value of syspar
   -- non_fifo_combine_plts_in_float.
   --
   IF (i_r_syspars.non_fifo_combine_plts_in_float = 'Y') THEN
      --
      -- The candidate putaway slots may be occupied.  The occupied cube
      -- will need to be calculated.
      --
      l_processing_occupied_slots := TRUE;
   ELSE
      --
      -- The candidate putaway slots will be open.  The occupied cube does
      -- not need to be calculated.
      --
      l_processing_occupied_slots := FALSE;
   END IF;

   direct_pallets_to_slots_inzone
                  (i_r_syspars,
                   io_r_item_info,
                   i_r_zone,
                   l_curvar_locations,
                   l_processing_occupied_slots,
                   io_r_pallet_table,
                   io_pallet_index,
                   l_num_slots_with_item_in_zone,
                   o_status);

   CLOSE l_curvar_locations;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'Leaving procedure.'
       || ' PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || '  o_status[' || TO_CHAR(o_status) || '].',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,io_r_item_info,i_r_zone,io_r_pallet_table'
         || ',io_pallet_index,o_status)'
         || '  LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']'
         || '  Item[' || io_r_item_info.prod_id || ']'
         || '  CPV[' || io_r_item_info.cust_pref_vendor || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_to_floating_slots;


---------------------------------------------------------------------------
-- Procedure:
--    direct_to_bulk_rule_zone
--
-- Description:
--    This procedure directs pallets for to slots in a bulk rule zone.
--
--    Slots are checked in this order:
--       If the item exists in the bulk rule zone:
--          1.  Slots with the same item.
--          2.  Open slots.
--          3.  Slots with different items if syspar MIX_PROD_BULK_AREA is Y.
--
--       If the item does not exist in the bulk rule zone:
--          1.  Open slots.
--          2.  Slots with different items if syspar MIX_PROD_BULK_AREA is Y.
--
-- Parameters:
--    i_r_syspars        - Syspars
--    io_r_item_info     - Item information record.
--    i_r_zone           - Putaway zone to direct pallets to.
--    io_r_pallet_table  - Table of pallet records to find slots for.
--    io_pallet_index    - The index of the pallet to process.
--                         This will be incremented by the number of pallets
--                         assigned to the slots.
--    o_status           - Status of finding slots for the item.  The value
--                         will be one of the following:
--                           - ct_no_pallets_left - All the pallets have been
--                                                  processed for the item.
--                           - ct_new_item        - The next pallet to process
--                                                  is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_to_bulk_rule_zone
    (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
     io_r_item_info        IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info,
     i_r_zone              IN     gl_c_zones%ROWTYPE,
     io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     io_pallet_index       IN OUT PLS_INTEGER,
     o_status              IN OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_to_bulk_rule_zone';

   l_buf               VARCHAR2(20);       -- Work area
   l_dummy             VARCHAR2(1);        -- Work area
   l_item_in_zone_bln  BOOLEAN;            -- Desigates if the item currently
                                           -- exists in the bulk rule zone.
   l_num_slots_with_item_in_zone PLS_INTEGER;  -- The number of slots in a zone
                                           -- that has a pallet of the item
                                           -- being processed.  It is used with
                                           -- pm.max_slot and pm.max_slot_per
                                           -- to limit the number of slots
                                           -- in a zone with a pallet of the
                                           -- item.
   l_processing_occupied_slots BOOLEAN;    -- Used to designate when the
                                           -- candidate putaway slots are
                                           -- occupied or could be occupied.

   l_curvar_locations  pl_rcv_open_po_types.t_refcur_location;

   --
   -- This cursor checks if the item has inventory in the bulk rule zone.
   --
   CURSOR c_item_in_zone(cp_zone_id          zone.zone_id%TYPE,
                         cp_prod_id          pm.prod_id%TYPE,
                         cp_cust_pref_vendor pm.cust_pref_vendor%TYPE) IS
      SELECT 'x'
        FROM inv i, lzone lz
       WHERE lz.zone_id         = cp_zone_id
         AND i.plogi_loc        = lz.logi_loc
         AND i.prod_id          = cp_prod_id
         AND i.cust_pref_vendor = cp_cust_pref_vendor;
BEGIN
   --
   -- Initialization.
   --
   l_num_slots_with_item_in_zone := 0;

   OPEN c_item_in_zone(i_r_zone.zone_id,
                       io_r_item_info.prod_id,
                       io_r_item_info.cust_pref_vendor);
   FETCH c_item_in_zone INTO l_dummy;
   IF (c_item_in_zone%FOUND) THEN
      l_item_in_zone_bln := TRUE;
   ELSE
      l_item_in_zone_bln := FALSE;
   END IF;
   CLOSE c_item_in_zone;

   --
   -- If the item currently exists in the bulk rule zone then direct pallets
   -- to the slots with the current inventory then to open slots then to
   -- available slots.
   -- If the item does not exist in the bulk rule zone then direct pallets
   -- to open slots then to available slots.
   --
   IF (l_item_in_zone_bln = TRUE) THEN
      --
      -- The item currently exists in the bulk rule zone.  Direct pallets to
      -- the slots that have the current inventory.
      --
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
          'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
          || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
          || ']'
          || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
          || '  The item currently exists in bulk rule zone '
          || i_r_zone.zone_id || '.  Directing pallets to the slots with'
          || ' the current inventory.',
          NULL, NULL,
          pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      pl_rcv_open_po_cursors.bulk_rule_slots
                 (pl_rcv_open_po_types.ct_same_item_slot,
                  i_r_syspars,
                  io_r_item_info,
                  io_r_pallet_table(io_pallet_index),
                  i_r_zone.zone_id,
                  l_curvar_locations);

      l_processing_occupied_slots := TRUE;

      direct_pallets_to_slots_inzone
                 (i_r_syspars,
                  io_r_item_info,
                  i_r_zone,
                  l_curvar_locations,
                  l_processing_occupied_slots,
                  io_r_pallet_table,
                  io_pallet_index,
                  l_num_slots_with_item_in_zone,
                  o_status);

      CLOSE l_curvar_locations;
   END IF;

   --
   -- If there are still pallets of the item to find slots for then direct
   -- the pallets to open slots.
   --
   IF (o_status = pl_rcv_open_po_types.ct_same_item) THEN
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV['
         || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
         || '  There are still pallets of the item to find slots for.'
         || '  Directing pallets to open slots in bulk rule zone '
         || i_r_zone.zone_id || '.',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      pl_rcv_open_po_cursors.bulk_rule_slots
                 (pl_rcv_open_po_types.ct_open_slot,
                  i_r_syspars,
                  io_r_item_info,
                  io_r_pallet_table(io_pallet_index),
                  i_r_zone.zone_id,
                  l_curvar_locations);

      l_processing_occupied_slots := FALSE;

      direct_pallets_to_slots_inzone
                 (i_r_syspars,
                  io_r_item_info,
                  i_r_zone,
                  l_curvar_locations,
                  l_processing_occupied_slots,
                  io_r_pallet_table,
                  io_pallet_index,
                  l_num_slots_with_item_in_zone,
                  o_status);

      CLOSE l_curvar_locations;

      --
      -- If there are still pallets of the item to find slots for
      -- then direct the pallets to available slots that have other items
      -- if syspar MIX_PROD_BULK_AREA is Y.
      --
      IF (o_status = pl_rcv_open_po_types.ct_same_item) THEN
         --
         -- There are still pallets of the item to find slots for.
         -- Direct pallets to available slots, which will be slots with
         -- pallets of other items, if syspar MIX_SAME_PROD_DEEP_SLOT
         -- allows this.
         --
         IF (i_r_syspars.mix_prod_bulk_area = 'Y') THEN
            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
              'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
              || '  CPV['
              || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
              || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
              || '  There are still pallets of the item to find slots for.'
              || '  Directing pallets to slots in bulk rule zone '
              || i_r_zone.zone_id || ' that have other items.',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            pl_rcv_open_po_cursors.bulk_rule_slots
                   (pl_rcv_open_po_types.ct_different_item_slot,
                    i_r_syspars,
                    io_r_item_info,
                    io_r_pallet_table(io_pallet_index),
                    i_r_zone.zone_id,
                    l_curvar_locations);

            l_processing_occupied_slots := TRUE;

            direct_pallets_to_slots_inzone
                   (i_r_syspars,
                    io_r_item_info,
                    i_r_zone,
                    l_curvar_locations,
                    l_processing_occupied_slots,
                    io_r_pallet_table,
                    io_pallet_index,
                    l_num_slots_with_item_in_zone,
                    o_status);

            CLOSE l_curvar_locations;
         ELSE
            --
            -- Syspar MIX_SAME_PROD_DEEP_SLOT is set to N.
            --
            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
               'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
               || '  CPV['
               || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
               || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
               || '  There are still pallets of the item to find slots for.'
               || '  Syspar "Mix items in bulk area slot" is set to N'
               || ' therefore no more slots will be checked.',
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
         END IF;
      END IF;
   END IF;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       ' PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || 'Leaving procedure.'
       || '  o_status[' || TO_CHAR(o_status) || '].',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,io_r_item_info,i_r_zone,io_r_pallet_table'
         || ',io_pallet_index,o_status)'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV['
         || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_to_bulk_rule_zone;


---------------------------------------------------------------------------
--  Procedure:
--      direct_pallets_to_prod_staging
--  Description:
--      This procedure directs pallets to a staging location that is setup
--      in the inbound_cust_setup table. We direct to staging loc based where
--      erd.cust_id = inbound_cust_setup.cust_id
--
--  Parameters:
--      i_r_syspars         - Syspars
--      io_r_item_info      - Item information record
--      io_r_pallet_table   - Table of pallet records to find slots for
--      io_pallet_index     - The index of the pallet to process. This 
--                              will be incremented by the number of pallets
--                              assigned to the slots
--      o_status            - Status of finding slots for the item. The value
--                              will be one of the following:
--                                  - ct_no_pallets_left:   All the pallets have
--                                                          been processed for the item 
--                                  - ct_new_item:          The next pallet to process
--                                                          is for a different item
--
--  Exceptions raised:
--      pl_exc.ct_database_error - Got an oracle error
--
--  Called by:
--      - direct_pallets_to_slots
--
--  Modification history:
--      Date        Designer    Comments      
--      ----------- ----------- -----------------------------------------------
--      19-JUN-2018 mpha8134    Created
---------------------------------------------------------------------------
PROCEDURE direct_pallets_to_prod_staging (
    i_r_syspars         IN pl_rcv_open_po_types.t_r_putaway_syspars,
    io_r_item_info      IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info,
    io_r_pallet_table   IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
    io_pallet_index     IN OUT PLS_INTEGER,
    o_status            IN OUT PLS_INTEGER)
IS
    l_message VARCHAR2(256);    -- Message buffer
    l_object_name VARCHAR2(30) := 'direct_pallets_to_prod_staging';

    l_previous_prod_id pm.prod_id%TYPE; -- First item to be processed. Used to 
                                        -- check when next pallet is for a diff item or uom
    
    l_previous_cust_pref_vendor pm.cust_pref_vendor%TYPE;   -- The first cpv processed.begin
                                                            -- Used to check when next pal is for
                                                            -- a different item or uom

    l_previous_uom erd.uom%TYPE;    -- First UOM process. Used to check when the next
                                    -- pallet is for a different item or uom
    l_previous_cust_id erd.cust_id%TYPE;
    l_previous_order_id erd.order_id%TYPE;
    l_num_pallets PLS_INTEGER; -- Number of pallets sent to staging location

    l_original_pallet_index PLS_INTEGER;    -- Used to save initial value of io_pallet_index. It is
                                            -- used in an aplog message
BEGIN
    
    -- Initialization
    l_previous_prod_id := io_r_pallet_table(io_pallet_index).prod_id;
    l_previous_cust_pref_vendor := io_r_pallet_table(io_pallet_index).cust_pref_vendor;
    l_previous_uom := io_r_pallet_table(io_pallet_index).uom;
    l_previous_cust_id := io_r_pallet_table(io_pallet_index).cust_id;
    l_previous_order_id := io_r_pallet_table(io_pallet_index).order_id;
    l_original_pallet_index := io_pallet_index;
    l_num_pallets := 0;
    o_status := pl_rcv_open_po_types.ct_same_item;

    log_pallet_message ( 
        pl_log.ct_info_msg,
        l_object_name,
        io_r_item_info,
        io_r_pallet_table(io_pallet_index),
        'Starting procedure. Status:' || o_status);

    WHILE(o_status = pl_rcv_open_po_types.ct_same_item) LOOP
        insert_records(io_r_item_info, io_r_pallet_table(io_pallet_index));

        -- See if last pallet was processed
        IF (io_pallet_index = io_r_pallet_table.LAST) THEN
            
            o_status := pl_rcv_open_po_types.ct_no_pallets_left;

        ELSE
            -- Advance to the next pallet
            io_pallet_index := io_r_pallet_table.NEXT(io_pallet_index);

            IF (l_previous_prod_id != io_r_pallet_table(io_pallet_index).prod_id OR
                l_previous_cust_pref_vendor != io_r_pallet_table(io_pallet_index).cust_pref_vendor OR
                l_previous_uom != io_r_pallet_table(io_pallet_index).uom OR
                l_previous_cust_id != io_r_pallet_table(io_pallet_index).cust_id OR
                l_previous_order_id != io_r_pallet_table(io_pallet_index).order_id OR
                io_r_pallet_table(io_pallet_index).direct_to_prod_staging_loc = FALSE) THEN
                
                o_status := pl_rcv_open_po_types.ct_new_item;
            ELSE
                -- The next pallet is for the same item
                NULL;
            END IF;
        END IF;

    END LOOP;

EXCEPTION
    WHEN OTHERS THEN
        l_message := 
            l_object_name ||
            ' LP[' || io_r_pallet_table(io_pallet_index).pallet_id || ']' ||
            ' Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']' ||
            ' CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor|| ']' ||
            ' PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

            pl_log.ins_msg (
                pl_lmc.ct_fatal_msg,
                l_object_name,
                l_message,
                SQLCODE,
                SQLERRM,
                pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name
            );

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);

END direct_pallets_to_prod_staging;


---------------------------------------------------------------------------
-- Procedure:
--    direct_pallets_to_rsrv_float
--
-- Description:
--    This procedure directs pallets for an item to reserve slots or
--    floating slots based on the items primary put zone and the
--    next zones.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    io_r_item_info       - Item information record.
--    io_r_pallet_table    - Table of pallet records to find slots for.
--    io_pallet_index      - The index of the pallet to process.
--                           This will be incremented by the number of pallets
--                           assigned to the slots.
--    o_status             - Status of finding slots for the item.  The value
--                           will be one of the following:
--                             - ct_no_pallets_left - All the pallets have been
--                                                    processed for the item.
--                             - ct_new_item        - The next pallet to process
--                                                    is for a different item.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - direct_pallets_to_slots
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_pallets_to_rsrv_float
    (i_r_syspars           IN     pl_rcv_open_po_types.t_r_putaway_syspars,
     io_r_item_info        IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info,
     io_r_pallet_table     IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     io_pallet_index       IN OUT PLS_INTEGER,
     o_status                 OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_pallets_to_rsrv_float';

   l_buf                VARCHAR2(20);      -- Work area

   l_num_next_zones_processed PLS_INTEGER; -- Running count of the next
                                           -- zones processed.

   r_zone   gl_c_zones%ROWTYPE;     -- Putaway zone to process.

BEGIN

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
      'Start of looking for slots in reserve/floating.'
      || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
      || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor || ']'
      || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
      || '  Item put zone[' || io_r_item_info.zone_id || ']'
      || '  Primary put zone[' || io_r_item_info.primary_put_zone_id || ']',
      NULL, NULL,
      pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

   --
   -- Initialization
   --
   l_num_next_zones_processed := 0;
   o_status := pl_rcv_open_po_types.ct_same_item;

   --
   -- Before startng directing pallets to reserve/floating slots move
   -- the partial pallet, if there is one to process, to the end of the
   -- pallet list for the item.  Partial pallets need to be processed
   -- last for the item.  Right now the partial pallet is at the beginning.
   --
   -- If this is an internal production PO, we don't need to move 
   -- the partial pallet to the end of the palletlist.
   --
   IF pl_common.f_is_internal_production_po(io_r_pallet_table(io_pallet_index).erm_id) = TRUE THEN
      null; -- don't move partial to end of list
   ELSE
      move_partial_to_end_of_list(io_r_pallet_table, io_pallet_index);
   END IF;

   --
   -- Direct pallets to reserve slots in the primary put zone then the
   -- next zones.
   --
   OPEN gl_c_zones(io_r_item_info.primary_put_zone_id);

   <<put_zone_loop>>
   LOOP
      --
      -- Leave the zone loop if all the pallets for the item have been
      -- processed.
      --
      EXIT put_zone_loop WHEN o_status != pl_rcv_open_po_types.ct_same_item;

      FETCH gl_c_zones INTO r_zone;
      EXIT put_zone_loop WHEN gl_c_zones%NOTFOUND;

      -- Text used in an aplog message.
      IF (r_zone.what_zone = 'P') THEN
         l_buf := 'primary';
      ELSE
         l_buf := 'next';
      END IF;

dbms_output.put_line('Searching for slots in ' || l_buf
         || ' zone ' || r_zone.zone_id || '.'
         || '  Rule ID[' || TO_CHAR(r_zone.rule_id) || ']'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']');

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Searching for slots in ' || l_buf
         || ' zone ' || r_zone.zone_id || '.'
         || '  Rule ID[' || TO_CHAR(r_zone.rule_id) || ']'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      --
      -- Keep track of the number of next zones processed.
      --
      IF (r_zone.what_zone = 'N') THEN
         l_num_next_zones_processed := l_num_next_zones_processed + 1;
      END IF;

      --
      -- Stop looking for locations in the next zones when the maximum number
      -- of next zones to look at has been reached.
      --
      IF (l_num_next_zones_processed > io_r_item_info.num_next_zones) THEN
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
            || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
            || ']'
            || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
            || '  Reached the maximum number of next zones, '
            || TO_CHAR(io_r_item_info.num_next_zones) || ', to check.',
            NULL, NULL,
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
         EXIT put_zone_loop;
      END IF;

      IF (r_zone.rule_id = 0) THEN
         --
         -- General rule zone.
         --
         -- The item should have a home slot.  If for some reason a floating
         -- item has rule 0 zone then the non-deep logic is followed.
         -- For floating items procedure
         -- pl_rcv_open_po_pallet_list.get_item_info() sets home_slot_deep_ind
         -- to 'N'.
         --
         IF (io_r_item_info.case_home_slot_deep_ind = 'N') THEN
            --
            -- Non-deep home slot.  Direct pallets to non-deep slots.
            --
            direct_to_non_deep_slots(i_r_syspars,
                                     io_r_item_info,
                                     r_zone,
                                     io_r_pallet_table,
                                     io_pallet_index,
                                     o_status);
         ELSE
            --
            -- Deep home slot.  Direct pallets to deep slots.
            --
            direct_to_deep_slots(i_r_syspars,
                                 io_r_item_info,
                                 r_zone,
                                 io_r_pallet_table,
                                 io_pallet_index,
                                 o_status);
         END IF;
      ELSIF (r_zone.rule_id = 1 ) THEN
         --
         -- Floating zone.
         --
         direct_to_floating_slots(i_r_syspars,
                                  io_r_item_info,
                                  r_zone,
                                  io_r_pallet_table,
                                  io_pallet_index,
                                  o_status);
      ELSIF (r_zone.rule_id = 2 ) THEN
         --
         -- Bulk rule zone.
         --
         direct_to_bulk_rule_zone(i_r_syspars,
                                  io_r_item_info,
                                  r_zone,
                                  io_r_pallet_table,
                                  io_pallet_index,
                                  o_status);
      ELSIF (r_zone.rule_id = 4 ) THEN
	--
	-- Cross Dock pallet Zone
	--	

         direct_to_floating_slots(i_r_syspars,
                                  io_r_item_info,
                                  r_zone,
                                  io_r_pallet_table,
                                  io_pallet_index,
                                  o_status);
         direct_to_bulk_rule_zone(i_r_syspars,
                                  io_r_item_info,
                                  r_zone,
                                  io_r_pallet_table,
                                  io_pallet_index,
                                  o_status);
      ELSE
         --
         -- r_zone.rule_id has an unhandled value.
         -- The zone will be ignored.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
            'Unhandled value for the rule ID.  This zone will be ignored.'
            || '  Zone[' || r_zone.zone_id || ']'
            || '  Rule ID[' || TO_CHAR(r_zone.rule_id) || ']'
            || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
            || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
            || ']'
            || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
            || '  Type[' || io_r_pallet_table(io_pallet_index).erm_type || ']',
            pl_exc.ct_data_error, NULL,
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      END IF;

   END LOOP put_zone_loop;

   CLOSE gl_c_zones;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']'
       || 'Leaving procedure.'
       || '  o_status[' || TO_CHAR(o_status) || '].',
       NULL, NULL,
       pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
     IF gl_c_zones%ISOPEN THEN
	CLOSE gl_c_zones;
     END IF; 
      l_message := l_object_name
         || '(i_r_syspars,io_r_item_info,io_r_pallet_table,io_pallet_index'
         || 'o_status)'
         || '  Item[' || io_r_pallet_table(io_pallet_index).prod_id || ']'
         || '  CPV[' || io_r_pallet_table(io_pallet_index).cust_pref_vendor
         || ']'
         || '  PO/SN[' || io_r_pallet_table(io_pallet_index).erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_pallets_to_rsrv_float;




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
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/20/04 prpbcb   Created.
--
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
      l_object_name := 'f_boolean_text';
      l_message := l_object_name || '(i_boolean)';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_boolean_text;

---------------------------------------------------------------------------
-- Procedure:
--    direct_pallets_to_slots
--
-- Description:
--    This procedure assigns slots to the putaway pallets.
--
--    Different procedures are called to:
--       - Assign pallets to home slots.
--       - Assign pallets to reserve slots.
--       - Assign pallets to floating slots.
--
--    Finding a slot consists of:
--       - Find a suitable location for the pallet.
--       - Creating a PUTAWAYLST record.
--       - If a suitable slot was found:
--            - Creating an INV record if it is a reserve or floating location.
--            - Updating the INV record if it is a home slot.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_erm_id             - PO/SN.  Used in aplog messages.
--    i_r_item_info_table  - Table of item information records.  The pallet
--                           list (i_r_pallet_table) has a field that has the
--                           index of the item in i_r_item_info_table.
--    i_r_pallet_table     - Table of pallet records to find a slot for.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - find_slot
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE direct_pallets_to_slots
  (i_r_syspars          IN     pl_rcv_open_po_types.t_r_putaway_syspars,
   i_erm_id             IN     erm.erm_id%TYPE,
   io_r_item_info_table IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
   io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'direct_pallets_to_slots';

   l_done_bln           BOOLEAN;      -- Flag when processing is done.
   l_item_index         PLS_INTEGER;  -- Index into the item info table.
   l_pallet_index       PLS_INTEGER;  -- Keeps track of the pallet being
                                      -- processed.

   l_status             PLS_INTEGER;  -- Designates what to process next.
   l_split_home_cnt     NUMBER;
BEGIN
   --
   -- Initialization.
   --
   l_done_bln := FALSE;

   --
   -- Check if the pallet list is empty.  There should be at least one record.
   --
   IF (io_r_pallet_table.COUNT = 0) THEN
      l_done_bln := TRUE;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Number of pallets in list['
         || TO_CHAR(io_r_pallet_table.COUNT) || '].'
         || '  Number of different items['
         || TO_CHAR(io_r_item_info_table.COUNT) || '].'
         || '  PO/SN[' || i_erm_id || ']'
         || '  There are no pallets to process.',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   END IF;

   --
   -- Check if the item list is empty.  There should be at least one record.
   --
   IF (io_r_item_info_table.COUNT = 0) THEN
      l_done_bln := TRUE;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Number of pallets in list['
         || TO_CHAR(io_r_pallet_table.COUNT) || '].'
         || '  Number of different items['
         || TO_CHAR(io_r_item_info_table.COUNT) || '].'
         || '  PO/SN[' || i_erm_id || ']'
         || '  There are no items in the item list.',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   END IF;

   --
   -- Prepare to process the pallets if there is something to process.
   --
   IF (l_done_bln = FALSE) THEN
      l_pallet_index :=io_r_pallet_table.FIRST;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
         'Start of assigning pallets to slots.  Non-MSKU pallets.'
         || '  PO/SN[' || i_erm_id || ']'
         || '  Number of pallets in list['
         || TO_CHAR(io_r_pallet_table.COUNT) || '].'
         || '  Number of different items['
         || TO_CHAR(io_r_item_info_table.COUNT) || '].',
         NULL, NULL,
         pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   END IF;

   --
   -- Loop through the pallets in the pallet list directing the pallets to
   -- slots.
   -- The pallet list needs to be in uom, prod id, ... order.
   --
   WHILE (NOT l_done_bln) LOOP

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
           'Current LP:  l_pallet_index[' || TO_CHAR(l_pallet_index)
           || ']'
           || '  pallet_id[' || io_r_pallet_table(l_pallet_index).pallet_id
           || ']'
           || '  prod_id[' || io_r_pallet_table(l_pallet_index).prod_id || ']'
           || '  io_r_pallet_table(l_pallet_index).item_index['
           || TO_CHAR(io_r_pallet_table(l_pallet_index).item_index) || ']'
           || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id || ']',
           NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      --
      -- Assign values to local variables for easier reading.
      --
      l_item_index := io_r_pallet_table(l_pallet_index).item_index;

       pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
           'Current LP 2:  l_pallet_index[' || TO_CHAR(l_pallet_index)
           || ']'
           || '  pallet_id[' || io_r_pallet_table(l_pallet_index).pallet_id
           || ']'
           || '  prod_id[' || io_r_pallet_table(l_pallet_index).prod_id || ']'
           || '  io_r_pallet_table(l_pallet_index).item_index['
           || TO_CHAR(io_r_pallet_table(l_pallet_index).item_index) || ']'
           || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id || ']'
           || '  mx_item_assign_flag[' || io_r_item_info_table(l_item_index).mx_item_assign_flag || ']'
           || '  matrix_reserve[' || f_boolean_text(io_r_pallet_table(l_pallet_index).matrix_reserve) || ']'
           || '  uom[' || io_r_pallet_table(l_pallet_index).uom || ']' 
           || '  go to cust staging[' || f_boolean_text(io_r_pallet_table(l_pallet_index).direct_to_prod_staging_loc) || ']',
           NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
      
      --
      -- direct_to_prod_staging_loc set in pl_rcv_open_pallet_list.build_pallet_list_from_prod_po
      --
      IF io_r_pallet_table(l_pallet_index).direct_to_prod_staging_loc = TRUE THEN
          
          direct_pallets_to_prod_staging(
              i_r_syspars,
              io_r_item_info_table(l_item_index),
              io_r_pallet_table,
              l_pallet_index,
              l_status);

          IF l_status = pl_rcv_open_po_types.ct_no_pallets_left THEN
              l_done_bln := TRUE;
          END IF;
          
          CONTINUE;
            
      ELSIF   (io_r_item_info_table(l_item_index).mx_item_assign_flag  = 'Y')
           and io_r_pallet_table(l_pallet_index).matrix_reserve = FALSE THEN
            
               pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
           'Current LP 3:  l_pallet_index[' || TO_CHAR(l_pallet_index)
           || ']'
           || '  pallet_id[' || io_r_pallet_table(l_pallet_index).pallet_id
           || ']'
           || '  prod_id[' || io_r_pallet_table(l_pallet_index).prod_id || ']'
           || '  io_r_pallet_table(l_pallet_index).item_index['
           || TO_CHAR(io_r_pallet_table(l_pallet_index).item_index) || ']'
           || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id || ']'
           || '  mx_item_assign_flag[' || io_r_item_info_table(l_item_index).mx_item_assign_flag || ']'
           || '  matrix_reserve[' || f_boolean_text(io_r_pallet_table(l_pallet_index).matrix_reserve) || ']'
           || '  uom[' || io_r_pallet_table(l_pallet_index).uom || ']',
           NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
           IF io_r_pallet_table(l_pallet_index).uom != 1  THEN               --Fix DF 11969 by Abhishek
               dbms_output.put_line('pallet_index:'||to_char(l_pallet_index)||'  pl_rcv_open_po_matrix.direct_to_induction_location');
                pl_rcv_open_po_matrix.direct_to_induction_location
                                     (i_r_syspars,
                                      io_r_item_info_table(l_item_index),
                                      io_r_pallet_table,
                                      l_pallet_index,
                                      l_status);

              IF (l_status = pl_rcv_open_po_types.ct_no_pallets_left) THEN
                 l_done_bln := TRUE;
              END IF;
              
              CONTINUE;      
           ELSE
                 SELECT COUNT(*)
                   INTO l_split_home_cnt
                   FROM Loc L
                  WHERE l.prod_id          = io_r_pallet_table(l_pallet_index).prod_id 
                    AND l.cust_pref_vendor = io_r_pallet_table(l_pallet_index).cust_pref_vendor
                    AND l.perm             = 'Y'
                    AND l.uom              IN (0, 1);
                
                 IF l_split_home_cnt > 0 THEN
                    io_r_item_info_table(l_item_index).has_home_slot_bln := TRUE;
                 ELSE
                    io_r_item_info_table(l_item_index).has_home_slot_bln := FALSE;
                 END IF;    
           END IF;
      END IF;      
      
      IF (   (io_r_item_info_table(l_item_index).miniload_storage_ind = 'B'
      	      AND NOT io_r_pallet_table(l_pallet_index).miniload_reserve)
          OR (    io_r_item_info_table(l_item_index).miniload_storage_ind = 'S'
              AND io_r_pallet_table(l_pallet_index).uom = 1) ) THEN
         --
         -- The item has cases and splits (if splittable) going to the
         -- miniloader or receiving splits and the splits go to the miniloader.
         -- Direct the pallets to the induction location.
         --

        dbms_output.put_line('pallet_index:'||to_char(l_pallet_index)||'  pl_rcv_open_po_ml.direct_to_induction_location');
         pl_rcv_open_po_ml.direct_to_induction_location
                             (i_r_syspars,
                              io_r_item_info_table(l_item_index),
                              io_r_pallet_table,
                              l_pallet_index,
                              l_status);
      ELSIF (io_r_item_info_table(l_item_index).has_home_slot_bln) THEN
         --
         -- The item has a home slot.  Attempt to direct pallets to the
         -- case home slot.
         --
         -- If receiving splits then always direct the splits to the split
         -- home regardless of FIFO, if they fit, etc. except if it is
         -- an aging item.
         --
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
           'Item[' || io_r_pallet_table(l_pallet_index).prod_id || ']'
           || '  CPV[' || io_r_pallet_table(l_pallet_index).cust_pref_vendor
           || ']'
           || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id || ']'
           || '  Item has a home slot.',
           NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

         IF (   io_r_pallet_table(l_pallet_index).uom != 1
             OR io_r_item_info_table(l_item_index).aging_item = 'Y') THEN
            --
            -- Receiving cases or receiving cases or splits for an aging item.
            --

            dbms_output.put_line('pallet_index:'||to_char(l_pallet_index)||'  direct_pallets_to_home_slot');
            direct_pallets_to_home_slot(i_r_syspars,
                                        io_r_item_info_table,
                                        io_r_pallet_table,
                                        l_pallet_index,
                                        l_status);

            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
               'PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id || ']'
               || '  After call to direct_pallets_to_home_slot'
               || '  l_status[' || l_status || ']', NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            --
            -- If there are still more pallets for the item then assign them to
            -- reserve slots which will be by primary put zone then next zones.
            --
            IF (l_status = pl_rcv_open_po_types.ct_check_reserve) THEN
               --
               -- None or not all the pallets went to the home slot.  Direct
               -- the pallets to reserve slots.
               --

               dbms_output.put_line('pallet_index:'||to_char(l_pallet_index)||'  direct_pallets_to_rsrv_float');
               direct_pallets_to_rsrv_float(i_r_syspars,
                                            io_r_item_info_table(l_item_index),
                                            io_r_pallet_table,
                                            l_pallet_index,
                                            l_status);

               --
               -- If there are still pallets of the item to find slots for
               -- then * the pallets.
               --
               IF (l_status = pl_rcv_open_po_types.ct_same_item) THEN
                  no_slot_found(i_r_syspars,
                                io_r_item_info_table(l_item_index),
                                io_r_pallet_table,
                                l_pallet_index,
                                l_status);
               END IF;

            ELSIF (l_status = pl_rcv_open_po_types.ct_new_item) THEN
               --
               -- The assignment to the home slot encountered a new item which
               -- means all the pallets for the item went to the home slot.
               -- Start processing for this new item.
               --
               NULL;
            END IF;
         ELSE
            --
            -- The item has a home slot and receiving splits and it is not
            -- an aging item.  Direct the splits to the split home regardless
            -- of FIFO, if they fit, etc.
            --

dbms_output.put_line('pallet_index:'||to_char(l_pallet_index)||'  direct_pallets_to_split_home');
            direct_pallets_to_split_home(i_r_syspars,
                                         io_r_item_info_table,
                                         io_r_pallet_table,
                                         l_pallet_index,
                                         l_status);
         END IF;
      ELSE
         --
         -- Floating item.
         --
         -- The item does not have a home slot therefore it is a floating item.
         --
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
            'Item[' || io_r_pallet_table(l_pallet_index).prod_id || ']'
            || '  CPV[' || io_r_pallet_table(l_pallet_index).cust_pref_vendor
            || ']'
            || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id || ']'
            || '  Floating item.',
            NULL, NULL,
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

         --
         -- Only look for slots if the items primary put zone rule id is 1.
         -- If not 1 then the pallets will "*".
         -- The rule id at this point should be 1.  Anything else means there
         -- is a data issue.  Miniloader items have already been processed
         -- so this point should not be reached if the rule id is 3.
         --

         IF (io_r_item_info_table(l_item_index).rule_id = 1 OR io_r_item_info_table(l_item_index).rule_id = 5 OR
               io_r_pallet_table(l_pallet_index).miniload_reserve OR io_r_pallet_table(l_pallet_index).matrix_reserve = TRUE) THEN
            --
            -- The items primary put zone rule id is for a floating zone.
            -- Find slots.
            --

            dbms_output.put_line('pallet_index:'||to_char(l_pallet_index)||'  direct_pallets_to_rsrv_float');
            direct_pallets_to_rsrv_float(i_r_syspars,
                                         io_r_item_info_table(l_item_index),
                                         io_r_pallet_table,
                                         l_pallet_index,
                                         l_status);
         ELSE
            --
            -- The items primary put zone rule id is not for a floating zone.
            -- The pallets will '*'.
            --
            l_status := pl_rcv_open_po_types.ct_same_item;  -- Need to do this
                                       -- since procedure
                                       -- direct_pallets_to_rsrv_float() was
                                       -- not called.
            pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
               'Item[' || io_r_pallet_table(l_pallet_index).prod_id || ']'
               || '  CPV[' || io_r_pallet_table(l_pallet_index).cust_pref_vendor
               || ']'
               || '  Item zone[' || io_r_item_info_table(l_item_index).zone_id
               || ']'
               || '  Rule ID['
               || TO_CHAR(io_r_item_info_table(l_item_index).rule_id) || ']'
               || '  PO/SN[' || io_r_pallet_table(l_pallet_index).erm_id || ']'
               || '  This is a floating item but the zone id for the item'
               || ' is not a rule 1 zone.  The pallets will "*".',
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
         END IF;

         --
         -- If there are still pallets of the item to find slots for
         -- then * the pallets.
         --
         IF (l_status = pl_rcv_open_po_types.ct_same_item) THEN
            no_slot_found(i_r_syspars,
                          io_r_item_info_table(l_item_index),
                          io_r_pallet_table,
                          l_pallet_index,
                          l_status);
         END IF;
      END IF;

      IF (l_status = pl_rcv_open_po_types.ct_no_pallets_left) THEN
         l_done_bln := TRUE;
      END IF;

   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,i_erm_id,io_r_item_info_table,io_r_pallet_table)'
         || '  PO/SN[' || i_erm_id || ']'
         || '  Number of pallets in list['
         || TO_CHAR(io_r_pallet_table.COUNT) || '].'
         || '  Number of different items['
         || TO_CHAR(io_r_item_info_table.COUNT) || '].';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
END direct_pallets_to_slots;


---------------------------------------------------------------------------
--  Procedure:
--      insert_put_trans (Private)
--
--  Description:
--      This procedure was created for the Meat Company changes. It inserts
--      the PUT transaction into the TRANS table. The columns for the INSERT
--      statement was taken from putaway.pc
--
--
--
--  Parameters:
--      i_r_item_info   - Record of details about the item on the pallet
--      io_r_pallet     - Pallet record to insert
--
--  Called by:
--      insert_putawaylst
--
--  Modification History:
--      Date        Designer    Comments
--      --------    --------    -------------------------------------------
--      07/05/18    mpha8134    Initial version
---------------------------------------------------------------------------
PROCEDURE insert_put_trans (
    i_r_item_info   IN              pl_rcv_open_po_types.t_r_item_info,
    io_r_pallet     IN OUT NOCOPY   pl_rcv_open_po_types.t_r_pallet)
IS
    l_message       VARCHAR2(512); -- Message buffer
    l_object_name   VARCHAR2(30) := 'insert_put_trans';

    l_warehouse_id  erm.to_warehouse_id%TYPE;
    l_door_no erm.door_no%TYPE;
    l_seq_no putawaylst.seq_no%TYPE;
    l_pallet_batch_no putawaylst.pallet_batch_no%TYPE;

BEGIN
    --
    -- Get PUT trans information
    --
    SELECT to_warehouse_id, door_no
    INTO l_warehouse_id, l_door_no
    FROM erm
    WHERE erm_id = io_r_pallet.erm_id;

    SELECT pallet_batch_no
    INTO l_pallet_batch_no
    FROM putawaylst
    WHERE rec_id = io_r_pallet.erm_id
        AND pallet_id = io_r_pallet.pallet_id;


    
    INSERT INTO trans (
        trans_id,
        trans_type,
        prod_id,
        cust_pref_vendor,
        uom,
        rec_id,
        lot_id,
        exp_date,
        weight,
        mfg_date,
        qty_expected,
        temp,
        qty,
        pallet_id,
        src_loc,
        dest_loc,
        trans_date,
        user_id,
        order_id,
        order_line_id,
        upload_time,
        batch_no,
        reason_code,
        new_status,
        cmt,
        warehouse_id,
        bck_dest_loc,
        parent_pallet_id,
        labor_batch_no,
        scan_method2)
    VALUES (
        trans_id_seq.NEXTVAL,
        'PUT',
        io_r_pallet.prod_id,
        io_r_pallet.cust_pref_vendor,
        io_r_pallet.uom,
        io_r_pallet.erm_id,
        io_r_pallet.lot_id,
        io_r_pallet.exp_date,
        io_r_pallet.catch_weight,
        io_r_pallet.mfg_date,
        io_r_pallet.qty_expected,
        null,
        io_r_pallet.qty,
        io_r_pallet.pallet_id,
        l_door_no, -- door no. from erm 
        io_r_pallet.dest_loc,
        sysdate,
        'SWMS',
        io_r_pallet.lot_id,
        io_r_pallet.seq_no,
        to_date('01-JAN-1980', 'FXDD-MON-YYYY'),
        55,
        null,
        'AVL',
        io_r_pallet.pallet_id,
        l_warehouse_id,
        io_r_pallet.dest_loc,
        io_r_pallet.parent_pallet_id,
        l_pallet_batch_no,
        null);
    
EXCEPTION
    WHEN OTHERS THEN
        --
        -- The insert into TRANS table failed for some reason.  Log
        -- a message and propagate the exception.
        --
        l_message := 
            l_object_name || '  TABLE=trans'
            || '  LP['     || io_r_pallet.pallet_id        || ']'
            || '  DEST_LOC[' || io_r_pallet.dest_loc       || ']'
            || '  Item['   || io_r_pallet.prod_id          || ']'
            || '  CPV['    || io_r_pallet.cust_pref_vendor || ']'
            || '  PO/SN['  || io_r_pallet.erm_id           || ']'
            || '  ACTION=INSERT  MESSAGE="Insert record failed."';

        pl_log.ins_msg(
            pl_log.ct_fatal_msg, 
            l_object_name, 
            l_message,
            SQLCODE, 
            SQLERRM,
            pl_rcv_open_po_types.ct_application_function,
            gl_pkg_name);

      RAISE;  -- Propagate the exception
END insert_put_trans;

---------------------------------------------------------------------------
-- Procedure:
--    insert_putawaylst (Private)
--
-- Description:
--    This procedure inserts the pallet into the PUTAWYLST table.
--
-- Parameters:
--    i_r_item_info  - Record of details about the item on the pallet.
--    io_r_pallet    - pallet record to insert.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - insert_records
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/21/16 bben0556 Brian Bent
--                      Moved the insert into the PUTAWAYLST table from
--                      the "insert_records" procedure to here.
--    Jira 2628 vkal9662 make auto confirm PO configurable at rule level 
---------------------------------------------------------------------------
PROCEDURE insert_putawaylst
            (i_r_item_info  IN            pl_rcv_open_po_types.t_r_item_info,
             io_r_pallet    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet)
IS
   l_message        VARCHAR2(512);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'insert_putawaylst';

   l_collect_clam_bed  putawaylst.clam_bed_trk%TYPE;  -- Designates if the clam
                                                      -- bed needs to be collected.
   l_ato_conf_cnt number :=0 ;
   
BEGIN
   --
   -- Check if the clam bed has already been captured.
   --
   BEGIN
      SELECT 'C'
        INTO l_collect_clam_bed
        FROM trans
       WHERE trans_type       = 'RHB'
         AND prod_id          = io_r_pallet.prod_id
         AND cust_pref_vendor = io_r_pallet.cust_pref_vendor
         AND rec_id           = io_r_pallet.erm_id
         AND ROWNUM           = 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_collect_clam_bed := io_r_pallet.collect_clam_bed;
   END;

   IF pl_common.f_is_internal_production_po(io_r_pallet.erm_id) THEN
   
       IF io_r_pallet.dest_loc in ('*', pl_rcv_open_po_types.ct_lr_dest_loc) THEN
       
          io_r_pallet.auto_confirm_put := 'N';
          
       ELSE
          --Jira 2628 vkal9662
          select count(*) into l_ato_conf_cnt
          from zone a, lzone b, rules c
          where a.RULE_ID =c.RULE_ID
          and b.ZONE_ID = a.ZONE_ID
          and a.ZONE_TYPE = 'PUT'
          and nvl(c.AUTO_CONFRM, 'N') ='Y'
          and b.LOGI_LOC =io_r_pallet.dest_loc;
          
          If l_ato_conf_cnt >0 then
             io_r_pallet.auto_confirm_put := 'Y';
          Else
             io_r_pallet.auto_confirm_put := 'N';
          End If;  
          
       END IF;
   END IF;

   INSERT INTO putawaylst
                     (rec_id,
                      prod_id,
                      cust_pref_vendor,
                      dest_loc,
                      qty,
                      uom,
                      status,
                      inv_status,
                      pallet_id,
                      qty_expected,
                      qty_received,
                      temp_trk,
                      catch_wt,
                      lot_trk,
                      exp_date_trk,
                      date_code,
                      equip_id,
                      rec_lane_id,
                      seq_no,
                      putaway_put,
                      exp_date,
                      clam_bed_trk,
                      lot_id,
                      weight,
                      mfg_date,
                      sn_no,
                      po_no,
                      erm_line_id,
                      po_line_id,
                      tti_trk,
                      cool_trk,
                      from_splitting_sn_pallet_flag,
                      door_no,
                      parent_pallet_id,
                      demand_flag)
   VALUES
                     (io_r_pallet.erm_id,            -- rec_id
                      io_r_pallet.prod_id,           -- prod_id
                      io_r_pallet.cust_pref_vendor,  -- cust_pref_vendor
                      io_r_pallet.dest_loc,          -- dest_loc
                      io_r_pallet.qty,               -- qty
                      io_r_pallet.uom,               -- uom
                      'NEW',                      -- status
                      DECODE(i_r_item_info.aging_item,
                             'Y', 'HLD', 'AVL'),     -- inv_status
                      io_r_pallet.pallet_id,         -- pallet_id
                      io_r_pallet.qty_expected,      -- qty_expected
                      io_r_pallet.qty_received,      -- qty_received
                      io_r_pallet.collect_temp,      -- temp_trk
                      io_r_pallet.collect_catch_wt,  -- catch_wt
                      io_r_pallet.collect_lot_id,    -- lot_trk
                      io_r_pallet.collect_exp_date,  -- exp_date_trk
                      io_r_pallet.collect_mfg_date,  -- exp_date_trk
                      ' ',                           -- equip_id, mandatory
                      ' ',                           -- rec_lane_id, mandatory
                      io_r_pallet.seq_no,            -- seq_no
                      NVL(io_r_pallet.auto_confirm_put, 'N'), --'N',   -- putaway_put, Jira 438: Use auto_confirm_put flag 
                                                            -- It will default to N unless PO was auto opened
                      io_r_pallet.exp_date,          -- exp_date
                      l_collect_clam_bed,            -- clam_bed_trk
                      io_r_pallet.lot_id,            -- lot_id
                      io_r_pallet.catch_weight,      -- weight
                      io_r_pallet.mfg_date,          -- mfg_date. Default is NULL. Only populates a value for auto confirm put/inv
                      io_r_pallet.sn_no,             -- sn_no
                      io_r_pallet.po_no,             -- po_no
                      io_r_pallet.erm_line_id,       -- erm_line_id
                      io_r_pallet.po_line_id,        -- po_line_id
                      io_r_pallet.collect_tti,       -- tti_trk
                      io_r_pallet.collect_cool,      -- cool_trk
                      io_r_pallet.from_splitting_sn_pallet_flag,
                      -- Story 3840 (kchi7065) Added door number column
                      io_r_pallet.door_no,           -- door_no
                      io_r_pallet.parent_pallet_id,  -- parent_palled_id added for Meat company changes Jira 438
                      io_r_pallet.demand_flag); 

    --
    -- Log the insert of the putaway task.
    --
    log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              io_r_pallet,
              'Putaway task created successfully.');

    -- If we are auto confirming put/inv then we need to create the PUT trans.
    -- Only create PUT if a location was found
    IF io_r_pallet.auto_confirm_put = 'Y' and io_r_pallet.dest_loc not in ('*', 'LR') THEN
        insert_put_trans(i_r_item_info, io_r_pallet);
    END IF;

EXCEPTION
   WHEN OTHERS THEN
      --
      -- The insert into PUTAWAYLST table failed for some reason.  Log
      -- a message and propagate the exception.
      --
      l_message := l_object_name || '  TABLE=putawaylst'
                  || '  LP['     || io_r_pallet.dest_loc         || ']'
                  || '  Item['   || io_r_pallet.prod_id          || ']'
                  || '  CPV['    || io_r_pallet.cust_pref_vendor || ']'
                  || '  PO/SN['  || io_r_pallet.erm_id           || ']'
                  || '  ACTION=INSERT  MESSAGE="Insert record failed."';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE;  -- Propagate the exception
END insert_putawaylst;


---------------------------------------------------------------------------
-- Procedure:
--    update_putawaylst (Private)
--
-- Description:
--    Live Receiving
--    This procedure updates the PUTAWYLST table with the dest loc.
--
-- Parameters:
--    i_r_item_info  - Record of details about the item on the pallet. 
--                     For log messages.
--    i_r_pallet     - Pallet record to insert.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - insert_records
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/21/16 bben0556 Brian Bent
--                      Live Receiving
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE update_putawaylst
              (i_r_item_info  IN  pl_rcv_open_po_types.t_r_item_info,
               i_r_pallet     IN  pl_rcv_open_po_types.t_r_pallet)
IS

   l_message        VARCHAR2(512);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'update_putawaylst';

BEGIN
   --
   -- Normal logic
   --
   IF (pl_common.f_is_internal_production_po(i_r_pallet.erm_id) = FALSE) THEN
      
      UPDATE putawaylst
      SET dest_loc = i_r_pallet.dest_loc
      WHERE pallet_id         = i_r_pallet.pallet_id
         AND prod_id          = i_r_pallet.prod_id           -- Sanity check
         AND cust_pref_vendor = i_r_pallet.cust_pref_vendor; -- Sanity check
   
   -- If a location was found, then "reset" the putaway_put to allow putaway to the main warehouse.
   ELSIF (pl_common.f_is_internal_production_po(i_r_pallet.erm_id) = TRUE AND
         i_r_pallet.dest_loc != '*') THEN

      UPDATE  putawaylst
      SET dest_loc = i_r_pallet.dest_loc,
          putaway_put = 'N'
      WHERE pallet_id         = i_r_pallet.pallet_id
         AND prod_id          = i_r_pallet.prod_id
         AND cust_pref_vendor = i_r_pallet.cust_pref_vendor;

   END IF;

   --
   -- Log the update of the putaway task.
   --
   log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              i_r_pallet,
              'Putaway task destination location updated successfully.');
EXCEPTION
   WHEN OTHERS THEN
      --
      -- The update of the PUTAWAYLST table failed for some reason.  Log
      -- a message and propagate the exception.
      --
      l_message := l_object_name || '  TABLE=putawaylst'
                  || '  LP['       || i_r_pallet.dest_loc         || ']'
                  || '  Item['     || i_r_pallet.prod_id          || ']'
                  || '  CPV['      || i_r_pallet.cust_pref_vendor || ']'
                  || '  Dest Loc[' || i_r_pallet.dest_loc         || ']'
                  || '  PO/SN['    || i_r_pallet.erm_id           || ']'
                  || '  ACTION=UPDATE  MESSAGE="Update of the dest_loc failed."';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE;  -- Propagate the exception
END update_putawaylst;


---------------------------------------------------------------------------
-- End Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

PROCEDURE p_add_fg_demand_lp (
   i_erm_id IN erm.erm_id%TYPE,
   i_prod_id IN pm.prod_id%TYPE,
   i_cust_pref_vendor IN pm.cust_pref_vendor%TYPE,
   i_qty IN inv.qoh%TYPE,
   i_uom IN erd.uom%TYPE,
   i_status IN inv.status%TYPE
)
IS
   l_message         swms_log.msg_text%TYPE;
   l_object_name     VARCHAR2(30) := 'p_add_fg_demand_lp';
   l_pallet          pl_rcv_open_po_types.t_r_pallet;
   l_vendor_id       erm.source_id%TYPE;
   l_item_info_table pl_rcv_open_po_types.t_r_item_info_table;
   l_syspars         pl_rcv_open_po_types.t_r_putaway_syspars;
   l_item_index      PLS_INTEGER := 1;
   l_qty             inv.qoh%TYPE;
   l_ato_conf_cnt number := 0;
BEGIN

   pl_log
      .ins_msg(pl_log.ct_info_msg, l_object_name, 'Starting ' || l_object_name,
         SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,gl_pkg_name);

   IF pl_common.f_is_internal_production_po(i_erm_id) = FALSE THEN
      RETURN;
   END IF;

   -- Retrieve the putaway syspars
   get_putaway_syspars(i_erm_id, TRUE, l_syspars);

   -- Retrieve item info
   pl_rcv_open_po_pallet_list
      .get_item_info(l_syspars, i_prod_id, i_cust_pref_vendor, i_erm_id, l_item_index, l_item_info_table);

   SELECT source_id INTO l_vendor_id
   FROM erm WHERE erm_id = i_erm_id;

   l_qty := i_qty * l_item_info_table(1).spc;

   -- Set up the pallet
   
   
   l_pallet.auto_confirm_put  := 'Y';
   l_pallet.demand_flag       := 'Y';
   l_pallet.pallet_id         := pl_common.f_get_new_pallet_id();
   l_pallet.erm_id            := i_erm_id;
   l_pallet.po_no             := i_erm_id;
   l_pallet.prod_id           := i_prod_id;
   l_pallet.cust_pref_vendor  := i_cust_pref_vendor;
   l_pallet.dest_loc          := pl_rcv_open_po_pallet_list.f_get_pit_location(l_vendor_id);
   l_pallet.qty               := l_qty;
   l_pallet.qty_received      := l_qty;
   l_pallet.qty_expected      := l_qty;
   l_pallet.uom               := i_uom;
   l_pallet.inv_uom           := i_uom;
   l_pallet.seq_no            := 1;
   l_pallet.collect_exp_date  := 'N';
   l_pallet.collect_mfg_date  := 'N';
   l_pallet.collect_lot_id    := 'N';
   l_pallet.collect_catch_wt  := 'N';
   l_pallet.collect_temp      := 'N';
   l_pallet.collect_clam_bed  := 'N';
   l_pallet.collect_tti       := 'N';
   l_pallet.collect_cool      := 'N';
   l_pallet.mfg_date          := trunc(sysdate);
   l_pallet.exp_date          := trunc(sysdate);

   -- Call the insert_records procedure to create INV and PUTAWAYLST records
   insert_records(l_item_info_table(1), l_pallet);

   -- Create the DLP (demand license plate) transaction
   INSERT INTO trans (
      trans_id,               trans_type,       rec_id,
      trans_date,             user_id,          pallet_id,
      qty,                    prod_id,          cust_pref_vendor,
      uom,                    exp_date) 
   VALUES (
      trans_id_seq.NEXTVAL,   'DLP',            l_pallet.erm_id,
      SYSDATE,                USER,             l_pallet.pallet_id,
      l_qty,                  l_pallet.prod_id, l_pallet.cust_pref_vendor,
      l_pallet.uom,           l_pallet.exp_date);

   pl_log
      .ins_msg(pl_log.ct_info_msg, l_object_name, 'Ending ' || l_object_name,
         SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,gl_pkg_name);

EXCEPTION WHEN OTHERS THEN
   l_message := 'Error creating demand license plate for FG PO. Procedure inputs:' ||
      'erm_id:[' || i_erm_id || ']' || 
      'prod_id:[' || i_prod_id || ']' || 
      'cust_pref_vendor:[' || i_cust_pref_vendor || ']' || 
      'qty:[' || i_qty || ']' || 
      'uom:[' || i_uom || ']' || 
      'status:[' || i_status || ']';
      
   pl_log
      .ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
         SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,gl_pkg_name);

   RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);

END p_add_fg_demand_lp;


---------------------------------------------------------------------------
-- Procedure:
--    get_putaway_syspars (public)
--
-- Description:
--    This procedure gets the syspars required for finding a putaway slot
--    for a pallet.
--
-- Parameters:
--    i_erm_id             - PO/SN being processed.  Only used in aplog messages.
--    i_find_slots_bln     - Flags if at the point of finding the putaway
--                           locations.  Added for Live Receiving
--    o_r_syspars          - Record of syspars.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - find_slot
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/05 prpbcb   Created
--    11/29/05 prpbcb   Added:
--                         - partial_minimize_option
--                         - home_itm_rnd_inv_cube_up_to_ti
--                         - home_itm_rnd_plt_cube_up_to_ti
--                         - flt_itm_rnd_inv_cube_up_to_ti
--                         - flt_itm_rnd_plt_cube_up_to_ti
--    02/22/06 prpbcb   Added:
--                         - partial_nondeepslot_search_clr
--                         - partial_nondeepslot_search_frz
--                         - partial_nondeepslot_search_dry
--    06/01/06 prpbcb   Added:
--                         - chk_float_cube_ge_lss_cube.
--    05/05/07 prpbcb   Added:
--                         - chk_reserve_hgt_ge_home_hgt
--                         - chk_float_hgt_ge_lss_hgt.
--                         - floating_slot_sort_order_clr
--                         - floating_slot_sort_order_frz
--                         - floating_slot_sort_order_dry
--    03/17/09 prpbcb   Added:
--                         - split_rdc_sn_pallet
--    09/18/14 vred5319  Modified to add mx_staging_or_induction types
--    09/06/16 bben0556 Brian Bent
--                      Added syspar:
--                         - enable_live_receiving
--
--                      If live receiving is active and we are not at the point
--                      in finding a slot for the LP's then do not select all
--                      the other syspars.
--
--                      Added parameter i_lr_find_slots_bln. 
--
--    03/10/17 bben0556 Brian Bent
--                      Change parameter name "i_lr_find_slots_bln"
--                      to "i_find_slots_bln".
--
--    01/11/22 bben0556 Brian Bent
--                      Added:
--                         - extended_case_cube_cutoff_cube
--
---------------------------------------------------------------------------
PROCEDURE get_putaway_syspars
           (i_erm_id             IN         erm.erm_id%TYPE,
            i_find_slots_bln     IN         BOOLEAN DEFAULT FALSE,
            o_r_syspars          OUT NOCOPY pl_rcv_open_po_types.t_r_putaway_syspars)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'get_putaway_syspars';

BEGIN
   --
   -- Live Receiving
   -- Retrieve the syspars always needed.
   --
   o_r_syspars.enable_live_receiving := pl_common.f_get_syspar('ENABLE_LIVE_RECEIVING', 'N');
   o_r_syspars.clam_bed_tracked :=
                          pl_common.f_get_syspar('CLAM_BED_TRACKED', 'N');

   --
   -- To save execution time do not retrieve the other syspars if
   -- live receiving is active and we are not at the point of finding slots
   -- for the pallet.
   --
   IF (    o_r_syspars.enable_live_receiving = 'Y'
       AND i_find_slots_bln = FALSE)
   THEN
      --
      -- Log a message
      --
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                     'Live Receiving is active and the processing is to open'
                     || ' the PO without finding slots.  Only the putaway task'
                     || ' is created.  It is not necessary to get the'
                     || ' putaway syspars at this time.',
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
   ELSE
      --
      -- Putaway to home slot.
      --
      o_r_syspars.home_putaway := pl_common.f_get_syspar('HOME_PUTAWAY', 'N');

      --
      -- Mix different items in the same deep slot.
      --
      o_r_syspars.mixprod_2d3d_flag :=
                          pl_common.f_get_syspar('MIXPROD_2D3D_FLAG', 'N');

      --
      -- Mix different items in the same bulk rule slot.
      --
      o_r_syspars.mix_prod_bulk_area :=
                          pl_common.f_get_syspar('MIX_PROD_BULK_AREA', 'N');

      --
      -- Mix like items with different receive dates in the same deep slot.
      --
      o_r_syspars.mix_same_prod_deep_slot :=
                       pl_common.f_get_syspar('MIX_SAME_PROD_DEEP_SLOT', 'N');

      --
      -- Pallet type flag.
      -- If Y then look for slots with the same pallet type of the item allowing
      -- for pallet type cross reference.
      -- If N then look for slots with the same slot type of the items rank 1 case
      -- home or if floating the slot type of the last ship slot.
      -- An exception to this is deep slot which ignores the syspar and goes
      -- by the deep ind.
      --
      o_r_syspars.pallet_type_flag :=
                          pl_common.f_get_syspar('PALLET_TYPE_FLAG', 'Y');


      o_r_syspars.putaway_dimension :=
                          pl_common.f_get_syspar('PUTAWAY_DIMENSION', 'C');

      o_r_syspars.non_fifo_combine_plts_in_float :=
                pl_common.f_get_syspar('NON_FIFO_COMBINE_PLTS_IN_FLOAT', 'N');


      o_r_syspars.putaway_to_home_if_fifo_allows :=
                pl_common.f_get_syspar('PUTAWAY_TO_HOME_IF_FIFO_ALLOWS', 'N');

      --
      -- Match deep home slot to deep reserve slots by deep indicator or by
      -- slot type.  If the syspar is Y then match by deep indicator.
      -- If the syspar is N then match by slot type.
      --
      o_r_syspars.putaway_to_any_deep_slot :=
                pl_common.f_get_syspar('PUTAWAY_TO_ANY_DEEP_SLOT', 'Y');


      --
      -- When finding a slot for a partial pallet for an item with a home slot
      -- find the best fit by size (cube or inches--whichever is active) which is
      -- designed with a 'S' or find the slot closest to the home slot which
      -- is designated with a 'D'.  The search order still applies (see the
      -- documentation at the beginning of this file).
      --
      o_r_syspars.partial_minimize_option :=
                pl_common.f_get_syspar('PARTIAL_MINIMIZE_OPTION', 'S');

      o_r_syspars.home_itm_rnd_inv_cube_up_to_ti :=
                pl_common.f_get_syspar('HOME_ITM_RND_INV_CUBE_UP_TO_TI', 'Y');

      o_r_syspars.home_itm_rnd_plt_cube_up_to_ti :=
                pl_common.f_get_syspar('HOME_ITM_RND_PLT_CUBE_UP_TO_TI', 'Y');

      o_r_syspars.flt_itm_rnd_inv_cube_up_to_ti :=
                pl_common.f_get_syspar('FLT_ITM_RND_INV_CUBE_UP_TO_TI', 'Y');

      o_r_syspars.flt_itm_rnd_plt_cube_up_to_ti :=
                pl_common.f_get_syspar('FLT_ITM_RND_PLT_CUBE_UP_TO_TI', 'Y');

      --
      -- The search order of the slots to when finding a slot for a partial
      -- pallet going to a non-deep reserve slot.
      --
      o_r_syspars.partial_nondeepslot_search_clr :=
                pl_common.f_get_syspar('PARTIAL_NONDEEPSLOT_SEARCH_CLR', '1');
      o_r_syspars.partial_nondeepslot_search_frz :=
                pl_common.f_get_syspar('PARTIAL_NONDEEPSLOT_SEARCH_FRZ', '1');
      o_r_syspars.partial_nondeepslot_search_dry :=
                pl_common.f_get_syspar('PARTIAL_NONDEEPSLOT_SEARCH_DRY', '1');

      --
      -- The floating slot sort order.  This comes into play when syspar
      -- NON_FIFO_COMBINE_PLTS_IN_FLOAT is Y.
      --
      o_r_syspars.floating_slot_sort_order_clr :=
                pl_common.f_get_syspar('FLOATING_SLOT_SORT_ORDER_CLR', '1');
      o_r_syspars.floating_slot_sort_order_frz :=
                pl_common.f_get_syspar('FLOATING_SLOT_SORT_ORDER_FRZ', '1');
      o_r_syspars.floating_slot_sort_order_dry :=
                pl_common.f_get_syspar('FLOATING_SLOT_SORT_ORDER_DRY', '1');

      --
      -- Check/not check that the floating slot cube is >= last ship
      -- slot cube when selecting candidate OPEN floating slots for
      -- a floating item and putaway is by cube.
      --
      o_r_syspars.chk_float_cube_ge_lss_cube :=
                pl_common.f_get_syspar('CHK_FLOAT_CUBE_GE_LSS_CUBE', 'N');

      --
      -- Check/not check that the floating slot height is >= last ship
      -- slot height when selecting candidate OPEN floating slots for
      -- a floating item and putaway is by inches.
      --
      o_r_syspars.chk_float_hgt_ge_lss_hgt :=
                pl_common.f_get_syspar('CHK_FLOAT_HGT_GE_LSS_HGT', 'N');

      --
      -- Check/not check that the reserve slot cube is >= rank 1 case home slot
      -- cube when selecting candidate OPEN NON-DEEP slots and putaway is by
      -- cube.
      --
      o_r_syspars.chk_reserve_cube_ge_home_cube :=
                pl_common.f_get_syspar('CHK_RESERVE_CUBE_GE_HOME_CUBE', 'Y');

      --
      -- Check/not check that the reserve slot height is >= rank 1 case home slot
      -- height when selecting candidate OPEN NON-DEEP slots and putaway is by
      -- inches
      --
      o_r_syspars.chk_reserve_hgt_ge_home_hgt :=
                pl_common.f_get_syspar('CHK_RESERVE_HGT_GE_HOME_HGT', 'N');

      --
      -- Split RDC SN pallet if the qty is greater than the SWMS Ti Hi.
      --
      o_r_syspars.split_rdc_sn_pallet :=
                pl_common.f_get_syspar('SPLIT_RDC_SN_PALLET', 'N');

      -- Vani Reddy Modified
      -- Matrix Staging or Induction
      o_r_syspars.mx_staging_or_induction_dry :=
                pl_common.f_get_syspar('MX_STAGING_OR_INDUCTION_DRY', NULL);
                
      o_r_syspars.mx_staging_or_induction_clr :=
                pl_common.f_get_syspar('MX_STAGING_OR_INDUCTION_CLR', NULL);
                                               
      o_r_syspars.mx_staging_or_induction_frz :=
                pl_common.f_get_syspar('MX_STAGING_OR_INDUCTION_FRZ', NULL);      -- Vani Reddy Modification end

      --
      -- When finding a slot for a full pallet for an item with a home slot
      -- find the best fit by size (cube or inches--whichever is active) which is
      -- designed with a 'S' or find the slot closest to the home slot which
      -- is designated with a 'D'.
      --
      o_r_syspars.full_plt_minimize_option_clr :=
                pl_common.f_get_syspar('FULL_PLT_MINIMIZE_OPTION_CLR', 'S');

      o_r_syspars.full_plt_minimize_option_frz :=
                pl_common.f_get_syspar('FULL_PLT_MINIMIZE_OPTION_FRZ', 'S');

      o_r_syspars.full_plt_minimize_option_dry :=
                pl_common.f_get_syspar('FULL_PLT_MINIMIZE_OPTION_DRY', 'S');

      --
      -- Assign values to the pseudo syspars.  See the record specification for
      -- a description of each.
      --
      o_r_syspars.stack_in_deep_slots := 'N';
      o_r_syspars.non_fifo_to_home_w_qty_in_rsrv := 'Y';
      o_r_syspars.putaway_to_any_matching_pt := 'N';

      o_r_syspars.extended_case_cube_cutoff_cube := pl_common.f_get_syspar('EXTENDED_CASE_CUBE_CUTOFF_CUBE', '900');
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '  PO/SN[' || i_erm_id || ']'
         || '  Failed to get the syspars.';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message);

END get_putaway_syspars;


---------------------------------------------------------------------------
-- Procedure:
--    show_syspars  (public)
--
-- Description:
--    This procedure outputs the values of the syspars.  Used for debugging.
--
-- Parameters:
---------------------------------------------------------------------------
PROCEDURE show_syspars(i_r_syspars  IN pl_rcv_open_po_types.t_r_putaway_syspars)
IS
BEGIN
   DBMS_OUTPUT.PUT_LINE('enable_live_receiving: ' ||
                        i_r_syspars.enable_live_receiving);

   DBMS_OUTPUT.PUT_LINE('home_putaway: ' ||
                        i_r_syspars.home_putaway);

   DBMS_OUTPUT.PUT_LINE('mixprod_2d3d_flag: ' ||
                        i_r_syspars.mixprod_2d3d_flag);

   DBMS_OUTPUT.PUT_LINE('mix_prod_bulk_area: ' ||
                        i_r_syspars.mix_prod_bulk_area);

   DBMS_OUTPUT.PUT_LINE('mix_same_prod_deep_slot: ' ||
                        i_r_syspars.mix_same_prod_deep_slot);

   DBMS_OUTPUT.PUT_LINE('pallet_type_flag: ' ||
                        i_r_syspars.pallet_type_flag);

   DBMS_OUTPUT.PUT_LINE('putaway_dimension: ' ||
                        i_r_syspars.putaway_dimension);

   DBMS_OUTPUT.PUT_LINE('clam_bed_tracked: ' ||
                        i_r_syspars.clam_bed_tracked);

   DBMS_OUTPUT.PUT_LINE('non_fifo_combine_plts_in_float: ' ||
                        i_r_syspars.non_fifo_combine_plts_in_float);

   DBMS_OUTPUT.PUT_LINE('putaway_to_home_if_fifo_allows: ' ||
                        i_r_syspars.putaway_to_home_if_fifo_allows);

   DBMS_OUTPUT.PUT_LINE('putaway_to_any_deep_slot: ' ||
                        i_r_syspars.putaway_to_any_deep_slot);

   DBMS_OUTPUT.PUT_LINE('chk_reserve_cube_ge_home_cube: ' ||
                        i_r_syspars.chk_reserve_cube_ge_home_cube);

   DBMS_OUTPUT.PUT_LINE('stack_in_deep_slots: ' ||
                        i_r_syspars.stack_in_deep_slots);

   DBMS_OUTPUT.PUT_LINE('non_fifo_to_home_w_qty_in_rsrv: ' ||
                        i_r_syspars.non_fifo_to_home_w_qty_in_rsrv);

   DBMS_OUTPUT.PUT_LINE('putaway_to_any_matching_pt: ' ||
                        i_r_syspars.putaway_to_any_matching_pt);

   DBMS_OUTPUT.PUT_LINE('split_rdc_sn_pallet: ' ||
                        i_r_syspars.split_rdc_sn_pallet);
   --VR modified                     
   DBMS_OUTPUT.PUT_LINE('mx_staging_or_induction_dry: ' ||
                        i_r_syspars.mx_staging_or_induction_dry);
                        
   DBMS_OUTPUT.PUT_LINE('mx_staging_or_induction_clr: ' ||
                        i_r_syspars.mx_staging_or_induction_clr);
                        
   DBMS_OUTPUT.PUT_LINE('mx_staging_or_induction_frz: ' ||
                        i_r_syspars.mx_staging_or_induction_frz);  --VR modification end 

   DBMS_OUTPUT.PUT_LINE('full_plt_minimize_option_clr: ' ||
                        i_r_syspars.mx_staging_or_induction_clr);
   DBMS_OUTPUT.PUT_LINE('full_plt_minimize_option_frz: ' ||
                        i_r_syspars.mx_staging_or_induction_frz);
   DBMS_OUTPUT.PUT_LINE('full_plt_minimize_option_dry: ' ||
                        i_r_syspars.mx_staging_or_induction_dry);

   DBMS_OUTPUT.PUT_LINE('EXTENDED_CASE_CUBE_CUTOFF_CUBE: ' ||
                        i_r_syspars.EXTENDED_CASE_CUBE_CUTOFF_CUBE);

END show_syspars;


---------------------------------------------------------------------------
-- Procedure:
--   log_syspars (public)
--
-- Description:
--    This procedure logs the setting of the syspars.  It will not log
--    the "psuedo" syspars.
--
-- Parameters:
--    i_r_syspars   - Syspars
--    i_erm_id      - PO/SN being processed.  Used in aplog messages.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - find_slot
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/20/05 prpbcb   Created
--    03/17/09 prpbcb   Added syspar SPLIT_RDC_SN_PALLET.
--    09/18/14 vred5319 Modified to add mx_staging_or_induction types
--    09/06/16 bben0556 Added syspar ENABLE_LIVE_RECEIVING.
--    01/17/22 bben0556 Added syspar EXTENDED_CASE_CUBE_CUTOFF_CUBE.
---------------------------------------------------------------------------
PROCEDURE log_syspars
           (i_r_syspars   IN pl_rcv_open_po_types.t_r_putaway_syspars,
            i_erm_id      IN erm.erm_id%TYPE)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(30) := 'log_syspars';

BEGIN
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
      'Syspar Settings:'
      || '  ENABLE_LIVE_RECEIVING['   || i_r_syspars.enable_live_receiving   || ']'
      || '  HOME_PUTAWAY['            || i_r_syspars.home_putaway            || ']'
      || '  MIXPROD_2D3D_FLAG['       || i_r_syspars.mixprod_2d3d_flag       || ']'
      || '  MIX_PROD_BULK_AREA['      || i_r_syspars.mix_prod_bulk_area      || ']'
      || '  MIX_SAME_PROD_DEEP_SLOT[' || i_r_syspars.mix_same_prod_deep_slot || ']'
      || '  PALLET_TYPE_FLAG[' || i_r_syspars.pallet_type_flag || ']'
      || '  PUTAWAY_DIMENSION[' || i_r_syspars.putaway_dimension || ']'
      || '  CLAM_BED_TRACKED[' || i_r_syspars.clam_bed_tracked || ']'
      || '  NON_FIFO_COMBINE_PLTS_IN_FLOAT['
      || i_r_syspars.non_fifo_combine_plts_in_float || ']'
      || '  PUTAWAY_TO_ANY_DEEP_SLOT['
      || i_r_syspars.putaway_to_any_deep_slot || ']'
      || '  PUTAWAY_TO_HOME_IF_FIFO_ALLOWS['
      || i_r_syspars.putaway_to_home_if_fifo_allows || ']'
      || '  PARTIAL_NONDEEPSLOT_SEARCH_CLR['
      || i_r_syspars.partial_nondeepslot_search_clr || ']'
      || '  PARTIAL_NONDEEPSLOT_SEARCH_FRZ['
      || i_r_syspars.partial_nondeepslot_search_frz || ']'
      || '  PARTIAL_NONDEEPSLOT_SEARCH_DRY['
      || i_r_syspars.partial_nondeepslot_search_dry || ']'
      || '  CHK_FLOAT_CUBE_GE_LSS_CUBE['
      || i_r_syspars.chk_float_cube_ge_lss_cube || ']'
      || '  CHK_FLOAT_HGT_GE_LSS_HGT['
      || i_r_syspars.chk_float_hgt_ge_lss_hgt || ']'
      || '  CHK_RESERVE_CUBE_GE_HOME_CUBE['
      || i_r_syspars.chk_reserve_cube_ge_home_cube || ']'
      || '  CHK_RESERVE_HGT_GE_HOME_HGT['
      || i_r_syspars.chk_reserve_hgt_ge_home_hgt || ']'
      || '  PARTIAL_MINIMIZE_OPTION['
      || i_r_syspars.partial_minimize_option || ']'
      || '  FLOATING_SLOT_SORT_ORDER_CLR['
      || i_r_syspars.floating_slot_sort_order_clr || ']'
      || '  FLOATING_SLOT_SORT_ORDER_FRZ['
      || i_r_syspars.floating_slot_sort_order_frz || ']'
      || '  FLOATING_SLOT_SORT_ORDER_DRY['
      || i_r_syspars.floating_slot_sort_order_dry || ']'
      || '  SPLIT_RDC_SN_PALLET['
      || i_r_syspars.split_rdc_sn_pallet || ']'
      || '  MX_STAGING_OR_INDUCTION_DRY['                                 -- VR modified
      || i_r_syspars.mx_staging_or_induction_dry || ']'
      || '  MX_STAGING_OR_INDUCTION_CLR['
      || i_r_syspars.mx_staging_or_induction_clr || ']'
      || '  MX_STAGING_OR_INDUCTION_FRZ['
      || i_r_syspars.mx_staging_or_induction_frz || ']'                    -- VR modification end   
      || '  FULL_PLT_MINIMIZE_OPTION_CLR['
      || i_r_syspars.full_plt_minimize_option_clr || ']'
      || '  FULL_PLT_MINIMIZE_OPTION_FRZ['
      || i_r_syspars.full_plt_minimize_option_frz || ']'
      || '  FULL_PLT_MINIMIZE_OPTION_DRY['
      || i_r_syspars.full_plt_minimize_option_dry || ']'
      || '  EXTENDED_CASE_CUBE_CUTOFF_CUBE['      || i_r_syspars.EXTENDED_CASE_CUBE_CUTOFF_CUBE || ']'
      || '  PO/SN[' || i_erm_id || ']',
      NULL, NULL);
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name || '  PO/SN[' || i_erm_id || ']';
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      DBMS_OUTPUT.PUT_LINE(SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message);

END log_syspars;


---------------------------------------------------------------------------
-- Procedure:
--    insert_records
--
-- Description:
--    This procedure inserts the PUTAWAYLST record and if the destination
--    location is not '*' inserts the INV record if the destination location
--    is not a home slot otherwise the home slot is updated.
--
--    For an SN, any required changes to the information tracking fields are
--    made here as well as validation of the data.
--
--    If a location was found for a pallet and processing an SN then
--    erd_lpn.pallet_assigned_flag is updated to Y.
--
-- Parameters:
--    i_r_item_info     - Item information record.
--    io_r_pallet       - Pallet record to process.  Passed as IN OUT because
--                        fields are modified though the calling object will
--                        not use any of these.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called By:
--    - direct_pallets_to_home_slot
--    - direct_pallets_to_split_home
--    - direct_pallets_to_slots_inzone
--    - no_slot_found
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
--    01/31/06 prpbcb   Modified to populate inv.inv.uom.
--    05/06/08 prpbcb   Added l_stmt_num to identify what stmt caused an
--                      error if an error occurs.
--    03/17/09 prpbcb   Populate putawylst.from_splitting_sn_pallet_flag.
--    10/20/09 ctvgg000	ASN to all OPCOs project
--			Include VSN in the erm_type if condition.
--			This is to process pallets in a VN similar to SN.
--
--			A pallet in a VSN can also be "*" because 
--			the qty was greater than SWMS Ti Hi. So include this
--			to the if condition where erm_type IN ('SN', 'VN')
--
--			Get the catch weight from ERD_LPN for creating  
--			TMP_WEIGHT record for VN. This is being done for 
--			SN already.
--
--    09/08/16 prpbcb   Live Receiving.
--                      When finding a slot for an existing putaway task
--                      update the PUTAWAYLST.DEST_LOC with the pallet
--                      location.  A field in the pallet record
--                      designates this.
--
---------------------------------------------------------------------------
PROCEDURE insert_records
           (i_r_item_info  IN            pl_rcv_open_po_types.t_r_item_info,
            io_r_pallet    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) :=  'insert_records';

   l_dummy              VARCHAR2(1);  -- Work area
   l_stmt_num           PLS_INTEGER := 0;  -- To identity stmt when an
                                          -- error occurs.
   l_sysdate            DATE;   -- The current sysdate.  Assigned once then
                                -- used where SYSDATE is needed.  Faster than
                                -- using SYSDATE each time.
   l_exp_date           DATE;   -- Jira 438, If auto confirm inv, then don't use SYSDATE
   l_total_cases        PLS_INTEGER := 0;   -- For TMP_WEIGHT table
   l_total_weight       NUMBER := 0;        -- For TMP_WEIGHT table
   l_inv_weight         inv.weight%TYPE;
   l_qoh                NUMBER := 0;        -- For inv.qoh
   l_qty_planned        NUMBER := io_r_pallet.qty;

   l_pallet_in_pit_flag CHAR := 'N';
   
   l_ato_conf_cnt number :=0;

   --
   -- This cursor is used to determine if a catch weight record exists.
   --
   CURSOR c_catch_weight
                (cp_erm_id            tmp_weight.erm_id%TYPE,
                 cp_prod_id           tmp_weight.prod_id%TYPE,
                 cp_cust_pref_vendor  tmp_weight.cust_pref_vendor%TYPE) IS
      SELECT 'x'
        FROM tmp_weight
       WHERE erm_id           = cp_erm_id
         AND prod_id          = cp_prod_id
         AND cust_pref_vendor = cp_cust_pref_vendor;
BEGIN
   --
   -- Initialization.
   --
   l_sysdate := TRUNC(SYSDATE); -- To keep from using SYSDATE a bunch of times.

	-- 10/20/09 - ctvgg000 - ASN to all OPCOs project
	-- Include VSN in the erm_type if condition.
	-- This is to process pallets in a VN similar to SN.	

   --
   -- Check to see if the pallet is currently sitting in the PIT location in the system.
   --
   l_pallet_in_pit_flag := pl_putaway_utilities.f_is_pallet_in_pit_location(io_r_pallet.pallet_id);


   IF (io_r_pallet.erm_type IN ('SN','VN')) THEN
      --
      -- Processing a SN.
      --
      -- Validate/set the data capture values.
      --
      validate_set_sn_data_capture(i_r_item_info, io_r_pallet);
      --
      -- Show the pallet has been processed.
      --
      BEGIN
         UPDATE erd_lpn
            SET pallet_assigned_flag = 'Y'
          WHERE pallet_id = io_r_pallet.pallet_id;
         --
         -- Check if the record was updated.
         --
         IF (SQL%NOTFOUND) THEN
            --
            -- No record was updated.  This will not stop processing but
            -- there could be potential problems if this program is rerun
            -- on the same SN.
            --
            -- Write log message.
            --
            l_message := l_object_name || '  TABLE=erd_lpn'
                  || '  KEY=[' || io_r_pallet.pallet_id || '(LP)]'
                  || '  Item[' || io_r_pallet.prod_id || ']'
                  || '  CPV[' || io_r_pallet.cust_pref_vendor || ']'
                  || '  Destination loc[' || io_r_pallet.dest_loc || ']'
                  || '  PO/SN[' || io_r_pallet.erm_id || ']'
                  || '  ACTION=UPDATE  MESSAGE="Failed to update the'
                  || ' pallet_assigned_flag to Y because no record was found.'
                  || '  This will not stop processing but could cause'
                  || ' problems if the program is rerun on the same SN."';
            pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name, l_message,
                           NULL, NULL,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
         END IF;
      END;  -- end update erd_lpn block
   ELSE
      --
      -- Processing a PO.  Force data collection based on the item.
      --
      
      IF io_r_pallet.collect_exp_date is null THEN
          io_r_pallet.collect_exp_date := i_r_item_info.exp_date_trk;
      END IF;
      
      IF io_r_pallet.collect_mfg_date is null THEN
          io_r_pallet.collect_mfg_date := i_r_item_info.mfg_date_trk;
      END IF;

      IF io_r_pallet.collect_lot_id is null THEN
          io_r_pallet.collect_lot_id := i_r_item_info.lot_trk;
      END IF;

      IF io_r_pallet.collect_catch_wt is null THEN
          io_r_pallet.collect_catch_wt := i_r_item_info.catch_wt_trk;
      END IF;

      IF io_r_pallet.collect_temp is null THEN
          io_r_pallet.collect_temp := i_r_item_info.temp_trk;
      END IF;

      IF io_r_pallet.collect_clam_bed is null THEN
          io_r_pallet.collect_clam_bed := i_r_item_info.clam_bed_trk;
      END IF;

      IF io_r_pallet.collect_tti is null THEN
          io_r_pallet.collect_tti := i_r_item_info.tti_trk;
      END IF;

      IF io_r_pallet.collect_cool is null THEN
          io_r_pallet.collect_cool := i_r_item_info.cool_trk;
      END IF;
      -- Commented out Jira-438. Use above if statements to set values
      /*io_r_pallet.collect_exp_date  := i_r_item_info.exp_date_trk;
      io_r_pallet.collect_mfg_date  := i_r_item_info.mfg_date_trk;
      io_r_pallet.collect_lot_id    := i_r_item_info.lot_trk;
      io_r_pallet.collect_catch_wt  := i_r_item_info.catch_wt_trk;
      io_r_pallet.collect_temp      := i_r_item_info.temp_trk;
      io_r_pallet.collect_clam_bed  := i_r_item_info.clam_bed_trk;
      io_r_pallet.collect_tti       := i_r_item_info.tti_trk;
      io_r_pallet.collect_cool      := i_r_item_info.cool_trk;*/
      
	  /* Jira 3230 code was removed in previous version, exp_date is defaulted to sysdate to begin with*/
        io_r_pallet.exp_date := l_sysdate;
	   
	   
          --Jira 2628 vkal9662
          select count(*) into l_ato_conf_cnt
          from zone a, lzone b, rules c
          where a.RULE_ID =c.RULE_ID
          and b.ZONE_ID = a.ZONE_ID
          and a.ZONE_TYPE = 'PUT'
          and nvl(c.AUTO_CONFRM,'N') ='Y'
          and b.LOGI_LOC =io_r_pallet.dest_loc;
          
          If l_ato_conf_cnt >0 then
            io_r_pallet.auto_confirm_put := 'Y';
          else   
              io_r_pallet.auto_confirm_put := 'N';
          end if;    
              
      IF NVL(io_r_pallet.auto_confirm_put, 'N') = 'Y' THEN
          l_qty_planned := 0;
          l_qoh := io_r_pallet.qty;
          l_exp_date := io_r_pallet.exp_date;
      ELSE
          l_qoh := 0;
          l_qty_planned := io_r_pallet.qty;
          l_exp_date := l_sysdate;
      END IF;
         
   END IF;

   --
   -- If a slot was found for the pallet and not a "live receiving" pallet
   -- then update the inventory if the
   -- slot is a home slot otherwise insert an inventory record.
   --
   IF (io_r_pallet.dest_loc NOT IN ('*', pl_rcv_open_po_types.ct_lr_dest_loc)) THEN
      --
      -- A location was found for the pallet.
      --
      IF (io_r_pallet.dest_loc_is_home_slot_bln = TRUE) THEN

         --
         -- If the the pallet is sitting in the PIT location, delete the inventory since we are updating the 
         -- inventory to qty_planned on the home location.
         --
         IF l_pallet_in_pit_flag = 'Y' THEN
            DELETE FROM INV
            WHERE logi_loc = io_r_pallet.pallet_id;

            -- Move the qoh from the inventory we just deleted, to the home location qoh rather than qty_planned
            -- since it's already been received. The qty_produced is added to the qty_produced of the home slot.
            UPDATE inv i
               SET i.qoh = i.qoh + io_r_pallet.qty,
                   i.qty_produced = NVL(i.qty_produced, 0) + NVL(io_r_pallet.qty_produced, 0)
             WHERE i.logi_loc         = io_r_pallet.dest_loc
               AND i.plogi_loc        = i.logi_loc
               AND i.prod_id          = io_r_pallet.prod_id
               AND i.cust_pref_vendor = io_r_pallet.cust_pref_vendor;
         ELSE
            --
            -- The destination location is a home slot.  Update the inventory.
            -- Match up several columns as a sanity check.
            --
            UPDATE inv i
               SET i.qty_planned = i.qty_planned + io_r_pallet.qty   -- 09/28/16  Brian Bent Do not use io_r_pallet.qty_received
             WHERE i.logi_loc         = io_r_pallet.dest_loc
               AND i.plogi_loc        = i.logi_loc
               AND i.prod_id          = io_r_pallet.prod_id
               AND i.cust_pref_vendor = io_r_pallet.cust_pref_vendor;

         END IF;

         --
         -- Check if the home slot was updated.
         --
         IF (SQL%FOUND) THEN
            --
            -- Home slot updated.
            -- Write log message.
            --
            log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
                 io_r_pallet,
                 'The home slot qty planned updated successfully.');
         ELSE
            --
            -- The home slot was not updated.  No record was found.
            --
            l_message := l_object_name || '  TABLE=inv'
                  || '  KEY=[' || io_r_pallet.dest_loc || ']'
                  || '[' || io_r_pallet.prod_id || ']'
                  || '[' || io_r_pallet.cust_pref_vendor || ']'
                  || '(dest loc,prod_id,cpv)'
                  || '  io_r_pallet.qty[' || TO_CHAR(io_r_pallet.qty) || ']'
                  || '  PO/SN[' || io_r_pallet.erm_id || ']'
                  || '  ACTION=UPDATE'
                  || '  MESSAGE="Failed to update the inventory home slot'
                  || ' qty planned.  No record was found.  This will cause'
                  || ' inventory qty issues.';
            pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name, l_message,
                           NULL, NULL,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
         END IF;
      ELSE
         --
         -- The destination location is a reserve slot or floating slot or
         -- miniloader induction location.
         -- Create the inventory record.
         --
         --
         -- 01/31/06 prpbbb The io_r_pallet.inv_uom was added as part of the
         -- miniloader changes.
         --


         BEGIN
            --
            -- If the pallet is sitting in the pit location, then update the current inv.plogi_loc
            -- to use the new location that was found.
            --
            IF l_pallet_in_pit_flag = 'Y' THEN
               
               UPDATE INV
               SET plogi_loc = io_r_pallet.dest_loc
               WHERE logi_loc = io_r_pallet.pallet_id;

            ELSE

               INSERT INTO inv
                        (plogi_loc,
                        logi_loc,
                        prod_id,
                        cust_pref_vendor,
                        rec_id,
                        qty_planned,
                        qoh,
                        qty_alloc,
                        min_qty,
                        inv_date,
                        rec_date,
                        abc,
                        status,
                        lst_cycle_date,
                        cube,
                        abc_gen_date,
                        exp_date,
                        mfg_date,
                        inv_uom,
                        parent_pallet_id,
                        weight,
                        inv_cust_id,
                        inv_order_id)
                  VALUES (io_r_pallet.dest_loc,           -- plogi_loc
                        io_r_pallet.pallet_id,          -- logi_loc
                        io_r_pallet.prod_id,            -- prod_id
                        io_r_pallet.cust_pref_vendor,   -- cust_pref_vendor
                        io_r_pallet.erm_id,             -- rec_id
                        l_qty_planned,--io_r_pallet.qty,   qty_planned   -- 09/28/16  Brian Bent Use io_r_pallet.qty instead of io_r_pallet.qty_received
                                                                           -- 06/20/18  mpha8134   Use l_qty_planned instead of io_r_pallet.qty,
                                                                           --                      assign l_qty_planned value above
                        l_qoh,  --0,                    -- qoh           -- 06/20/18  mpha8134   Use variable, assign l_qoh value above
                        0,                              -- qty_alloc
                        0,                              -- min_qty
                        l_sysdate,                      -- inv_date
                        l_sysdate,                      -- rec_date
                        i_r_item_info.abc,              -- abc
                        DECODE(i_r_item_info.aging_item, 'Y', 'HLD',
                                                         'AVL'),  -- status
                        l_sysdate,                      -- lst_cycle_date
                        io_r_pallet.cube_with_skid,     -- cube
                        l_sysdate,                      -- abc_gen_date
                        l_exp_date,                     -- exp_date
                        io_r_pallet.mfg_date,           -- mfg_date
                        io_r_pallet.inv_uom,            -- inv_uom 
                        io_r_pallet.parent_pallet_id,   -- parent_pallet_id Jira 438
                        io_r_pallet.inv_weight,       -- Added for Jira 438
                        io_r_pallet.cust_id,            -- Added for Jira 438 
                        io_r_pallet.order_id);          -- Added for Jira 438
            END IF; -- END l_pallet_in_pit_flag = 'Y'

            log_pallet_message(pl_log.ct_info_msg, l_object_name, i_r_item_info,
              io_r_pallet,
              'Putaway to reserve/floating/induction slot.  Inventory created'
              || ' successfully.');
         EXCEPTION
            WHEN OTHERS THEN
               --
               -- The insert into INV failed for some reason.  Log
               -- a message and propagate the exception.
               --
               l_message := l_object_name || '  TABLE=inv'
                  || '  LP[' || io_r_pallet.pallet_id || ']'
                  || '  Item[' || io_r_pallet.prod_id || ']'
                  || '  CPV[' || io_r_pallet.cust_pref_vendor || ']'
                  || '  Destination loc[' || io_r_pallet.dest_loc || ']'
                  || '  PO/SN[' || io_r_pallet.erm_id || ']'
                  || '  ACTION=INSERT  MESSAGE="Insert record failed."';
               pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);

               RAISE;
         END;
      END IF;
   ELSE
      --
      -- The pallet "*" or a "live receiving" pallet.
      --
      -- If the pallet "*" because it was an a SN and the qty was greater
      -- than the Ti Hi then log this.  Be aware that the initial reason the
      -- pallet could "*" is because no slot was found for the pallet and not
      -- because the check of the pallet qty was > Ti Hi.
      --

      -- 10/20/09 - ctvgg000 - A pallet in a VSN can also be "*" because
      -- the qty was greater than SWMS Ti Hi. So include this to the
      -- if condition where erm_type IN ('SN', 'VN')
      IF (io_r_pallet.erm_type IN ('SN','VN') AND
          io_r_pallet.qty_received >
                (i_r_item_info.ti * i_r_item_info.hi * i_r_item_info.spc)) THEN
         --
         -- The pallet is on a SN and the pallet qty is >= Ti Hi.
         -- "*" the pallet.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
            'LP[' || io_r_pallet.pallet_id || ']'
            || '  Item[' || io_r_pallet.prod_id || ']'
            || '  CPV[' || io_r_pallet.cust_pref_vendor || ']'
            || '  PO/SN[' || io_r_pallet.erm_id || ']'
            || '  Ti[' || TO_CHAR(i_r_item_info.ti) || ']'
            || '  Hi[' || TO_CHAR(i_r_item_info.hi) || ']'
            || '  Destination loc[' || io_r_pallet.dest_loc || ']'
            || '  Processing a SN and the qty on the pallet is more than the'
            || ' SWMS Ti Hi for the item.  The pallet will not be assigned a'
            || ' slot.',
            NULL, NULL,
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
      END IF;
   END IF;  -- end if (io_r_pallet.dest_loc NOT IN ('*', pl_rcv_open_po_types.ct_lr_dest_loc))

   --
   -- Update RHB transaction with received date
   --
   -- 09/01/05 prpbcb I am not familiar with the RHB logic.  I took
   -- the logic straight from pallet_label2.pc
   UPDATE trans
      SET mfg_date = l_sysdate
    WHERE trans_type       = 'RHB'
      AND prod_id          = io_r_pallet.prod_id
      AND cust_pref_vendor = io_r_pallet.cust_pref_vendor
      AND rec_id           = io_r_pallet.erm_id
      AND ROWNUM           = 1;

   --
   -- If a live receiving pallet and we are at the point of finding the
   -- dest loc then update the PUTAWAYLST.DEST_LOC otherwise insert the
   -- putaway task.
   --
   IF (io_r_pallet.live_receiving_status = 'SLOT')
   THEN
      --
      -- We are at the point of having found the dest loc for
      -- the live receiving pallet.  Update the PUTAWAYLST.DEST_LOC
      --
      update_putawaylst(i_r_item_info, io_r_pallet);
   ELSE
      insert_putawaylst(i_r_item_info, io_r_pallet);
   END IF;

   --
   -- Mark the pallet as having been processed.
   --
   io_r_pallet.pallet_processed_bln := TRUE;

   --
   -- If it is a catch weight track item then create the TMP_WEIGHT record if
   -- it does not already exists.  This record will assure the close PO/SN
   -- screen pops up the catch weight entry.
   --
   IF (i_r_item_info.catch_wt_trk = 'Y') THEN
      l_stmt_num := 1;
      OPEN c_catch_weight(io_r_pallet.erm_id,
                          io_r_pallet.prod_id,
                          io_r_pallet.cust_pref_vendor);
      l_stmt_num := 2;
      FETCH c_catch_weight INTO l_dummy;

      l_stmt_num := 4;
      IF (c_catch_weight%FOUND) THEN
         l_stmt_num := 5;
         CLOSE c_catch_weight;
      ELSE
         l_stmt_num := 6;
         CLOSE c_catch_weight;

            --
            -- 10/20/09 ctvgg000 ASN to all OPCOs project
            -- Get the catch weight from ERD_LPN for creating
            -- TMP_WEIGHT record for VN. This is being done for
            -- SN already, now I included VN in the if condition.
            --
         IF (io_r_pallet.erm_type IN ('SN','VN')) THEN
            --
            -- Get the catch weight to use in creating the TMP_WEIGHT record.
            --

            /******
            7/1/08 Brian Bent Comment out.  Don't need this msg.
                   Was used for debugging
            l_message := l_object_name || '  TABLE=ERD_LPN'
                  || '  Erm ID[' || io_r_pallet.erm_id || ']'
                  || '  Item[' || io_r_pallet.prod_id || ']'
                  || '  CPV[' || io_r_pallet.cust_pref_vendor || ']'
                  || '  PO/SN[' || io_r_pallet.erm_id || ']'
                  || '  BEFORE SUM OF WEIGHT/CASES';

            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                   l_message,
                   NULL, NULL,
                   pl_rcv_open_po_types.ct_application_function,
                   gl_pkg_name);
            ******/

            l_stmt_num := 7;

            SELECT NVL(SUM(NVL(catch_weight, 0)), 0),
                   NVL(SUM(NVL(qty, 0)), 0)
              INTO l_total_weight,
                   l_total_cases
              FROM erd_lpn
             WHERE prod_id          = io_r_pallet.prod_id
               AND cust_pref_vendor = io_r_pallet.cust_pref_vendor
               AND sn_no            = io_r_pallet.erm_id;

            /******
            7/1/08 Brian Bent Comment out.  Don't need this msg.
                   Was used for debugging
            l_message := l_object_name || '  TABLE=ERD_LPN'
                  || '  Erm ID[' || io_r_pallet.erm_id || ']'
                  || '  Item[' || io_r_pallet.prod_id || ']'
                  || '  CPV[' || io_r_pallet.cust_pref_vendor || ']'
                  || '  PO/SN[' || io_r_pallet.erm_id || ']'
                  || '  AFTER SUM OF WEIGHT/CASES';
            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                   l_message,
                   NULL, NULL,
                   pl_rcv_open_po_types.ct_application_function,
                   gl_pkg_name);
            ******/
         END IF;

         /******
         7/1/08 Brian Bent Comment out.  Don't need this msg.
                   Was used for debugging
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                   'BEFORE INSERT INTO TMP_WEIGHT',
                   NULL, NULL,
                   pl_rcv_open_po_types.ct_application_function,
                   gl_pkg_name);
         ******/

         l_stmt_num := 8;
         BEGIN  -- start a new block to trap errors

            -- 10/20/09 ctvgg000 ASN to all OPCOs Project
            -- Insert the total weight in total cases field for VSN.
            -- Add 'VN' to the decode statement in the below query.
            INSERT INTO tmp_weight
                      (erm_id,
                       prod_id,
                       cust_pref_vendor,
                       total_cases,
                       total_splits,
                       total_weight)
               VALUES (io_r_pallet.erm_id,
                       io_r_pallet.prod_id,
                       io_r_pallet.cust_pref_vendor,
                       DECODE(io_r_pallet.erm_type,
                              'SN', DECODE(l_total_weight, 0, 0,
                                                       l_total_cases),
                              'VN', DECODE(l_total_weight, 0, 0,
                                                       l_total_cases),
                              0),
                       0,          -- l_total_splits
                       l_total_weight);
         EXCEPTION
            WHEN OTHERS THEN
               --
               -- The insert into TMP_WEIGHT table failed for some reason.
               -- Log a message and propagate the exception.
               --
               l_message := l_object_name || '  TABLE=tmp_weight'
                  || '  Erm ID[' || io_r_pallet.erm_id || ']'
                  || '  Item[' || io_r_pallet.prod_id || ']'
                  || '  CPV[' || io_r_pallet.cust_pref_vendor || ']'
                  || '  PO/SN[' || io_r_pallet.erm_id || ']'
                  || '  l_stmt_num[' || TO_CHAR(l_stmt_num) || ']'
                  || '  ACTION=INSERT  MESSAGE="Insert record failed."';

               pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                              SQLCODE, SQLERRM,
                              pl_rcv_open_po_types.ct_application_function,
                              gl_pkg_name);

               RAISE;
         END;
      END IF;  -- end if (c_catch_weight%FOUND)
   END IF;  -- end if (i_r_item_info.catch_wt_trk = 'Y')
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name || '(i_r_item_info,io_r_pallet)'
         || '  i_r_item_info.prod_id[' || i_r_item_info.prod_id || ']'
         || '  i_r_item_info.cust_pref_vendor['
         || i_r_item_info.cust_pref_vendor || ']'
         || '  io_r_pallet.pallet_id[' || io_r_pallet.pallet_id || ']'
         || '  io_r_pallet.erm_id[' || io_r_pallet.erm_id || ']'
         || '  l_stmt_num[' || TO_CHAR(l_stmt_num) || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                   gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);

END insert_records;


---------------------------------------------------------------------------
--  Procedure:
--      insert_records_multi_lp_parent
--
--  Description:
--      This procedure calls the insert_records procedure N number of times
--      based on number of case-LPs N that are on the parent pallet.
--      Ex: Parent pallet with pallet_index of 1 has 3 child case-LPs on it
--      We want to insert records for each of the child case-LPs (NOT the parent
--      the parent just holds information) so we loop through the pallet table.
--      start_index := parent_pallet_index + 1; 
--      end_index := start + 3;
--      for i in start .. end loop, and call insert_records() for each case-LP.
--
--  Parameters:
--      i_r_item_info       - Item information record
--      io_r_pallet_table   - The table of pallet records. Passed as IN OUT because
--                          fields are modified though the calling object will 
--                          not use any of these
--      io_pallet_index     - The index of the pallet to process from pallet_table
-- 
--  Called by:
--      - direct_pallets_to_split_home
--      - direct_pallets_to_slots_inzone
--      - no_slot_found
--
--  Modification History:
--      Date        Designer    Comments
--      --------    --------    -------------------------------------------
--      06/27/18    mpha8134    Created
--      02/28/19    mpha8134    Not used as of now.  
---------------------------------------------------------------------------
PROCEDURE insert_records_multi_lp_parent (
            i_r_item_info       IN              pl_rcv_open_po_types.t_r_item_info,
            io_r_pallet_table   IN OUT NOCOPY   pl_rcv_open_po_types.t_r_pallet_table,
            io_pallet_index     IN OUT          PLS_INTEGER
)
IS
    l_start PLS_INTEGER;
    l_end PLS_INTEGER;
    l_dest_loc putawaylst.dest_loc%TYPE; -- dest_loc stored in the parent pallet record

    l_message VARCHAR2(256); -- Message buffer
    l_object_name VARCHAR2(30) := 'insert_records_multi_lp_parent';

BEGIN

    l_message := 'Inserting records for Multi-LP Parent pallet' || 
        ' PARENT_PALLET_ID[' || io_r_pallet_table(io_pallet_index).parent_pallet_id || ']' ||
        ' case QTY[' || io_r_pallet_table(io_pallet_index).qty || ']';
    pl_log.ins_msg(
        pl_log.ct_info_msg, 
        l_object_name, 
        l_message,
        NULL,
        NULL,
        pl_rcv_open_po_types.ct_application_function,
        gl_pkg_name);

    --
    -- Initialization
    --
    l_start := io_pallet_index + 1;
    l_end := io_pallet_index + io_r_pallet_table(io_pallet_index).qty;
    l_dest_loc := io_r_pallet_table(io_pallet_index).dest_loc;

    FOR i in l_start .. l_end LOOP
        io_r_pallet_table(i).dest_loc := l_dest_loc;

        IF io_r_pallet_table(i).dest_loc IN ('*', pl_rcv_open_po_types.ct_lr_dest_loc) THEN
            io_r_pallet_table(i).auto_confirm_put := 'N';
        END IF;

        insert_records(i_r_item_info, io_r_pallet_table(i));
        io_pallet_index := io_pallet_index + 1;
    END LOOP;
END;


---------------------------------------------------------------------------
-- Procedure:
--    find_slot
--
-- Description:
--    This procedure finds and assigns the putaway slots for a PO/SN.
--
-- Parameters:
--    i_erm_id                 - PO#/SN# to find the slots for.
--    i_pallet_id              - For Live Receiving.  Works in conjuction with
--                               i_use_existing_tasks_bln.  When populated and
--                               i_use_existing_tasks_bln is TRUE then find the
--                               putaway slot for the the pallet.  The pallet
--                               needs to be in PUTAWAYLST table with dest_loc
--                               = 'LR'  If the dest_loc is not LR then nothing
--                               happens.
--    i_use_existing_tasks_bln - For Live Receving.  This designates to use the
--                               existing putaway tasks to create the pallet
--                               list.  When TRUE locations will be found for
--                               the PUTAWAYLST records with dest_loc = 'LR'.
--                               The calling program needs to set this appropriately.                               
--    io_error_bln             - Designates if an error occurred opening the PO/SN.
--    o_crt_msg                - Error message to display on the CRT if an error
--                               occurs.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - pallet_label2.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created
--    09/20/16 bben0556 Add parameters "i_use_existing_tasks_bln" and
--                      i_pallet_id for Live Receiving.
--    12/11/18 mpha8134 Add new erm_type FG
---------------------------------------------------------------------------
PROCEDURE find_slot(i_erm_id                 IN     erm.erm_id%TYPE,
                    i_pallet_id              IN     putawaylst.pallet_id%TYPE DEFAULT NULL,
                    i_use_existing_tasks_bln IN     BOOLEAN                   DEFAULT FALSE,
                    io_error_bln             IN OUT BOOLEAN,
                    o_crt_msg                OUT    VARCHAR2)

IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'find_slot';

   l_crt_message        VARCHAR2(512); -- Message to display on the CRT
                                       -- if an error occurs.
   l_dummy              VARCHAR2(1);  -- Work area
   l_dummy_parents      pl_msku.t_parent_pallet_id_arr; -- Holding area.
   l_error_bln          BOOLEAN;
   l_r_item_info_table  pl_rcv_open_po_types.t_r_item_info_table;
   l_r_pallet_table     pl_rcv_open_po_types.t_r_pallet_table;
   l_r_syspars          pl_rcv_open_po_types.t_r_putaway_syspars;  -- Syspars

   l_erm_type                erm.erm_type%TYPE;  -- 03/10/2017  Added
   l_find_slots_bln          BOOLEAN;            -- 03/10/2017  Added

   e_error_with_msku    EXCEPTION;
BEGIN
   BEGIN
      l_message := l_object_name
            || '(i_erm_id[' || i_erm_id || ']'
            || ',i_pallet_id[' || i_pallet_id || ']'
            || ',i_use_existing_tasks_bln[' || f_boolean_text(i_use_existing_tasks_bln) || ']'
            || ', io_error_bln, o_crt_msg)';

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      --
      -- Check for null parameters.
      --
      IF (i_erm_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;
      --
      -- Initialization
      --
      l_error_bln := FALSE;

      --
      -- Get what is being processed--PO or SN.
      --
      BEGIN
         SELECT erm.erm_type
           INTO l_erm_type
           FROM erm
          WHERE erm.erm_id = i_erm_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
      END;

      --
      -- Are we at the point of finding the slots
      -- or creating putaway tasks with "LR" dest loc.
      --
      IF (   l_erm_type = 'SN'
          OR i_use_existing_tasks_bln = TRUE
          OR pl_common.f_is_internal_production_po(i_erm_id))
      THEN
         l_find_slots_bln := TRUE;
      ELSE
         l_find_slots_bln := FALSE;
      END IF;

      --
      -- If processing a SN then assign slots to MSKUs first.
      --
      IF (l_erm_type = 'SN') THEN

         pl_msku.p_assign_msku_putaway_slots(i_erm_id,
                                             l_dummy_parents,
                                             l_error_bln,
                                             l_crt_message);

         --
         -- Stop processing if there was an error processing
         -- the MSKU's on the SN.
         --
         IF (l_error_bln = TRUE) THEN
            o_crt_msg := l_crt_message;
            RAISE e_error_with_msku;
         END IF;
      END IF;

      --
      -- Retrieve the relevant syspars.
      --
      get_putaway_syspars
                 (i_erm_id            => i_erm_id,
                  i_find_slots_bln    => l_find_slots_bln,
                  o_r_syspars         => l_r_syspars);

      show_syspars(l_r_syspars);
      log_syspars(l_r_syspars, i_erm_id);

      --
      -- Build the last of pallets to find slots for which will be stored in a
      -- table of PL/SQL records.  At the same time the pallet list is built a
      -- table of PL/SQL records of the item info is built.
      --
      IF (    l_find_slots_bln         = TRUE
          AND i_use_existing_tasks_bln = TRUE)
      THEN
         --
         -- Live Receiving.
         -- Build the list from existing putawaylst records.  This implies
         -- the PO was first opened with the putawaylst.dest_loc set to 'LR'.
         --
         pl_rcv_open_po_lr.build_pallet_list_from_tasks
              (i_r_syspars          => l_r_syspars,
               i_erm_id             => i_erm_id,
               i_pallet_id          => i_pallet_id,
               o_r_item_info_table  => l_r_item_info_table,
               o_r_pallet_table     => l_r_pallet_table);
      ELSE
         pl_rcv_open_po_pallet_list.build_pallet_list
              (l_r_syspars,
               i_erm_id,
               l_r_item_info_table,
               l_r_pallet_table);
      END IF;

      pl_rcv_open_po_pallet_list.show_pallets(l_r_pallet_table);

      --
      -- Assign slots to the pallets.
      -- But if "live receiving" is active and it is a PO and we are not
      -- at the point of finding slots for the live receiving pallets then
      -- only create the putaway task with the dest_loc set to 'LR'.
      -- Added type TR as well to include outside process POs
      --
      -- Jira 438
      -- If the PO is an internal PO, do NOT use LR logic.
      -- Use the direct_pallet_to_slots logic
      --

      IF (  l_r_syspars.enable_live_receiving = 'Y' AND
            l_find_slots_bln = FALSE AND 
            l_erm_type in ('PO', 'TR', 'FG')
        ) THEN

         pl_rcv_open_po_lr.create_putaway_task
                               (i_r_syspars         => l_r_syspars,
                                i_r_item_info_table => l_r_item_info_table,
                                io_r_pallet_table   => l_r_pallet_table);
      ELSE
         --
         -- 02/15/@017 Brian Bent Added call to "lock_putaway_find_slot_process"
         -- for Live Receiving
         --
         lock_putaway_find_slot_process;

         direct_pallets_to_slots(l_r_syspars,
                                 i_erm_id,
                                 l_r_item_info_table,
                                 l_r_pallet_table);
      END IF;
   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || ': Parameter i_erm_id is null';

         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         o_crt_msg := l_message;
         io_error_bln := TRUE;

      WHEN e_error_with_msku THEN
         l_message := l_object_name || '(i_erm_id[' || i_erm_id || '])';

         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         io_error_bln := TRUE;

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_erm_id[' || i_erm_id || '])';
         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         o_crt_msg := l_message || ' ' || SUBSTR(SQLERRM, 1, 200);
         io_error_bln := TRUE;
   END;

   --
   -- Clear the data.
   --
   l_r_item_info_table.DELETE;
   l_r_pallet_table.DELETE;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_erm_id,io_error_bln,o_crt_msg)'
         || '  i_erm_id[' || i_erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                       l_object_name || ': ' || SQLERRM);
END find_slot;


---------------------------------------------------------------------------
-- Procedure:
--    find_slot
--
-- Description:
--    This procedure finds and assigns the putaway slots for a PO/SN
--    allowing the syspars to be passed as a parameter.
--
--    README     README     READDME
--    README     README     READDME
--    03/20/2017   Brian Bent  This was never implented thus this
--                             procedure never gets called.
--                             But we will leave it as maybe one day
--                             we will implement it ???
--
-- Parameters:
--    i_erm_id        - PO#/SN# to find the slots for.
--    io_error_bln    - Designates if an error occurred opening the PO/SN/
--    o_crt_msg       - Error message to display on the CRT if an error
--                      occurs.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - pallet_label2.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/10/05 prpbcb   Created  Not used.
---------------------------------------------------------------------------
PROCEDURE find_slot
           (i_erm_id      IN     erm.erm_id%TYPE,
            i_r_syspars   IN     pl_rcv_open_po_types.t_r_putaway_syspars,
            io_error_bln  IN OUT BOOLEAN,
            o_crt_msg     OUT    VARCHAR2)

IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'find_slot';

   l_crt_message        VARCHAR2(512); -- Message to display on the CRT
                                       -- if an error occurs.
   l_dummy              VARCHAR2(1);  -- Work area
   l_dummy_parents      pl_msku.t_parent_pallet_id_arr; -- Holding area.
   l_error_bln          BOOLEAN;
   l_r_item_info_table  pl_rcv_open_po_types.t_r_item_info_table;
   l_r_pallet_table     pl_rcv_open_po_types.t_r_pallet_table;
   l_r_syspars          pl_rcv_open_po_types.t_r_putaway_syspars;  -- Syspars

   e_error_with_msku    EXCEPTION;
BEGIN

   BEGIN
      l_message := l_object_name || '(i_erm_id[' || i_erm_id || ']'
            || ', io_error_bln, o_crt_msg)';

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      --
      -- Check for null parameters.
      --
      IF (i_erm_id IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      --
      -- Initialization
      --
      l_error_bln := FALSE;

      --
      -- If processing a SN then assign slots to MSKUs first.
      --
      BEGIN
         SELECT 'x' INTO l_dummy
           FROM erm
          WHERE erm.erm_id = i_erm_id
            AND erm_type   = 'SN';

         pl_msku.p_assign_msku_putaway_slots(i_erm_id,
                                             l_dummy_parents,
                                             l_error_bln,
                                             l_crt_message);
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
      END;

      IF (l_error_bln = TRUE) THEN
         o_crt_msg := l_crt_message;
         RAISE e_error_with_msku;
      END IF;

      --
      -- Retrieve the relevant syspars.
      --
      get_putaway_syspars
                 (i_erm_id      => i_erm_id,
                  o_r_syspars   => l_r_syspars);

      show_syspars(l_r_syspars);
      log_syspars(l_r_syspars, i_erm_id);

      override_syspars(i_erm_id, i_r_syspars, l_r_syspars);

      --
      -- Build the last of pallets to find slots for which will be stored in a
      -- table of PL/SQL records.  At the same time the pallet list is built a
      -- table of PL/SQL records of the item info is built.
      --
      pl_rcv_open_po_pallet_list.build_pallet_list(l_r_syspars,
                                                   i_erm_id,
                                                   l_r_item_info_table,
                                                   l_r_pallet_table);

      pl_rcv_open_po_pallet_list.show_pallets(l_r_pallet_table);

      --
      -- Assign slots to the pallets.
      --
      direct_pallets_to_slots(l_r_syspars,
                              i_erm_id,
                              l_r_item_info_table,
                              l_r_pallet_table);

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '  Parameter i_erm_id is null';

         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         o_crt_msg := l_message;
         io_error_bln := TRUE;

      WHEN e_error_with_msku THEN
         l_message := l_object_name || '(i_erm_id[' || i_erm_id || '])';

         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         io_error_bln := TRUE;

      WHEN OTHERS THEN
         l_message := l_object_name || '(i_erm_id[' || i_erm_id || '])';

         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);

         o_crt_msg := l_message || ' ' || SUBSTR(SQLERRM, 1, 200);
         io_error_bln := TRUE;
   END;

   --
   -- Clear the data.
   --
   l_r_item_info_table.DELETE;
   l_r_pallet_table.DELETE;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_erm_id,i_r_syspars,io_error_bln,o_crt_msg)'
         || '  i_erm_id[' || i_erm_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                       l_object_name || ': ' || SQLERRM);

END find_slot;



---------------------------------------------------------------------------
--  Procedure:
--      open_internal_po
--
--  Description:
--      This procedure is called from the open_internal_po.sh cronjob. If the  
--      ENABLE_FINISH_GOODS syspar for this company is set to Y, then it will try to open
--      any internal productions POs by passing in a condition to TP_wk_seet2 that checks if 
--      the ERM.SOURCE_ID exists in the VENDOR_PIT_ZONE table.
--
--  Called by:
--      open_internal_po.sh cronjob
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/23/18 mpha8134 Created to be called from cronjob
--    01/21/19 mpha8134 Changing from the SPECIALTY_VENDOR_ID syspar to checking
--                      if it exists in the VENDOR_PIT_ZONE table.   
---------------------------------------------------------------------------
PROCEDURE open_internal_po
IS
    l_message swms_log.msg_text%TYPE;
    l_object_name   VARCHAR2(30) := 'open_internal_po';
    l_vendor_id erm.source_id%TYPE;
    l_host_str VARCHAR2(255);
    l_host_rc VARCHAR2(500); -- Return code from HOST_COMMAND call
BEGIN
    
   IF (pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y') THEN

      l_host_str := 'nohup TP_wk_sheet2 "trunc(ship_date) - 1 <= trunc(sysdate) and source_id in (select distinct vendor_id from vendor_pit_zone)"';

      --
      -- Call TP_wk_sheet2 
      --
      l_host_rc := DBMS_HOST_COMMAND_FUNC('swms', l_host_str);
      
      l_message := 'After TP_wk_sheet2 call using: "' || l_host_str || '".  Host command return code:' || l_host_rc;
      pl_log.ins_msg(
         pl_log.ct_info_msg,
         l_object_name,
         l_message,
         SQLCODE,
         SQLERRM,
         pl_rcv_open_po_types.ct_application_function,
         gl_pkg_name);
   END IF;

END open_internal_po;


END pl_rcv_open_po_find_slot;  -- end package body
/


