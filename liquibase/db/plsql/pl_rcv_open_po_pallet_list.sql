CREATE OR REPLACE PACKAGE swms.pl_rcv_open_po_pallet_list
AS

---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_pallet_list
--
-- Description:
--    This package has the objects used IN creating the list of pallets on
--    the PO/SN as part of the open PO/SN process.
--
--    The packages used IN the open PO/SN process are:
--       - pl_rcv_open_po_types
--       - pl_rcv_open_po_cursors
--       - pl_rcv_open_po_pallet_list
--       - pl_rcv_open_po_find_slot
--
--    The basic process flow is to build a list of the pallets on the PO/SN,
--    which is stored IN a PL/SQL table, then direct the pallets to slots.
--    This package builds the list.  Package pl_rcv_open_po_find_slot is the
--    driving package which calls objects IN this package to build the
--    pallet list then will direct the pallets to slots.
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
--                      Project: CMBFS-Combine floating slots for non-fIF
--
--    09/01/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Fixes to bugs found by SQ.
--
--    09/11/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Fixes to bugs found by SQ.
--
--                      Populate new field direct_only_to_open_slot_bln IN
--                      the pallet record.
--
--    09/11/05 prpbcb   Oracle 8 rs239b swms9 DN
--                      Bug fixes.
--
--                      IN calc_pallet_size statement
--          IF (io_r_pallet_table(i_pallet_index).cube_without_skid != 1) THEN
--                     should have been
--          IF (io_r_pallet_table(i_pallet_index).uom != 1) THEN
--
--                      Procedures build_pallet_list_from_po() and
--                      build_pallet_list_from_sn() were forcing aging items
--                      to go to open slots by setting
--          o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln
--                      to TRUE for an aging item.  Aging items need to
--                      follow the regular logic.  They just cannot go to
--                      the home slot.
--
--
--    09/13/05 prpbcb   Oracle 8 rs239b swms9 DN  12000
--                      Bug fixes.
--
--                      The case home slot slot TYPE was not being assigned
--                      to the item record IN procedure get_item_info().
--                      Added:
--       io_r_item_info_table(l_index).case_home_slot_slot_type :=
--                                               r_case_home_slot.slot_type;
--
--                      ModIFied procedure get_item_info() to turn off
--                      extended case (IF it was on) for an item when the
--                      case home slot cube is >= 900.  This 900 is a "magic"
--                      value.  This follows the logic IN pallet_label2.pc
--                      It had been left out IN this program.
--
--    09/27/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
--                      Bug fixes.
--                      ModIFied to use the rank 1 case home as the
--                      pallet TYPE for the item for a slotted item.
--                      pm.pallet_type should be the same as the rank 1
--                      case home pallet TYPE but IF they are dIFferent
--                      the home slot pallet TYPE is used.  The pallet TYPE
--                      affects what candidate slots are selected when
--                      syspar "Pallet TYPE Flag" is Y.
--
--    11/29/05 prpbcb   Oracle 8 rs239b swms9 DN 12043
--
--                      Ticket: 82078
--                      The magic cube was being ignored for floating items.
--                      Changed procedure get_item_info() to look at the magic
--                      cube when processing a floating item.  See history
--                      for 09/13/05 for an explanation of the "magic" cube.
--
--                      Show the tracking flags IN the item information log
--                      message.
--
--    01/20/06 prpbcb   Oracle 8 rs239b swms9 DN 12048
--                      WAI changes.
--                      Added selecting the split zone id, auto ship flag,
--                      miniloader storage indicator, case induction location
--                      and split induction location to cursor c_item_info.
--                      End of WAI changes.
--
--                      Round cube of the pallet to putaway to 2 decimal places
--                      to resolve rounding issue that at times resulted IN the
--                      pallet cube being slightly larger than one position IN
--                      the home slot when using extended case cube.
--                      Note:  The data TYPE for field case_cube_for_calc was
--                             changed from pm.case_cube%TYPE to NUMBER which
--                             was another change to resolve the rounding issue.
--
--                      ModIFied procedure get_item_info() to populate fields
--                         - case_home_slot_deep_positions
--                         - case_home_slot_width_positions
--                         - case_home_slot_total_positions
--                      IN the item record.
--
--                      Moved cursor c_loc_info to pl_rcv_open_po_cursors.sql.
--
--                      Changed the swms log messages to always have the
--                      PO/SN.  This required adding the PO/SN number to the
--                      parameter list for some of the functions/procedures.
--
--                      ModIFied procedure get_item_info() to populate field
--                      "partial_nondeepslot_search" IN the item info record.
--                      This field controls the slot search order for partial
--                      pallets going to non-deep reserve slots.  See
--                      procedure
--                 pl_rcv_open_po_find_slot.set_partial_nondeepslot_search()
--                      for more information.
--
--    03/24/06 prpbcb   Oracle 8 rs239b swms9 DN 12078
--                      WAI changes.
--                      Added assignment of the pallet record inv_uom based
--                      on the receiving uom (erd.uom) and the item's
--                      storage indicator (pm.miniload_storage_ind).
--                      Before the assignment was IN package
--                      pl_rcv_open_po_ml so the pallet record inv_uom was
--                      null for anything not going to the mini-loader.  Now
--                      it is populated for each pallet.  To do this procedure
--                      procedure calc_pallet_size() was renamed to
--                      determine_pallet_attributes() and the assignment
--                      of the pallet record inv_uom was added.
--                      End WAI changes.
--
--    06/01/06 prpbcb   Oracle 8 rs239b swms9 DN 12087
--                      WAI changes.
--                      Added addtional item info written to SWMS_LOG
--                      IN procedure get_item_info().
--
--    06/07/06 prpbcb   Oracle 8 rs239b swms9 DN 12097
--                      Changed statement
--       IF (io_r_item_info_table(l_index).last_ship_slot_cube IS NULL) THEN
--                      to
--       IF (io_r_item_info_table(l_index).last_ship_slot IS NULL) THEN
--                      IN procedure get_item_info().
--                      last_ship_slot_cube would always be not null because
--                      IN is initialized to 0 IN the record declaration.
--                      This could have caused some unexpected results IF
--                      the last ship slot was null.
--
--    02/22/07 prpbcb   DN 12214
--                      Ticket: 326211
--                      Project: 326211-Miniload Induction Qty Incorrect
--
--                      The current f_get_new_pallet_id was moved to
--                      pl_common.sql and function f_get_new_pallet_id IN
--                      this package was changed to call
--                      pl_commmon.f_get_new_pallet_id.
--
--    03/26/07 prpbcb   DN 12214
--                      Ticket: 326211
--                      Project: 326211-Miniload Induction Qty Incorrect
--                      DN, ticket and project same as previous change.
--
--                      Found bug during testing.   Cursor c_item_info
--                      had some fields moved around but the select into
--                      stmt was not changed.  This is fixed.
--
--    05/01/07 prpbcb   DN 12235
--                      Ticket: 265200
--                      Project: 265200-Putaway By Inches ModIFications
--
--                      Implement logic for pm.pallet_stack.  It was missed
--                      when pallet_label2.pc was converted to PL/SQL.
--
--                      Added constant ct_default_case_height and set it
--                      to 99.
--                      IN procedure get_item_info() changed
--                      NVL(pm.case_height, 1) to
--                        DECODE(pm.case_height,
--                               NULL, ct_default_case_height
--                               0, ct_default_case_height,
--                               pm.case_height)
--                      to get the pallet to '*' (unless there are some
--                      really tall slots) when putaway is by inches and
--                      the case has no height.
--
--                      IN procedure get_itme_info() added populating
--                      "pt_putaway_floating_by_max_qty" and "pallet_stack"
--                      IN the item record.
--
--                      Start changing the pl_log messages to pass the
--                      application function and program name on the
--                      command line.
--
--                      Populate max_qty_in_splits IN the item record.
--
--                      Change procedure determine_pallet_attributes() to
--                      populate cube_for_home_putaway and
--                      pallet_height_for_home_putaway IN the pallet record.
--
--    01/03/07 prpbcb   DN 12317
--                      Project: 339513-Miniload Proforma Correction
--                      Changed cursor c_item_info to use '*' for the
--                      induction location IF null.  This it to handle
--                      the situation where it is a miniloader item but the
--                      induction location was not entered for the zone.
--                      Before when this happened the putawaylst.dest_loc
--                      was null.  Now it will be a '*'.
--                      A non-miniload item does not use the induction
--                      location.
--
--    01/28/08 prpbcb   DN 12345
--                      Project: 339513-Miniload Proforma Correction
--                      Set the inv_uom to 1 for a ship split only item
--                      received as cases that is going to the miniloader
--                      induction location.  This item will be inducted
--                      as splits as the expected receipt sent to the
--                      miniloader will have a uom of 1.  We want to
--                      induct as splits as this item will always be shipped
--                      to customers as splits thus we select splits.
--                      Setting the inv_uom to 1 will allow split
--                      inventory adjustments for the LP at the induction
--                      location.  We have received tickets asking for
--                      the inv_uom for inventory at the induction location
--                      to be changed from 2 to 1 so the user can adjust
--                      splits so this change will allow the user to make
--                      the adjustment.
--
--
--    03/02/09 prpbcb   DN 12466
--                      Incident: 121256
--                      CR: 6799
--                      Project: CRQ000000006799-Pallet Not Fit IN Home Slot
--
--                      Fix bug IN procedure build_pallet_list_from_sn()
--                      that was calling procedure
--                      determine_pallet_attributes() before setting
--                        o_r_pallet_table(l_pallet_index).partial_pallet_flag
--                      Procedure determine_pallet_attributes() looks at the
--                      setting of partial_pallet_flag when determining
--                      cube_for_home_putaway and
--                      pallet_height_for_home_putaway
--                      of the receiving pallet so these were set incorrectly.
--                      This could result IN a receiving pallet directed to
--                      the home slot which would not fit.
--                      I moved setting partial_pallet_flag before calling
--                      determine_pallet_attributes().
--
--    03/13/09 prpbcb   DN 12474
--                      Incident:
--                      Project: CRQ7373-Split SN pallet IF over SWMS Ti Hi
--
--                      Implement logic to split RDC SN pallet IF the qty is
--                      over the SWMS Ti Hi.  The qty on the SN pallet will be
--                      reduced to the SWMS Ti Hi and the quantity over the
--                      SWMS Ti Hi will be put on a new pallet when the qty
--                      on the SN pallet is greater than the SWMS Ti Hi.
--                      IF the item is expiration date tracked and the new
--                      pallet is made up of cases from dIFferent SN pallets
--                      with dIFferent expiration then the oldest expiration
--                      date is used for the new pallet.  Same thing applies
--                      for a manufacturer date tracked item.
--                      Syspar SPLIT_RDC_SN_PALLET control this.
--
--                      Created procedures:
--                         - build_pallet_list_from_sn_splt()
--                              Created by copying and modIFying
--                              build_pallet_list_from_sn().
--                         - build_additional_pallets()
--
--                      ModIFied procedure build_pallet_list() to call
--                      build_pallet_list_from_sn_splt() IF syspar
--                      SPLIT_RDC_SN_PALLET is Y.
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
--    03/20/09 prpbcb   DN 12474
--                      Project: CRQ7373-Split SN pallet IF over SWMS Ti Hi
--
--                      Fixing bugs found during testing.  The pallet
--                      catchweight was not divided up correctly among
--                      pallets when the SN pallet was split.
--
--    04/14/09 prpbcb   DN 12491
--                      Project:
--                          CRQ8439-Transfer PO into WH with inch turned on
--
--                      Change to handle a transfer request from outside
--                      storage to the main warehouse.
--                      IN procedure build_pallet_list() changed
--                         IF (l_erm_type = 'PO') THEN
--                      to
--                         IF (l_erm_type  IN ('PO', 'TR')) THEN
--
--                      IN procedure build_pallet_list_from_po() changed
--                      where clause IN cursor c_erd from
--                         AND erm.status          IN ('NEW', 'SCH')
--                      to
--                         AND erm.status          IN ('NEW', 'SCH', 'TRF')
--
--    04/30/09 prpbcb   DN 12500
--                      Project:
--                   CRQ9069-QTY Received not sent to SUS for SN pallet split
--
--                      Fix bugs when splitting SN pallet.
--                      IN procedure build_additional_pallets() the
--                      sn_no was not being populated and po_no was being set
--                      to the SN for the new pallet being created.
--
--                      Create log messages to show showing how the SN pallet
--                      was split.
--                      The messages will look something like this:
--           SN pallet ___ split into ___ new pallet(s).
--           Original SN pallet qty: ___  Exp Date: ___  Mfg Date: ___
--           The new pallets are:
--           New pallet: ___  Qty: ___  Exp Date: ___  Mfg Date: ___
--           ......
--
--           New pallet ______ created from SN pallet(s):
--           New pallet qty: ___  Exp Date: ___  Mfg Date: ___
--           The SN pallets the new pallet was created from are:
--           SN pallet: ___  Qty: ___  Exp Date: ___  Mfg Date: ___
--           ...  ...
--
--    06/05/09 prpbcb   DN 12505
--                      Project: CRQ9582-Split SN pallet log messages
--                      More work on the log messages when splitting
--                      a SN pallet.
--                      This is what the log message looks like:
--
--           SN ______  SN LP _____ split.  __ case(s) moved to LP ______
--
--                      I simplIFied what I put IN the comments above for
--                      04/30/09.  The log message format could change once
--                      the splitting of the SN LP goes into production.
--
--
--    10/19/09 ctvgg000 Changed for ASN to all OPCOs project
--          A VSN (ASN) will be shipped with pallets already
--          built by the vendor, similar to an SN from RDC.
--          Hence treat VSN like an SN only for building
--          pallets. IN build_pallet_list function, the IF
--          condition will modIFied to include 'VN' as below,
--          erm_type IN ('VN', 'SN')
--
--    11/06/09 prpbcb   Added AUTHID CURRENT_USER so things work correctly
--                      when pre-receiving into the new warehouse for a
--                      warehouse move.
--
--    12/17/09 prpbcb   DN 12533
--                      Removed AUTHID CURRENT_USER.  We found a problem IN
--                      pl_rcv_open_po_cursors.f_get_inv_qty when using it.
--
--    04/01/10 ctvgg000 DN 12572 Changed function build_pallet_list_from_sn.
--          Included a union to cursor c_sn_line_item to select
--          VNs related pallet information from the ERD LPN
--          table and do not consider the ERD table as it might
--          have a the dIFferent PO line number than what is IN
--          IN ERD_LPN.
--
--    06/08/10 ctvgg000 DN 12587 Changed fn build_pallet_list_from_sn_splt.
--          Included a union to cursor c_sn_line_item to select
--          VNs related pallet information from the ERD LPN
--          table and do not consider the ERD table as it might
--          have a the dIFferent PO line number than what is IN
--          IN ERD_LPN.
--
--    01/07/10 vgur0337 Added new procedure to optimize pallet split for
--                      VSN's. This procedure distributes cases from
--                      vendor pallets having qty over swms tihi to
--                      partial vendor pallets (pallets with qty under
--                      swms tihi).
--                      New procedure - pallet_split_optimize.
--
--    10/17/12 prpbcb  Activty: Activity: CRQ39909-Putaway_by_min_qty
--                     Project: Activity: CRQ39909-Putaway_by_min_qty
--
--                     Change putaway by max qty logic to use the min qty
--                     as the threshold to send pallets to the home slot.
--                     The rules are:
--                     - IF the qty IN the home slot is <= min qty
--                       then direct the receiving pallet to the home slot.
--                     - IF the qoh IN the home slot plus the receiving
--                       pallet qty is < max qty then direct the receiving
--                       pallet to the home slot.
--
--                     NOTE: FIFO rules always apply
--
--                     Added populating the following fields IN the item
--                     record:
--                        - min_qty
--                        - min_qty_in_splits
--                        - putaway_to_home_slot_method
--                             Values can be: Y - by min/max qty
--                                            N - Normal processing
--                                            NULL  - Normal processing
--                     Field "pt_putaway_use_repl_threshold" IN the item
--                     record will not be used anymore since the name is
--                     somewhat confusing.  But we will still take the value
--                     for "putaway_to_home_slot_method"
--                     from column PALLET_TYPE.PUTAWAY_USE_REPL_THRESHOLD.
--                     Maybe at some time we can change the column name
--                     from PUTAWAY_USE_REPL_THRESHOLD to something more
--                     IN line with what it means.
--
--                     Populate the pallet record erm_line_id.
--
--    08/07/14 sred5131  Added Matrix logic for symbotic.
--    09/17/14 vred5319   Modified for Symbotic/Matrix Project 
--
--    03/24/15 bben0556 Symbotic project.
--        R30.0 Symbotic/Matrix_Project-Split_repl_caused_rcv_pallet_to be_directed_to_main_whse
--
--                      Procedure "get_mx_item_inventory" was including
--                      replenishments from the matrix to the split home
--                      as case inventory in the main warehouse so the open
--                      PO process sent the receiving palllet to main
--                      warehouse reserve instead of the matrix.
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
--                     Modified procedure "get_item_info" to populate field
--                     'full_plt_minimize_option" in the item PL/SQL record.
--                   
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/14/16 bben0556 Brian Bent
--                      Project:
--            R30.6--WIE#669--CRQ000000008118_Live_receiving_story_15_cron_open_PO
--
--                      Add functionality to find the slot for the putaway
--                      tasks created by Live Receiving.  When the Live
--                      Receiving syspar is active and a PO is opened
--                      only the putaway tasks are created with the 
--                      dest loc set to 'LR'.  No inventory is created.
--                      The dest loc and the inventory is created for the
--                      pallet is found at during check-in.
--
--    09/28/16 bben0556 Brian Bent
--                      Project:
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_33_find_dest_loc
--
--                      Populate qty_expected and qty_recieived in the 
--                      pallet records. These are new fields in the
--                      pallet record.  Intially qty, qty_expected and
--                      qty_recieived all set to the quantity on the pallet.
--                      Live Receiving check-in in the RF can change the
--                      quantity received which is the quantity we want
--                      to use when find the putaway location for a live
--                      receiving pallet.
--
--                      Changed to use the pallet list record qty received
--                      instead of the qty.
--                      We want to use the actual qty on the pallet.
--                      This comes into play when checking-in a live
--                      receiving pallet on the RF.  Otherwise the pallet list
--                      record qty and qty_received are the same.
--
--    02/06/17 bben0556 Brian Bent
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_276_lock_records_when_finding_putaway_dest_loc
--
--                      There was a COMMIT  procedure "pallet_split_optimize()"
--                      I commented it out.  We should not have any commits
--                      in this package.   FYI-At this time "pallet_split_optimize()"
--                      is never called.
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
--	03/08/21	sban3548 OPCOF-3339: Removed "magic" number used in the putaway find slot logic 
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/11/22 bben0556 Brian Bent
--                      Card: R50_0_DML_OPCOF-3872_BUG_Miniload_items_asterisk_when_directed_to_main_whse_reserve
--                      Bug fix.
--                      Will re-implement the magic cube using a syspar.
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
--                      Changed procedure "get_item_info" to populate to look at i_r_syspars.extended_case_cube_cutoff_cube
--                      to off extended case cube.
--
--
---------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public TYPE Declarations
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

FUNCTION f_boolean_text(i_boolean IN BOOLEAN)
RETURN VARCHAR2;

FUNCTION f_get_cust_staging_loc (
    i_cust_id IN erd.cust_id%TYPE, 
    i_sort_ind IN CHAR
)
RETURN VARCHAR2;

FUNCTION f_get_pit_location(i_vendor_id IN erm.source_id%TYPE)
RETURN VARCHAR2;



---------------------------------------------------------------------------
-- Prosedure
--   get_item_ml_capacity
--
-- Description
--   The proceure returns the number of splits of an item that can still be
--   stored IN the minload.  It also returns the number of splits IN the one
--   miniload carrier overflow allowance.
---------------------------------------------------------------------------
Procedure get_item_ml_capacity(
    i_item_info     IN  pl_rcv_open_po_types.t_r_item_info,
    o_ml_capacity Out PLS_INTEGER,
    o_ml_overflow OUT PLS_INTEGER);


---------------------------------------------------------------------------
-- Procedure:
--    get_mx_item_inventory
--
---------------------------------------------------------------------------
PROCEDURE get_mx_item_inventory
   (i_r_item_info              IN  pl_rcv_open_po_types.t_r_item_info,
    i_erm_id                   IN  erm.erm_id%TYPE,
    o_mx_qty_in_splits         OUT PLS_INTEGER,                          -- VR                  
    o_warehouse_qty_in_splits  OUT PLS_INTEGER);                         -- VR 

PROCEDURE determine_pallet_attributes
     (i_r_item_info       IN            pl_rcv_open_po_types.T_R_Item_Info,
      i_pallet_index      IN            PLS_INTEGER,
      io_r_pallet_table   IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);


PROCEDURE show_item_info
           (i_index             IN PLS_INTEGER,
            i_r_item_info_table IN pl_rcv_open_po_types.t_r_item_info_table);


PROCEDURE get_item_info
  (i_r_syspars          IN     pl_rcv_open_po_types.t_r_putaway_syspars,
   i_prod_id            IN     pm.prod_id%TYPE,
   i_cust_pref_vendor   IN     pm.cust_pref_vendor%TYPE,
   i_erm_id             IN     erm.erm_id%TYPE,
   o_index              IN Out PLS_INTEGER,
   io_r_item_info_table IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table);

PROCEDURE build_pallet_list_from_po
    (i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
     i_erm_id             IN  erm.erm_id%TYPE,
     o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
     o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);

PROCEDURE build_pallet_list_from_sn
      (i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
       i_erm_id             IN  erm.erm_id%TYPE,
       o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
       o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);

PROCEDURE log_how_sn_pallet_split
 (i_r_how_sn_pallet_split_table  IN
                        pl_rcv_open_po_types.t_r_how_sn_pallet_split_table,
  i_r_item_info_table        IN pl_rcv_open_po_types.t_r_item_info_table,
  i_r_pallet_table           IN pl_rcv_open_po_types.t_r_pallet_table,
  i_erm_id                   IN erm.erm_id%TYPE);

PROCEDURE build_additional_pallets
    (io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     io_seq_no                   IN OUT PLS_INTEGER,
     i_r_item_info               IN     pl_rcv_open_po_types.t_r_item_info,
     i_qty_over_ti_hi_in_splits  IN     NUMBER,
     i_oldest_exp_date           IN     DATE,
     i_oldest_mfg_date           IN     DATE,
     i_new_lp_catch_weight       IN     NUMBER,
     i_last_sn_pallet_exp_date   IN     DATE,
     i_last_sn_pallet_mfg_date   IN     DATE,
     io_r_how_sn_pallet_split_table  IN OUT NOCOPY
                           pl_rcv_open_po_types.t_r_how_sn_pallet_split_table,
     i_sn_pallet_index           IN     PLS_INTEGER,
     i_erm_id                    IN     erm.erm_id%TYPE);

PROCEDURE build_pallet_list_from_sn_splt
      (i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
       i_erm_id             IN  erm.erm_id%TYPE,
       o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
       o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);

PROCEDURE build_pallet_list_from_prod_po (
    i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
    i_erm_id             IN  erm.erm_id%TYPE,
    o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
    o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);

---------------------------------------------------------------------------
-- Procedure:
--    show_pallets
--
-- Description:
--    Output the pallets IN the pallet plslq table.  Used for debugging.
---------------------------------------------------------------------------
Procedure Show_Pallets
              (i_r_pallet_table  IN pl_rcv_open_po_types.t_r_pallet_table);


---------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list
--
-- Description:
--    This procedure builds the list of pallets to putaway.
--    Each pallet is a record IN PL/SQL table o_r_pallet_table.
---------------------------------------------------------------------------
PROCEDURE build_pallet_list
     (I_R_Syspars          IN  pl_rcv_open_po_types.T_R_Putaway_Syspars,
      i_erm_id             IN  erm.erm_id%TYPE,
      o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
      o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);


---------------------------------------------------------------------------
-- Function:
--    save_erd_to_erd_case
--
-- Description:
--    This procedure builds will populate the erd_case table with the erd
--    lines for a produced item PO
---------------------------------------------------------------------------
FUNCTION save_erd_to_erd_case (
    i_erm_id IN erm.erm_id%TYPE
) RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Procedure:
--    build_erd_from_erd_case
--
-- Description:
--    This procedure takes the combines the cases from ERD_CASE table and
--    inserts them into the ERD table
---------------------------------------------------------------------------
PROCEDURE build_erd_from_erd_case (
    i_erm_id IN erm.erm_id%TYPE
);


---------------------------------------------------------------------------
--  Procedure:
--      assign_finish_good_item_to_flt
--  
--  Description:
--      If the item on the production PO is not slotted to a floating
--      zone, then we will auto assign it to a floating zone based off
--      of the pm.area to look for corresponding zone in that area.
---------------------------------------------------------------------------
PROCEDURE assign_finish_good_item_to_flt(i_erm_id IN erm.erm_id%TYPE);


---------------------------------------------------------------------------
-- Procedure
--   pallet_split_optimize
--
-- Description
--   This procedure distributes cases from VSN pallets having qty over swms
--   tihi to partial VSN pallets of the same item (pallets with qty under
--   swms tihi(partial pallets).
--
-----------------------------------------------------------------------------

Procedure Pallet_Split_Optimize (i_erm_id IN erm.erm_id%TYPE);

END pl_rcv_open_po_pallet_list;  -- end package specIFication
/



CREATE OR REPLACE PACKAGE BODY swms.pl_rcv_open_po_pallet_list
AS

---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_pallet_list
--
-- Description:
--    This package has the objects used IN creating the list of pallets on
--    the PO/SN as part of the open PO/SN process.
--
--    The packages used IN the open PO/SN process are:
--       - pl_rcv_open_po_types
--       - pl_rcv_open_po_cursors
--       - pl_rcv_open_po_pallet_list
--       - pl_rcv_open_po_find_slot
--
-- ModIFication History:
--    Date     Designer   Comments
--    -------- --------   ---------------------------------------------------
--    08/10/05 prpbcb     Oracle 8 rs239b swms9 DN _____
--                        Created.
--                        Putaway by cube and inches have been combined
--                        into one set of packages.
--    08/07/14 sred5131   Added Matrix logic for symbotic.
--    09/17/14 vred5319   Modified for Symbotic/Matrix Project
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private TYPE Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_rcv_open_po_pallet_list';  -- Package name.
                                                 -- Used IN error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------



--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------
-- OPCOF-3339: Removed "magic" number used in the putaway find slot logic 
-- OPCOF-3872: 01/11/2021 Brian Bent  Re-implement the extended case magic cube using a new syspar--EXTENDED_CASE_CUBE_CUTOFF_CUBE
-- ct_ext_case_cube_magic_num CONSTANT NUMBER := 900;  -- A case home slot with  a cube >= this value
                                                       -- turns off extended case cube for that item.

ct_default_case_height CONSTANT NUMBER := 99;  -- Case height used IF 0 or null
                                               -- IN the database.

---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

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
-- Modification History:
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
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END f_boolean_text;


---------------------------------------------------------------------------
--  Function:
--      f_get_pit_location
--
--  Description:
--      This function will use the erm.source_id (vendor ID) to find a Pit
--      location in a Pit Zone (rule 11) from the vendor_pit_zone table.
--
--  Modification History
--  Date        Designer    Comments
--  --------    --------    -----------------------------------------------
--  01/18/19    mpha8134    Created.
---------------------------------------------------------------------------
FUNCTION f_get_pit_location(i_vendor_id IN erm.source_id%TYPE)
RETURN VARCHAR2
IS
    l_message VARCHAR2(256);
    l_object_name VARCHAR2(61) := 'f_get_pit_location';
    l_location loc.logi_loc%TYPE;
BEGIN

    SELECT logi_loc
    INTO l_location
    FROM lzone
    WHERE zone_id in (select zone_id from vendor_pit_zone where vendor_id = i_vendor_id)
    and rownum <= 1;

    RETURN l_location;

EXCEPTION
    WHEN OTHERS THEN
        l_message := 'Error getting location from lzone and vendor_pit_zone. Vendor ID:' || i_vendor_id;
        pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, 
            SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

        RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);

END f_get_pit_location;


---------------------------------------------------------------------------
--  Function:
--      f_get_cust_staging_loc
--
--  Description:
--      This function will get the customer staging location for the given
--      cust_id. Returns NULL if not found in the inbound_cust_setup table
--      for inbound_type 'BUILD_TO_PALLET'.
--
---------------------------------------------------------------------------
FUNCTION f_get_cust_staging_loc(
    i_cust_id IN erd.cust_id%TYPE,
    i_sort_ind IN CHAR
)
RETURN VARCHAR2
IS
    l_message swms_log.msg_text%TYPE;
    l_object_name VARCHAR2(256) := 'f_get_cust_staging_loc';
    l_location loc.logi_loc%TYPE;
BEGIN
    
    SELECT DECODE(
        i_sort_ind,
        'B', staging_loc,
        'C', rack_cut_loc,
        'W', willcall_loc,
        NULL
    )
    INTO l_location
    FROM inbound_cust_setup
    WHERE cust_id = i_cust_id;
    
    IF l_location is NULL THEN
        raise NO_DATA_FOUND;
    END IF;

    RETURN l_location;

EXCEPTION 
    WHEN NO_DATA_FOUND THEN
        -- If No data was found, then use the locations from the  DEFAULT customer
        SELECT DECODE(
            i_sort_ind,
            'B', staging_loc,
            'C', rack_cut_loc,
            'W', willcall_loc,
            NULL
        )
        INTO l_location
        FROM inbound_cust_setup
        WHERE cust_id = 'DEFAULT';

        RETURN l_location;

    WHEN OTHERS THEN
        l_message := 'Error getting staging_loc from inbound_cust_setup. cust_id[' || i_cust_id || ']';
        pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, 
            SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
        
        RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);

END f_get_cust_staging_loc;

---------------------------------------------------------------------------
-- Procedure:
--    get_item_ml_capacity
--
-- Description
--   The proceure returns the number of splits of an item that can still be
--   stored IN the miniload.  It also returns the number of splits IN the one
--   miniload carrier overflow allowance.
--
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/02/09 prswp000 Created.
--
---------------------------------------------------------------------------
PROCEDURE get_item_ml_capacity(
      i_item_info      IN  pl_rcv_open_po_types.t_r_item_info,
      o_ml_capacity OUT PLS_INTEGER,
      o_ml_overflow OUT PLS_INTEGER)
IS
   l_num_curr_ml_carriers PLS_INTEGER;
   l_num_future_ml_carriers PLS_INTEGER;
   l_num_total_ml_carriers PLS_INTEGER;
BEGIN
   SELECT COUNT(*)
     INTO l_num_curr_ml_carriers
     FROM ZONE Z, LZONE LZ, INV I
    WHERE LZ.LOGI_LOC = I.PLOGI_LOC
      AND Z.ZONE_ID = LZ.ZONE_ID
      AND Z.RULE_ID = 3
      AND Z.INDUCTION_LOC <> I.PLOGI_LOC
      AND I.PROD_ID = i_item_info.prod_id
      AND I.INV_UOM <> 1;

   SELECT NVL(SUM(CEIL((I.QOH + I.QTY_PLANNED - I.QTY_ALLOC) /
          (i_item_info.case_qty_per_carrier * i_item_info.spc))),0)
     INTO l_num_future_ml_carriers
     FROM ZONE Z, LZONE LZ, INV I
    WHERE LZ.LOGI_LOC = I.PLOGI_LOC
      AND Z.ZONE_ID = LZ.ZONE_ID
      AND (Z.INDUCTION_LOC = I.PLOGI_LOC OR Z.RULE_ID <> 3)
      AND I.PROD_ID = i_item_info.prod_id
      AND I.INV_UOM <> 1;

   l_num_total_ml_carriers := l_num_curr_ml_carriers + l_num_future_ml_carriers;

   o_ml_capacity := (i_item_info.max_miniload_case_carriers
                     - l_num_total_ml_carriers)
                    * i_item_info.case_qty_per_carrier * i_item_info.spc;

   IF o_ml_capacity < 0 THEN
         o_ml_capacity := 0;
         o_ml_overflow := 0;
   ELSE
         o_ml_overflow := i_item_info.case_qty_per_carrier * i_item_info.spc;
   END IF;

   dbms_output.put_line('ml_capacity:'||TO_CHAR(o_ml_capacity)||'   ml_overflow:'||TO_CHAR(o_ml_overflow));
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'get_item_ml_capacity',
                     'Error IN procedure', SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              'get_item_ml_capacity' || ': ' || SQLERRM);
END get_item_ml_capacity;


---------------------------------------------------------------------------
-- Procedure:
--    get_mx_item_inventory
--
-- Description:
--    This procedure determines the number of cases to be considered to be in
--    the matrix and the
--    number of cases in the main warehouse for an item.  The open PO process
--    will send the receiving pallet to main warehouse reserve if there are
--    any "AVL" cases in the main warehouse or if the qty in the matrix
--    is >= the item's mx_max_case.
--
--    Inventory at the following are considerd to be in the matrix:
--       - Pallet in the main warehouse that has a replenishment task to move
--         it to the matrix.
--       - Matrix staging location(s) 
--       - Matrix induction location
--       - Matrix outbound location
--       - Matrix spur location
--       - Matrix inventory location.
--    A location is considered a matrix location when the rule id for the
--    PUT zone of the inventory location is 5.
--
-- Parameters:
--    i_r_item_info              - Record of item being processed.
--    i_erm_id                   - PO/SN being processed.  Used in aplog messages.
--    o_mx_qty_in_splits         - Qty considered to be in the matrix.  In cases.
--    o_warehouse_qty_in_splits  - Qty in the main warehouse.  In splits.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list_from_po
--    - build_pallet_list_from_sn
--
-- Modification History:
--    Date     Designer  Comments
--    -------- --------  ---------------------------------------------------
--    08/07/14 sred5131  Created.
--    09/17/14 vred5319  Modified for Symbotic/Matrix Project
--    03/25/15 bben0556  Replenishments from the matrix to the split home
--                       was case inventory in the main warehouse so the open
--                       PO process sent the receiving palllet to main
--                       warehouse reserve instead of the matrix.
---------------------------------------------------------------------------
PROCEDURE get_mx_item_inventory
     (i_r_item_info              IN  pl_rcv_open_po_types.t_r_item_info,
      i_erm_id                   IN  erm.erm_id%TYPE,
      o_mx_qty_in_splits         OUT PLS_INTEGER,               -- VR modified
      o_warehouse_qty_in_splits  OUT PLS_INTEGER)               -- VR modified
IS
   l_object_name                     VARCHAR2(30) := 'get_mx_item_inventory';

   l_curr_mx_qty_in_splits           PLS_INTEGER;
   l_curr_warehouse_qty_in_splits    PLS_INTEGER; 
   l_repl_qty_to_matrix_in_splits    PLS_INTEGER; 

   --
   -- Get the qty in the matrix and the qty in the main warehouse.
   -- Only concerned about cases as only cases are in symbotic.
   -- NOTE: If we have a bogus replenishment task then the qty's
   --       will most likely be thrown off.
   --
   -- The columns with the qty in cases are used in log messages.
   -- The case qty's are "trunc"ed though ideally their should be no splits
   -- in the qty.  We could have converted to cases in separate stmts
   -- after the fetch from the cursor but doing so in the cursor does
   -- not add any measurable computing time.
   --
   CURSOR c_item_qty(cp_prod_id           pm.prod_id%TYPE,
                     cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE)
   IS
      SELECT NVL(SUM(DECODE(zone.rule_id, 5, inv.qoh + inv.qty_planned, 0)), 0)                   mx_qty_in_splits,
             NVL(SUM(DECODE(zone.rule_id, 5, TRUNC((inv.qoh + inv.qty_planned) / pm.spc), 0)), 0) mx_qty_in_cases,
             --
             NVL(SUM(DECODE(zone.rule_id, 5, 0, inv.qoh + inv.qty_planned)), 0)                   main_warehouse_qty_in_splits,
             NVL(SUM(DECODE(zone.rule_id, 5, 0, TRUNC((inv.qoh + inv.qty_planned) / pm.spc))), 0) main_warehouse_qty_in_cases,
             --
             MIN(NVL(rep.replen_qty_to_matrix, 0))                              repl_qty_to_matrix_in_splits,
             MIN(NVL(TRUNC(rep.replen_qty_to_matrix / pm.spc), 0))              repl_qty_to_matrix_in_cases,
             --
             MIN(NVL(rep.replen_count, 0))                                      repl_count
        FROM inv,
             lzone,
             zone,
             pm,
             --
             -- inline view
             -- Get replenishment qty going to the matrix.
             (SELECT r.prod_id,
                     r.cust_pref_vendor,
                     SUM(r.qty) replen_qty_to_matrix,
                     COUNT(*)   replen_count
                FROM replenlst r
               WHERE r.type IN ('NXL', 'MXL')  -- Only concerned about these repl types
               GROUP BY r.prod_id, r.cust_pref_vendor) rep
       WHERE inv.prod_id                    = cp_prod_id
         AND inv.cust_pref_vendor           = cp_cust_pref_vendor
         AND lzone.logi_loc                 = inv.plogi_loc
         AND zone.zone_id                   = lzone.zone_id
         AND zone.zone_type                 = 'PUT'
         AND pm.prod_id                     = inv.prod_id
         AND pm.cust_pref_vendor            = inv.cust_pref_vendor
         AND inv.status                     = 'AVL'  -- Only want AVL inventory.
         --
         AND rep.prod_id          (+)       = inv.prod_id
         AND rep.cust_pref_vendor (+)       = inv.cust_pref_vendor
         --
         AND NVL(inv.inv_uom, 0) <> 1  -- Leave out split inventory
         AND inv.plogi_loc NOT IN      -- Leave out split home
             (SELECT logi_loc
                FROM loc
               WHERE loc.prod_id          = inv.prod_id
                 AND loc.cust_pref_vendor = inv.cust_pref_vendor
                 AND loc.uom              = 1)
       GROUP BY inv.prod_id, inv.cust_pref_vendor;

   l_r_item_qty c_item_qty%ROWTYPE;
BEGIN
   OPEN c_item_qty(i_r_item_info.prod_id, i_r_item_info.cust_pref_vendor);
   FETCH c_item_qty INTO l_r_item_qty;

   IF (c_item_qty%NOTFOUND) THEN
      --
      -- Did not find any inventory for the item.
      -- We need to set these values to 0 because
      -- they are expected to have a value.
      --
      l_r_item_qty.mx_qty_in_splits             := 0;
      l_r_item_qty.main_warehouse_qty_in_splits := 0;
      l_r_item_qty.repl_qty_to_matrix_in_splits := 0;
   END IF;

   o_mx_qty_in_splits := l_r_item_qty.mx_qty_in_splits
                         + l_r_item_qty.repl_qty_to_matrix_in_splits;

   o_warehouse_qty_in_splits := l_r_item_qty.main_warehouse_qty_in_splits
                                - l_r_item_qty.repl_qty_to_matrix_in_splits;

   CLOSE c_item_qty;

   DBMS_OUTPUT.put_line('o_mx_qty_in_splits: '|| TO_CHAR(o_mx_qty_in_splits)
         || '  mx_max_in_splits: ' || TO_CHAR(i_r_item_info.mx_max_case * i_r_item_info.spc)
         || '  o_warehouse_qty_in_splits: ' || TO_CHAR(o_warehouse_qty_in_splits));

   --
   -- Log an INFO message. 
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
              ' Item['                       || i_r_item_info.prod_id              || ']'
           || '  CPV['                       || i_r_item_info.cust_pref_vendor     || ']'
           || '  SPC['                       || TO_CHAR(i_r_item_info.spc)         || ']'
           || '  Item mx_eligible['          || i_r_item_info.mx_eligible          || ']'
           || '  Item mx_item_assign_flag['  || i_r_item_info.mx_item_assign_flag  || ']'
           || '  Item mx_max_case['          || TO_CHAR(i_r_item_info.mx_max_case) || ']'
           || '  PO/SN['                     || i_erm_id                           || ']'
           || '  o_mx_qty_in_splits['        || TO_CHAR(o_mx_qty_in_splits)        || ']'
           || '  o_warehouse_qty_in_splits[' || TO_CHAR(o_warehouse_qty_in_splits) || ']'
           || '  AVL cases in the matrix['   || l_r_item_qty.mx_qty_in_cases || ']'
           || '  AVL cases in the main warehouse['
           || TO_CHAR(l_r_item_qty.main_warehouse_qty_in_cases) || ']'
           || '  Cases to be replenished to the matrix in NXL and MXL replenishments['
           || TO_CHAR(l_r_item_qty.repl_qty_to_matrix_in_cases) || ']'
           || '  Number of NXL and MXL replenishments['
           || TO_CHAR(l_r_item_qty.repl_count) || ']'
           || '  Effective case qty in the main warehouse(the qty in the main warehouse minus the NXL and MXL replenishment qty)['
           || TO_CHAR(l_r_item_qty.main_warehouse_qty_in_cases - l_r_item_qty.repl_qty_to_matrix_in_cases)
           || ']'
           || '  Effective case qty in the matrix(the qty in the matrix plus the NXL and MXL replenishment qty)['
           || TO_CHAR(l_r_item_qty.mx_qty_in_cases + l_r_item_qty.repl_qty_to_matrix_in_cases)
           || ']'
           || '  The case qty in the warehouse, the case qty in the matrix,'
           || ' the replenishment qty going to the matrix for NXL and MXL replenishments'
           || ' and the item''s mx_max_case are used to determine if the'
           || ' receiving pallet should go to the matrix or to the main warehouse'
           || ' for an item assigned to the matrix.'
           || '  NOTE: The NXL and MXL replenishment qty is considered to be in the matrix.'
           || '  If there are any AVL cases in the main warehouse then the receiving pallet'
           || ' is directed to the main warehouse.',
           NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                     'Error IN procedure', SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     Gl_Pkg_Name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END get_mx_item_inventory;


---------------------------------------------------------------------------
-- Procedure:
--    determine_pallet_attributes
--
-- Description:
--    This procedure determines dIFferent attributes for the pallet.
--    Some of these are:
--       - Calculating the cube and height of the pallet.
--         Extended case cube is taken into account.
--         IF receivng splits then the cube is not rounded up to the nearest
--         Ti and extended case cube is not used.
--       - Setting the inv_uom.
--         This is based on the receiving uom (erd.uom) and the item's
--         storage indicator (pm.miniload_storage_ind) and the ship split
--         flag (pm.auto_ship_flag).
--
-- Parameters:
--    i_r_item_info       - Item being processed
--    i_pallet_index      - Index of current pallet IN pallet list.
--    o_r_pallet_table    - List of pallets being built.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error     - Unhandled value for the erd uom.
--                               Unhandled value for the item's miniloader
--                               storage ind.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called By:
--    - build_pallet_list_from_po
--    - build_pallet_list_from_sn
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/15/05 prpbcb   Created
--    03/24/06 prpbcb   Renamed procedure from calc_pallet_size to
--                      determine_pallet_attributes.  Added the assignment
--                      of the pallet record inv_uom.
--    06/15/07 prpbcb   Added populating fields cube_for_home_putaway and
--                      pallet_height_for_home_putaway IN the pallet record.
--    01/28/08 prpbcb   Set the inv_uom to 1 for a pallet that will be going
--                      to the miniloader induction location when receiving
--                      cases and the item is ship splits only.
---------------------------------------------------------------------------
PROCEDURE determine_pallet_attributes
     (i_r_item_info       IN            pl_rcv_open_po_types.t_r_item_info,
      i_pallet_index      IN            PLS_INTEGER,
      io_r_pallet_table   IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_message       VARCHAR2(300);    -- Message buffer
   l_object_name   VARCHAR2(61);

    e_bad_uom  EXCEPTION;  -- Unhandled value for the erd uom which is stored
                           -- IN the pallet record.
    e_bad_miniload_storage_ind  EXCEPTION;  -- Unhandled value for the item's
                                            -- miniload storage indicator.
BEGIN
   --
   -- Calculate the cube of the pallet excluding the skid cube and
   -- the inv_uom.
   -- The cube will be rounded up to a full Ti IF it is designated to
   -- do so for the item.
   --
   -- IF extended case cube is active and item has a case home slot then the
   -- size of the pallet including the skid will be set to the cube of the
   -- case home divided by the number of positions IN the case home.
   --
   -- IF receivng splits then the cube is not rounded up to the nearest Ti.
   --
   -- The cube will be rounded to 2 decimal places.
   --
   IF (io_r_pallet_table(i_pallet_index).uom = 0) THEN
       --
       -- ----------------------------------
       -- Receiving cases (the norm).
       -- ----------------------------------
       --
       -- Calculate the cube of the pallet excluding the skid cube.
       --
       IF (i_r_item_info.round_plt_cube_up_to_ti_flag = 'Y') THEN
          --
          -- Round cube to full Ti.
          --
          io_r_pallet_table(i_pallet_index).cube_without_skid :=
     ROUND(CEIL((io_r_pallet_table(i_pallet_index).qty_received / i_r_item_info.spc) /
                         i_r_item_info.ti) *
                 i_r_item_info.ti *
                 i_r_item_info.case_cube_for_calc, 2);
       ELSE
          --
          -- Do not round cube to full Ti.
          --
          io_r_pallet_table(i_pallet_index).cube_without_skid :=
             ROUND((io_r_pallet_table(i_pallet_index).qty_received / i_r_item_info.spc)
                  * i_r_item_info.case_cube_for_calc, 2);
      END IF;

      --
      -- Set the inv_uom.
      --
      IF (i_r_item_info.miniload_storage_ind = 'N') THEN
          --
          -- Receiving cases and not a miniload item.
          -- Set the inv_uom to 0.
          --
          io_r_pallet_table(i_pallet_index).inv_uom := 0;
      ELSIF (i_r_item_info.miniload_storage_ind = 'S') THEN
          --
          -- Receiving cases and only splits are stored IN the
          -- miniloader.
          -- Set the inv_uom to 0.
          --
          io_r_pallet_table(i_pallet_index).inv_uom := 0;
      ELSIF (i_r_item_info.miniload_storage_ind = 'B') THEN
          --
          -- Receiving cases and both cases and splits (IF a splitable item)
          -- are stored IN the miniloader.
          -- The inv_uom will be 2 IF the item is not ship split only.
          -- The inv_uom will be 1 IF the item is ship split only.
          --
         IF (i_r_item_info.auto_ship_flag = 'N') THEN
            io_r_pallet_table(i_pallet_index).inv_uom := 2;
         ELSE
            io_r_pallet_table(i_pallet_index).inv_uom := 1;
         END IF;
      ELSE
         --
         -- Unhandled value for the item's miniload storage indicator.
         -- This stops processing.
         --
         RAISE e_bad_miniload_storage_ind;
      END IF;

   ELSIF (io_r_pallet_table(i_pallet_index).uom = 1) THEN
       --
       -- ----------------------------------
       -- Receiving splits (not the norm).
       -- ----------------------------------
       --
       -- Calculate the cube of the pallet based only on the qty.  No rounding
       -- of the qty to a full Ti will take place.  Extended case cube applies.
       --
       io_r_pallet_table(i_pallet_index).cube_without_skid :=
     ROUND((io_r_pallet_table(i_pallet_index).qty_received / i_r_item_info.spc) *
                 i_r_item_info.case_cube_for_calc, 2);

      --
      -- Set the inv_uom.
      --
      IF (i_r_item_info.miniload_storage_ind = 'N') THEN
          io_r_pallet_table(i_pallet_index).inv_uom := 0;
      ELSIF (i_r_item_info.miniload_storage_ind IN ('B', 'S')) THEN
          io_r_pallet_table(i_pallet_index).inv_uom := 1;
      ELSE
         --
         -- Unhandled value for the item's miniload storage indicator.
         -- This stops processing.
         --
         RAISE e_bad_miniload_storage_ind;
      END IF;
   ELSE
      --
      -- Have an unhandled value for io_r_pallet_table(i_pallet_index).uom
      -- (which is the erd.uom).
      -- This stops processing.
      --
      RAISE e_bad_uom;
   END IF;

   --
   -- Calculate the cube of the pallet to use for putaway including the
   -- skid.  Extended case cube is taken into account.
   --
   io_r_pallet_table(i_pallet_index).cube_with_skid :=
             io_r_pallet_table(i_pallet_index).cube_without_skid +
             i_r_item_info.pt_skid_cube;

   --
   -- Calculate the height of the pallet excluding the skid.
   -- Round to 1 decimal place.
   --
   io_r_pallet_table(i_pallet_index).pallet_height_without_skid :=
    ROUND(CEIL((io_r_pallet_table(i_pallet_index).qty_received / i_r_item_info.spc) /
                         i_r_item_info.ti) *
                      i_r_item_info.case_height, 1);

   --
   -- Calculate the height of the pallet including the skid.
   --
   io_r_pallet_table(i_pallet_index).pallet_height_with_skid :=
           io_r_pallet_table(i_pallet_index).pallet_height_without_skid +
                  i_r_item_info.pt_skid_height;

   --
   -- Determine the pallet cube and pallet height to use when directing the
   -- pallet to the home slot.  The values will get set for floating items
   -- but it will cause no problems.
   --
   IF (io_r_pallet_table(i_pallet_index).partial_pallet_flag = 'N') THEN
      --
      -- Full pallet.
      --
      io_r_pallet_table(i_pallet_index).cube_for_home_putaway :=
             io_r_pallet_table(i_pallet_index).cube_with_skid;

      io_r_pallet_table(i_pallet_index).pallet_height_for_home_putaway :=
             io_r_pallet_table(i_pallet_index).pallet_height_with_skid;
   ELSE
      --
      -- Partial pallet.  Do not include the skid.
      --
      io_r_pallet_table(i_pallet_index).cube_for_home_putaway :=
             io_r_pallet_table(i_pallet_index).cube_without_skid;

      io_r_pallet_table(i_pallet_index).pallet_height_for_home_putaway :=
             io_r_pallet_table(i_pallet_index).pallet_height_without_skid;
   END IF;

   dbms_output.put_line('qty:'||to_char(io_r_pallet_table(i_pallet_index).qty_received)||
                        '   cube_wo_skid:'||to_char(io_r_pallet_table(i_pallet_index).cube_without_skid)||
                        '   cube_w_skid:'||to_char(io_r_pallet_table(i_pallet_index).cube_with_skid));
EXCEPTION
   WHEN e_bad_uom THEN
      l_object_name := 'determine_pallet_attributes';
      l_message :=
               ' Item[' || i_r_item_info.prod_id || ']'
               || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
               || '  LP[' || io_r_pallet_table(i_pallet_index).pallet_id || ']'
               || '  PO/SN[' || io_r_pallet_table(i_pallet_index).erm_id || ']'
               || '  Unhandled erd uom['
               || TO_CHAR(io_r_pallet_table(i_pallet_index).uom) || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN e_bad_miniload_storage_ind THEN
      l_object_name := 'determine_pallet_attributes';
      l_message :=
               ' Item[' || i_r_item_info.prod_id || ']'
               || '  CPV[' || i_r_item_info.cust_pref_vendor || ']'
               || '  LP[' || io_r_pallet_table(i_pallet_index).pallet_id || ']'
               || '  PO/SN[' || io_r_pallet_table(i_pallet_index).erm_id || ']'
               || '  Unhandled miniload storage indicator['
               || i_r_item_info.miniload_storage_ind || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
               NULL, NULL,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN OTHERS THEN
      l_object_name := 'determine_pallet_attributes';
      l_message := l_object_name
            || ' i_r_item_info.prod_id[' || i_r_item_info.prod_id || ']'
            || ' i_r_item_info.cust_pref_vendor['
            || i_r_item_info.cust_pref_vendor || ']'
            || ' io_r_pallet_table(i_pallet_index).pallet_id['
            || io_r_pallet_table(i_pallet_index).pallet_id || ']'
            || ' i_pallet_index[' || TO_CHAR(i_pallet_index) || ']'
            || ' PO/SN[' || io_r_pallet_table(i_pallet_index).erm_id || ']'
            || ' Oracle error';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
               SQLCODE, SQLERRM,
               pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                    gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);
END determine_pallet_attributes;


---------------------------------------------------------------------------
-- Procedure:
--    show_item_info
--
-- Description:
--    Output the item infor racord.  Used for debugging.
--
-- Parameters:
--    i_r_item_info_table - Item information record.
--    i_item_index        - Index of item IN table.
---------------------------------------------------------------------------
PROCEDURE show_item_info
           (i_index             IN PLS_INTEGER,
            i_r_item_info_table IN pl_rcv_open_po_types.t_r_item_info_table)
IS
BEGIN
   DBMS_OUTPUT.PUT_LINE('========== Start show_item_info ==========');
   DBMS_OUTPUT.PUT_LINE('i_index: ' || TO_CHAR(i_index));
   DBMS_OUTPUT.PUT_LINE('prod_id: ' || i_r_item_info_table(i_index).prod_id);
   DBMS_OUTPUT.PUT_LINE('cust_pref_vendor: ' ||
                           i_r_item_info_table(i_index).cust_pref_vendor);
/*
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).hazardous,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).lot_trk,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).catch_wt_trk,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).split_trk,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).exp_date_trk,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).temp_trk,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).mfg_date_trk,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).stackable,
*/
   DBMS_OUTPUT.PUT_LINE('spc: ' || TO_CHAR(i_r_item_info_table(i_index).spc));
   DBMS_OUTPUT.PUT_LINE('ti: ' || TO_CHAR(i_r_item_info_table(i_index).ti));
   DBMS_OUTPUT.PUT_LINE('hi: ' || TO_CHAR(i_r_item_info_table(i_index).hi));
   DBMS_OUTPUT.PUT_LINE('mf_ti: ' || i_r_item_info_table(i_index).mf_ti);
   DBMS_OUTPUT.PUT_LINE('mf_hi: ' || i_r_item_info_table(i_index).mf_hi);
   DBMS_OUTPUT.PUT_LINE('pallet_type: ' ||
                                  i_r_item_info_table(i_index).pallet_type);
   DBMS_OUTPUT.PUT_LINE('case_cube: ' ||
                         TO_CHAR(i_r_item_info_table(i_index).case_cube));
   DBMS_OUTPUT.PUT_LINE('case_cube_for_calc: ' ||
                 TO_CHAR(i_r_item_info_table(i_index).case_cube_for_calc));
   DBMS_OUTPUT.PUT_LINE('home_slot_cube: ' ||
                 TO_CHAR(i_r_item_info_table(i_index).case_home_slot_cube));
   DBMS_OUTPUT.PUT_LINE('home_slot_true_slot_hgt: ' ||
     TO_CHAR(i_r_item_info_table(i_index).case_home_slot_true_slot_hgt));
/*
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).zone_id,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).max_slot,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).max_slot_per,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).fIFo_trk,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).last_ship_slot,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).case_height,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).split_height,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).min_qty,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).max_qty,
   DBMS_OUTPUT.PUT_LINE(i_r_item_info_table(i_index).mf_sw_ti,
*/
   DBMS_OUTPUT.PUT_LINE('full_pallet_qty_in_splits: ' ||
           TO_CHAR(i_r_item_info_table(i_index).full_pallet_qty_in_splits));

   DBMS_OUTPUT.PUT_LINE('========== End show_item_info ==========');
END show_item_info;



---------------------------------------------------------------------------
-- Function:
--    f_get_new_pallet_id
--
-- Description:
--    This function returns the pallet id to use for the putaway pallet.
--
-- Parameters:
--    i_erm_id  -  PO/SN number.  Used only IN error message.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list_from_po
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/01/05 prpbcb   Created
--    02/22/07 prpbcb   Changed to call pl_common.f_get_new_pallet_id.
---------------------------------------------------------------------------
FUNCTION f_get_new_pallet_id(i_erm_id  IN erm.erm_id%TYPE DEFAULT NULL)
RETURN VARCHAR2
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61);

   l_done_bln   BOOLEAN;      -- Flag
   l_dummy      VARCHAR2(1);  -- Work area
   l_pallet_id  putawaylst.pallet_id%TYPE;  -- LP to use for the pallet

BEGIN
   l_pallet_id := pl_common.f_get_new_pallet_id;

   RETURN(l_pallet_id);

EXCEPTION
   WHEN OTHERS THEN
      l_object_name := 'f_net_new_pallet_id';
      l_message := l_object_name
                   || '  PO/SN[' || i_erm_id || ']'
                   || '  Failed to get the pallet id.';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                  gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);
END f_get_new_pallet_id;


---------------------------------------------------------------------------
-- Procedure:
--    get_item_info
--
-- Description:
--    This procedure gets information about the item that is needed
--    for the putaway processing.  The info is stored IN a PL/SQL table
--    of records.
--
--    IF the item is already IN the table then o_item_index
--    is set to where the item is at.  It will not be selected again.
--
-- Parameters:
--    i_r_syspars         - Putaway syspars.
--    i_prod_id           - The item to find the information for.
--    i_cust_pref_vendor  - The CPV for the item.
--    i_erm_id            - SN/PO number.  Used IN aplog messages.
--    o_item_index        - Index of item IN table.
--    o_r_item_info_table - Item information record.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list_from_po
--    - build_pallet_list_from_sn
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    xx/xx/xx prpbcb   Created
--    06/02/06 prpbcb   Added the following to the item info written to
--                      SWMS_LOG.  This information helps when resolving
--                      issues.
--                         - Ti
--                         - Hi
--                         - FIFO track flag
--                         - Aging item flag
--                         - round_inv_cube_up_to_ti_flag flag
--                         - round_plt_cube_up_to_ti_flag
--
--    05/02/07 prpbcb   Change NVL(pm.case_height, 1) to
--                        DECODE(pm.case_height,
--                               NULL, ct_default_case_height
--                               0, ct_default_case_height,
--                               pm.case_height)
--                      to get the pallet to '*'
--                      (unless there are some really tall slots) when
--                      putaway is by inches and the case has no height.
--
--                      Added populating pt_putaway_floating_by_max_qty IN
--                      the item record.  The value comes from
--                      pallet_type.putaway_floating_by_max_qty.  It is used
--                      to designame IF directing a floating item to a slot
--                      will be by the item's max qty or by the current
--                      putaway dimension.  IF the value is Y then the item's
--                      max qty is used to direct pallets to slots for
--                      floating items.  IF the value is N then the putaway
--                      dimension syspar controls directing pallets to slots.
--
--    10/17/12 prpbcb   Added populating min_qty and min_qty_in_splits
--                      the item record.
--    08/05/14 sred5131  Added following fields to cursor c_item_info and added matrix logic.
--                             MX_ITEM_ASSIGN_FLAG
--                             MX_MIN_CASE
--                             MX_MAX_CASE
--                             MX_FOOD_TYPE
--   09/18/14  vred5319 Modified decode statement for mx_item_assign_flag-'Y' item
--   09/26/14  vred5319 Added mx_eligible field to cursor c_item_info.
---------------------------------------------------------------------------
PROCEDURE get_item_info
  (i_r_syspars          IN     pl_rcv_open_po_types.t_r_putaway_syspars,
   i_prod_id            IN     pm.prod_id%TYPE,
   i_cust_pref_vendor   IN     pm.cust_pref_vendor%TYPE,
   i_erm_id             IN     erm.erm_id%TYPE,
   o_index              IN OUT PLS_INTEGER,
   io_r_item_info_table IN OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table)
IS
   l_message        VARCHAR2(256);    -- Message buffer
   l_object_name    VARCHAR2(30)    := 'get_item_info';

   l_found_item_bln BOOLEAN; -- Flag used when checking IF item already IN tbl.
   l_index          PLS_INTEGER;   -- Index into table

   r_case_home_slot  pl_rcv_open_po_cursors.g_c_case_home_slots%ROWTYPE;
                                   -- Case home slot for the item.

   e_item_not_found EXCEPTION;  -- Item not found
   l_config_val   varchar2(40);
   --
   -- This cursor selects the item information that is required to find a slot
   -- for the item.
   --
   -- NVL is used on the nullable columns that IF left null may cause a
   -- problem though IN practice these columns should have a value
   -- such on the pm.ti.
   --
   CURSOR c_item_info(cp_prod_id           pm.prod_id%TYPE,
                      cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE) IS
      SELECT
             pm.prod_id                      prod_id,
             pm.cust_pref_vendor             cust_pref_vendor,
             pm.category                     category,
             pm.hazardous                    hazardous,
             pm.abc                          abc,
             NVL(pm.lot_trk,      'N')       lot_trk,
             NVL(pm.catch_wt_trk, 'N')       catch_wt_trk,
             NVL(pm.split_trk,    'N')       split_trk,
             NVL(pm.exp_date_trk, 'N')       exp_date_trk,
             NVL(pm.temp_trk,     'N')       temp_trk,
             NVL(pm.mfg_date_trk, 'N')       mfg_date_trk,
             NVL(pm.fIFo_trk,     'N')       fIFo_trk,
             pm.stackable                    stackable,
             DECODE(pm.spc, 0, 1, pm.spc)    spc,   -- sanity check
             NVL(pm.ti, 1)                   ti,
             pm.hi                           hi,
             pm.mf_ti                        mf_ti,
             pm.mf_hi                        mf_hi,
             NVL(pm.pallet_type, 'LW')       pallet_type,
             pm.area                         area,
             NVL(pm.case_cube, 1)            case_cube,
             pm.zone_id                      zone_id,
             NVL(z.rule_id, 0)               rule_id,
             NVL(pm.max_slot, 999)           max_slot,
             NVL(pm.max_slot_per, 'Z')       max_slot_per,
             DECODE(pm.miniload_storage_ind,
                    'B', z.induction_loc,
                    pm.last_ship_slot)       last_ship_slot,
             DECODE(pm.case_height,
                    NULL, ct_default_case_height,
                    0, ct_default_case_height,
                    pm.case_height)          case_height,
             pm.split_height                 split_height,
             NVL(pm.min_qty, 0)              min_qty,
             NVL(pm.min_qty, 0) *
                DECODE(pm.spc, 0, 1, pm.spc) min_qty_in_splits,
             NVL(pm.max_qty, 0)              max_qty,
             NVL(pm.max_qty, 0) *
                DECODE(pm.spc, 0, 1, pm.spc) max_qty_in_splits,
             pm.mf_sw_ti                     mf_sw_ti,
             NVL(pm.mfr_shelf_life, 0)       mfr_shelf_life,
             NVL(pm.sysco_shelf_lIFe, 0)     sysco_shelf_lIFe,
             NVL(pm.cust_shelf_lIFe, 0)      cust_shelf_lIFe,
             NVL(pm.pallet_stack,
                 pl_rcv_open_po_types.ct_pallet_stack_magic_num) pallet_stack,
       pl_rcv_open_po_types.ct_pallet_stack_magic_num   pallet_stack_magic_num,
             pm.spc * pm.ti * pm.hi          full_pallet_qty_in_splits,
             pm.ti * pm.hi                   full_pallet_qty_in_cases,
             NVL(pt.cube, 0)                 pt_cube,
             NVL(pt.skid_cube, 0)            pt_skid_cube,
             pt.skid_height                  pt_skid_height,
             pt.ext_case_cube_flag           pt_ext_case_cube_flag,
             pt.putaway_use_repl_threshold   pt_putaway_use_repl_threshold,
             pt.putaway_floating_by_max_qty  pt_putaway_floating_by_max_qty,
             NVL(sa.num_next_zones, 0)       num_next_zones,
             pm.split_zone_id                split_zone_id,
             z_split.rule_id                 split_zone_rule_id,
             pm.auto_ship_flag               auto_ship_flag,
             pm.miniload_storage_ind         miniload_storage_ind,
             DECODE(z.rule_id, 3, z.induction_loc,
                    decode(pm.mx_item_assign_flag, 'Y', pl_matrix_common.f_get_mx_dest_loc(pm.prod_id),       --VR modified
                                      NULL))         case_induction_loc,                        
             DECODE(z_split.rule_id, 3, NVL(z_split.induction_loc, '*'),
                                     NULL)   split_induction_loc,
             pm.case_qty_per_carrier         case_qty_per_carrier,
             NVL(pm.max_miniload_case_carriers,99) max_miniload_case_carriers,
             pm.mx_item_assign_flag    mx_item_assign_flag,
             pm.mx_min_case            mx_min_case,
             pm.mx_max_case            mx_max_case,
             pm.mx_food_type           mx_food_type,
             pm.mx_eligible            mx_eligible,                                                            -- VR added
             pm.avg_wt                 avg_wt 
        FROM swms_areas  sa,       -- To get the number of next zones to check.
             pallet_type pt,       -- To get info about the item's pallet TYPE.
             zone        z,        -- To get the rule id of pm.zone_id and the
                                   -- miniload induction location for cases.
             zone        z_split,  -- Joined to pm.split_zone_id to determine
                                   -- the miniload induction location for
                                   -- splits.
             pm          pm
       WHERE sa.area_code (+)    = pm.area
         AND pt.pallet_type (+)  = pm.pallet_type
         AND z.zone_id (+)       = pm.zone_id
         AND z_split.zone_id (+) = pm.split_zone_id
         AND pm.prod_id          = cp_prod_id
         AND pm.cust_pref_vendor = cp_cust_pref_vendor;

   --
   -- Location info record used when processing floating item.
   --
   r_loc_info    pl_rcv_open_po_cursors.g_c_loc_info%ROWTYPE;
BEGIN
   --
   -- IF the item has already been selected then find the index for it.
   -- It will not be selected again.
   --


   l_found_item_bln := FALSE;
   l_index := io_r_item_info_table.FIRST;

   WHILE (l_index <= io_r_item_info_table.LAST AND
          l_found_item_bln = FALSE) LOOP
      IF (io_r_item_info_table(l_index).prod_id = i_prod_id AND
          io_r_item_info_table(l_index).cust_pref_vendor = i_cust_pref_vendor)
      THEN
         -- The item already exists IN the PL/SQL table.
         l_found_item_bln := TRUE;
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' Item already IN table.' ||
                       ' ' || io_r_item_info_table(l_index).prod_id ||
                       ' ' || io_r_item_info_table(l_index).pallet_type ||
                       ' ' || io_r_item_info_table(l_index).zone_id ||
                       ' l_index[' || TO_CHAR(l_index) || ']' ||
                       ' i_prod_id' || i_prod_id ||
                       ' i_cpvd' || i_cust_pref_vendor);
      ELSE
         -- The item is not IN the PL/SQL table.
         l_index := io_r_item_info_table.NEXT(l_index);
      END IF;
   END LOOP;

   IF (l_found_item_bln = FALSE) THEN
      -- The item does not exist IN the PL/SQL table.  Add it.

      -- Determine the next element.
      l_index := NVL(io_r_item_info_table.LAST, 0) + 1;

      DBMS_OUTPUT.PUT_LINE('io_r_item_info_table.LAST: ' ||
                            io_r_item_info_table.LAST);
      DBMS_OUTPUT.PUT_LINE('io_r_item_info_table.COUNT: ' ||
                            io_r_item_info_table.COUNT);

      OPEN c_item_info(i_prod_id, i_cust_pref_vendor);

      FETCH c_item_info
       INTO io_r_item_info_table(l_index).prod_id,
            io_r_item_info_table(l_index).cust_pref_vendor,
            io_r_item_info_table(l_index).category,
            io_r_item_info_table(l_index).hazardous,
            io_r_item_info_table(l_index).abc,
            io_r_item_info_table(l_index).lot_trk,
            io_r_item_info_table(l_index).catch_wt_trk,
            io_r_item_info_table(l_index).split_trk,
            io_r_item_info_table(l_index).exp_date_trk,
            io_r_item_info_table(l_index).temp_trk,
            io_r_item_info_table(l_index).mfg_date_trk,
            io_r_item_info_table(l_index).fIFo_trk,
            io_r_item_info_table(l_index).stackable,
            io_r_item_info_table(l_index).spc,
            io_r_item_info_table(l_index).ti,
            io_r_item_info_table(l_index).hi,
            io_r_item_info_table(l_index).mf_ti,
            io_r_item_info_table(l_index).mf_hi,
            io_r_item_info_table(l_index).pallet_type,
            io_r_item_info_table(l_index).area,
            io_r_item_info_table(l_index).case_cube,
            io_r_item_info_table(l_index).zone_id,
            io_r_item_info_table(l_index).rule_id,
            io_r_item_info_table(l_index).max_slot,
            io_r_item_info_table(l_index).max_slot_per,
            io_r_item_info_table(l_index).last_ship_slot,
            io_r_item_info_table(l_index).case_height,
            io_r_item_info_table(l_index).split_height,
            io_r_item_info_table(l_index).min_qty,
            io_r_item_info_table(l_index).min_qty_in_splits,
            io_r_item_info_table(l_index).max_qty,
            io_r_item_info_table(l_index).max_qty_in_splits,
            io_r_item_info_table(l_index).mf_sw_ti,
            io_r_item_info_table(l_index).mfr_shelf_life,
            io_r_item_info_table(l_index).sysco_shelf_lIFe,
            io_r_item_info_table(l_index).cust_shelf_lIFe,
            io_r_item_info_table(l_index).pallet_stack,
            io_r_item_info_table(l_index).pallet_stack_magic_num,
            io_r_item_info_table(l_index).full_pallet_qty_in_splits,
            io_r_item_info_table(l_index).full_pallet_qty_in_cases,
            io_r_item_info_table(l_index).pt_cube,
            io_r_item_info_table(l_index).pt_skid_cube,
            io_r_item_info_table(l_index).pt_skid_height,
            io_r_item_info_table(l_index).pt_ext_case_cube_flag,
            io_r_item_info_table(l_index).putaway_to_home_slot_method,
            io_r_item_info_table(l_index).pt_putaway_floating_by_max_qty,
            io_r_item_info_table(l_index).num_next_zones,
            io_r_item_info_table(l_index).split_zone_id,
            io_r_item_info_table(l_index).split_zone_rule_id,
            io_r_item_info_table(l_index).auto_ship_flag,
            io_r_item_info_table(l_index).miniload_storage_ind,
            io_r_item_info_table(l_index).case_induction_loc,
            io_r_item_info_table(l_index).split_induction_loc,
            io_r_item_info_table(l_index).case_qty_per_carrier,
            io_r_item_info_table(l_index).max_miniload_case_carriers,
            io_r_item_info_table(l_index).mx_item_assign_flag,
            io_r_item_info_table(l_index).mx_min_case,
            io_r_item_info_table(l_index).mx_max_case,
            io_r_item_info_table(l_index).mx_food_type,
            io_r_item_info_table(l_index).mx_eligible,
            io_r_item_info_table(l_index).avg_wt;

      IF (c_item_info%NOTFOUND) THEN
         CLOSE c_item_info;
         l_message := l_object_name || '  TABLE=pm'
               || '  KEY=[' || i_prod_id || '][' || i_cust_pref_vendor || ']'
               || '(i_prod_id,i_cust_pref_vendor)'
               || '  PO/SN[' || i_erm_id || ']'
               ||  ' mx_item_assign_flag[' || io_r_item_info_table(l_index).case_induction_loc || ']'
                ||  ' mx_item_assign_flag[' || io_r_item_info_table(l_index).mx_item_assign_flag || ']'
                     || '  mx_min_case[' || io_r_item_info_table(l_index).mx_min_case || ']'
                     || ' mx_max_case[' || io_r_item_info_table(L_Index).Mx_Max_Case ||']'
                     || ' mx_food_type[' || io_r_item_info_table(l_index).mx_food_type ||']'
               || '  ACTION=SELECT  MESSAGE="Item not found."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
         RAISE e_item_not_found;
      END IF;

      CLOSE c_item_info;

      --
      -- Get info about the items rank 1 case home slot or floating slot IF
      -- a floating item.
      --
      -- A view notes about finding available slots based on cube:
      --    - Using extended case cube affects this.
      --    - For a floating item, when using extended case cube the last ship
      --      slot is used to calculate the extended case cube.  IF the last
      --      ship slot is no longer a valid location then the case cube
      --      is used for the extended case cube.
      --    - IF putaway dimension is C:
      --         IF using the replenishment threshold then the case cube is
      --         ignored when directing pallets to the home slot.
      --    - IF putaway dimension is I:
      --         The case cube is ignored.
      --

      OPEN pl_rcv_open_po_cursors.g_c_case_home_slots
                                         (io_r_item_info_table(l_index));
      FETCH pl_rcv_open_po_cursors.g_c_case_home_slots INTO r_case_home_slot;

      IF (pl_rcv_open_po_cursors.g_c_case_home_slots%FOUND) THEN
         --
         --**********************************************************
         -- The item has a case home slot(s).
         --**********************************************************
         --
         CLOSE pl_rcv_open_po_cursors.g_c_case_home_slots;

         io_r_item_info_table(l_index).case_home_slot_cube :=
                                                 r_case_home_slot.cube;

         io_r_item_info_table(l_index).case_home_slot_true_slot_hgt :=
                                   r_case_home_slot.true_slot_height;

         io_r_item_info_table(l_index).case_home_slot_slot_type :=
                                                 r_case_home_slot.slot_type;
         io_r_item_info_table(l_index).put_aisle := r_case_home_slot.put_aisle;
         io_r_item_info_table(l_index).put_slot := r_case_home_slot.put_slot;
         io_r_item_info_table(l_index).put_level := r_case_home_slot.put_level;
         io_r_item_info_table(l_index).has_home_slot_bln := TRUE;
         io_r_item_info_table(l_index).case_home_slot :=
                                                 r_case_home_slot.logi_loc;
         io_r_item_info_table(l_index).case_home_slot_deep_ind :=
                                                 r_case_home_slot.deep_ind;
         io_r_item_info_table(l_index).primary_put_zone_id :=
                                                 r_case_home_slot.zone_id;
         io_r_item_info_table(l_index).primary_put_zone_id_rule_id :=
                                                 r_case_home_slot.rule_id;
         io_r_item_info_table(l_index).case_home_slot_deep_positions :=
                                           r_case_home_slot.deep_positions;
         io_r_item_info_table(l_index).case_home_slot_width_positions :=
                                           r_case_home_slot.width_positions;
         --
         -- 02/13/06 prpbcb At this time the total positions IN the case home
         -- slot are the same as the deep positions.  The width positions
         -- are not yet handled.
         --
         io_r_item_info_table(l_index).case_home_slot_total_positions :=
                                   r_case_home_slot.total_positions;

         --
         -- Set the fields based on the syspar settings that designate IF
         -- the current inventory IN a slot is to be rounded up to the nearest
         -- ti when calculating the occupied cube IN a slot and IF the
         -- quantity on the pallet being received is to be rounded up to
         -- the nearest ti when calculating the cube of the pallet.
         --
         -- 02/21/06 prpbcb Currently the rounding/not rounding of the qty to
         -- a full Ti is at the syspar level.  IF a syspar does not allow
         -- enough flexibility and is moved to a dIFferent level such as the
         -- pallet TYPE level then this assignment would need to be changed.
         --
         io_r_item_info_table(l_index).round_inv_cube_up_to_ti_flag :=
                i_r_syspars.home_itm_rnd_inv_cube_up_to_ti;
         io_r_item_info_table(l_index).round_plt_cube_up_to_ti_flag :=
                i_r_syspars.home_itm_rnd_plt_cube_up_to_ti;

         --
         -- At this point io_r_item_info_table(l_index).pallet_type has what
         -- was IN pm.pallet_type.  IF the items pallet TYPE is not the same
         -- as the rank 1 case home pallet TYPE then set
         -- io_r_item_info_table(l_index).pallet_type to the rank 1 case home
         -- and write an aplog message noting this.  Finding available slots
         -- will be based on the case home slot pallet TYPE.
         -- For a slotted item pm.pallet_type should be the same as the rank
         -- 1 case home.
         --
         IF (io_r_item_info_table(l_index).pallet_type !=
                                             r_case_home_slot.pallet_type) THEN
            --
            -- The items pallet TYPE is not the same as the rank 1 case home.
            --
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
              ' Item[' || io_r_item_info_table(l_index).prod_id || ']'
              || '  CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
              || ']'
              || '  PO/SN[' || i_erm_id || ']'
              || '  Item Pallet TYPE['
              || io_r_item_info_table(l_index).pallet_type || ']'
              || '  Case Home Slot[' || r_case_home_slot.logi_loc || ']'
              || '  Case Home Slot Pallet TYPE['
              || r_case_home_slot.pallet_type || ']'
              || '  The items pallet TYPE is not the same as the case home'
              || ' slot.  They should be the same.  This will not stop'
              || ' processing but should be corrected.  Finding available'
              || ' slots will be based on the case home slot pallet TYPE.',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            io_r_item_info_table(l_index).pallet_type :=
                                                r_case_home_slot.pallet_type;

         END IF;


         --
         -- IF the item zone is not the same as the rank 1 case home then
         -- write an aplog message.  The zones should be the same.  IN the
         -- putaway logic the rank 1 case home zone is considered the items
         -- primary put zone.
         --
         IF (io_r_item_info_table(l_index).zone_id !=
                   io_r_item_info_table(l_index).primary_put_zone_id) THEN
            --
            -- The items put zone is not the same as the rank 1 case home.
            -- Log a message.
            --
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
           ' Item[' || io_r_item_info_table(l_index).prod_id || ']'
           || '  CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
           || ']'
           || '  PO/SN[' || i_erm_id || ']'
           || '  Item Zone[' || io_r_item_info_table(l_index).zone_id || ']'
           || '  Rule ID['
           || TO_CHAR(io_r_item_info_table(l_index).rule_id) || ']'
           || '  Primary Put Zone['
           || io_r_item_info_table(l_index).primary_put_zone_id || ']'
           || '  Primary Put Zone Rule ID['
        || TO_CHAR(io_r_item_info_table(l_index).primary_put_zone_id_rule_id)
           || ']'
           || '  The item put zone is not the same as the rank 1 case home'
           || ' PUT zone.  This will not stop processing but needs to be'
           || ' fixed.  The rank 1 case home PUT zone is always considered'
           || ' the items primary PUT zone.',
           NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

         END IF;

         --
         -- Calculate the case cube to use IN calculations of the pallet size.
         -- Using extended case cube affects this.
         --
         -- IF the cube of the case home slot is >= the magic cube value
         -- then extended case cube is always off.  OpCos use this to
         -- turn off extended case cube for an item.
         --
         IF (io_r_item_info_table(l_index).pt_ext_case_cube_flag = 'Y') THEN
            --
            -- Extended case cube is on.
            -- If the case home slot cube is >= the magic cube value then do
            -- not use extended case cube.
            --
            IF (r_case_home_slot.cube >= i_r_syspars.extended_case_cube_cutoff_cube) THEN
               --
               -- The case home slot cube is >= the magic cube value.
               -- Do not use extended case cube.
               --
               io_r_item_info_table(l_index).case_cube_for_calc :=
                                  io_r_item_info_table(l_index).case_cube;

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  'NOTE: Item[' || io_r_item_info_table(l_index).prod_id || ']'
                  ||'  CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
                  || ']'
                  || '  PO/SN[' || i_erm_id || ']'
                  ||'  Rank 1 case home slot['
                  || io_r_item_info_table(l_index).case_home_slot || ']'
                  || '  The case home slot cube of '
                  || TO_CHAR(r_case_home_slot.cube)
                  || ' is >= to the magic cube of '
                  || i_r_syspars.extended_case_cube_cutoff_cube
                  || ' as designated by syspar EXTENDED_CASE_CUBE_CUTOFF_CUBE'
                  || ' therefore extended'
                  || ' case cube is turned off for this item.',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
            ELSE
               --
               -- Extended case cube is on and the home slot cube is less
               -- than the magic cube.  Calculate the extended case cube.
               --
               io_r_item_info_table(l_index).case_cube_for_calc := ((r_case_home_slot.cube / r_case_home_slot.total_positions) -
                                                                     io_r_item_info_table(l_index).pt_skid_cube) /
                                                                   (io_r_item_info_table(l_index).ti * io_r_item_info_table(l_index).hi);
            END IF;
         ELSE
            --
            -- Extended case cube is off.
            --
            io_r_item_info_table(l_index).case_cube_for_calc := io_r_item_info_table(l_index).case_cube;
         END IF;
      ELSE    -- else for IF (pl_rcv_open_po_cursors.g_c_case_home_slots%FOUND)
         --
         --**********************************************************
         -- Floating item.
         --**********************************************************
         --
         -- The item does not have a rank 1 case home therefore it should be a
         -- floating item.  Check for location using the items last ship slot.
         -- 07/20/05 prpbcb  It is possible the last ship slot could no longer
         -- be a valid location.
         --
         -- Since there is no home slot home_slot_deep_ind will be set to 'N'.
         --
         CLOSE pl_rcv_open_po_cursors.g_c_case_home_slots;

        --Fix DF 11969 by Abhishek  
        -- For symbotic item there may be no case home but may have split home

        io_r_item_info_table(l_index).has_home_slot_bln := FALSE;
   
         --End DF 11969
         
         io_r_item_info_table(l_index).case_home_slot_deep_ind := 'N';

         io_r_item_info_table(l_index).primary_put_zone_id :=
                                      io_r_item_info_table(l_index).zone_id;
         io_r_item_info_table(l_index).primary_put_zone_id_rule_id :=
                                      io_r_item_info_table(l_index).rule_id;

         --
         -- Set the fields based on the syspar settings that designate IF
         -- the current inventory IN a slot is to be rounded up to the nearest
         -- ti when calculating the occupied cube IN a slot and IF the
         -- quantity on the pallet being received is to be rounded up to
         -- the nearest ti when calculating the cube of the pallet.
         --
         --
         -- 02/21/06 prpbcb Currently the rounding/not rounding of the qty to
         -- a full Ti is at the syspar level.  IF a syspar does not allow
         -- enough flexibility and is moved to a dIFferent level such as the
         -- pallet TYPE level then this assignment would need to be changed.
         --
         io_r_item_info_table(l_index).round_inv_cube_up_to_ti_flag :=
                i_r_syspars.flt_itm_rnd_inv_cube_up_to_ti;
         io_r_item_info_table(l_index).round_plt_cube_up_to_ti_flag :=
                i_r_syspars.flt_itm_rnd_plt_cube_up_to_ti;

         --
         -- Calculate the case cube to use IN calculations of the pallet size
         -- based on the last ship slot.
         -- IF extended case cube is on then the last ship slot is used to
         -- calculate the extended case cube.  IF there is no last ship slot
         -- or the last ship slot is invalid then the normal case cube is used
         -- for the extended case cube.
         --
         IF (io_r_item_info_table(l_index).last_ship_slot IS NULL) THEN
            --
            -- The item has no last ship slot.  Ideally a floating item
            -- should have a last ship slot.  This will not stop processing.
            --
            -- Extended case cube is ignored since it is based on the cube
            -- of the last ship slot.  Some default values are assigned.
            --
            io_r_item_info_table(l_index).case_cube_for_calc :=
                                  io_r_item_info_table(l_index).case_cube;
            io_r_item_info_table(l_index).last_ship_slot_cube := 0;
            io_r_item_info_table(l_index).last_ship_slot_height := 0;
            io_r_item_info_table(l_index).put_aisle := 0;
            io_r_item_info_table(l_index).put_slot := 0;
            io_r_item_info_table(l_index).put_level := 0;

            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
              ' Item[' || io_r_item_info_table(l_index).prod_id || ']'
              ||' CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
              || ']'
              || '  PO/SN[' || i_erm_id || ']'
              ||' Item Zone[' || io_r_item_info_table(l_index).zone_id || ']'
              || '  This floating item has no last ship slot.'
              || '  This will not stop processing but should be fixed'
              || ' by slotting the item.',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
         ELSE
            --
            -- The item has a last ship slot.
            --
            OPEN pl_rcv_open_po_cursors.g_c_loc_info
                              (io_r_item_info_table(l_index).last_ship_slot);
            FETCH pl_rcv_open_po_cursors.g_c_loc_info INTO r_loc_info;
            IF (pl_rcv_open_po_cursors.g_c_loc_info%FOUND) THEN
               --
               -- The last ship slot is a valid location.
               --
               CLOSE pl_rcv_open_po_cursors.g_c_loc_info;

               io_r_item_info_table(l_index).last_ship_slot_cube :=
                                            r_loc_info.cube;
               io_r_item_info_table(l_index).last_ship_slot_height :=
                                            r_loc_info.true_slot_height;
               io_r_item_info_table(l_index).put_aisle :=
                                            r_loc_info.put_aisle;
               io_r_item_info_table(l_index).put_slot :=
                                            r_loc_info.put_slot;
               io_r_item_info_table(l_index).put_level :=
                                            r_loc_info.put_level;

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                 ' Item[' || io_r_item_info_table(l_index).prod_id || ']'
                 || ' CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
                 || ']'
                 || '  PO/SN[' || i_erm_id || ']'
                 || ' Item Zone[' || io_r_item_info_table(l_index).zone_id ||']'
                 || ' Last Ship Slot['
                 || io_r_item_info_table(l_index).last_ship_slot || ']'
                 || ' Last Ship Slot Cube[' || TO_CHAR(r_loc_info.cube) || ']'
                 || ' Last Ship Slot Put Zone[' || r_loc_info.zone_id || ']'
                 || ' Last Ship Slot Zone Rule ID['
                 || TO_CHAR(r_loc_info.rule_id) || ']',
                 NULL, NULL,
                 pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

               IF (io_r_item_info_table(l_index).pt_ext_case_cube_flag = 'Y')
               THEN
                  --
                  -- Extended case cube is on.
                  --
                  -- If the last ship slot cube is >= the magic cube value
                  -- then do not use extended case cube.
                  --
                  IF (r_loc_info.cube >= i_r_syspars.extended_case_cube_cutoff_cube) THEN
                     --
                     -- Extended case cube is on and the last ship slot cube is >= the magic cube value.
                     -- Do not use extended case cube.
                     --
                     io_r_item_info_table(l_index).case_cube_for_calc :=
                                  io_r_item_info_table(l_index).case_cube;

                     pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                        'NOTE: Item[' || io_r_item_info_table(l_index).prod_id || ']'
                        ||' CPV['
                        || io_r_item_info_table(l_index).cust_pref_vendor
                        || ']'
                        || '  PO/SN[' || i_erm_id || ']'
                        ||'  Last ship slot['
                        || io_r_item_info_table(l_index).last_ship_slot || ']'
                        || '  The last ship slot cube of '
                        || TO_CHAR(r_loc_info.cube)
                        || ' is >= to the magic cube of '
                        || i_r_syspars.extended_case_cube_cutoff_cube
                        || ' as designated by syspar EXTENDED_CASE_CUBE_CUTOFF_CUBE'
                        || ' therefore extended'
                        || ' case cube is turned off for this item.',
                        NULL, NULL,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
                  ELSE
                     --
                     -- Extended case cube is on and the last ship slot cube is < the magic cube value.
                     -- Use extended case cube.
                     -- 
                     io_r_item_info_table(l_index).case_cube_for_calc :=
                                                     ((r_loc_info.cube / r_loc_info.total_positions) - io_r_item_info_table(l_index).pt_skid_cube) /
                                                     (io_r_item_info_table(l_index).ti * io_r_item_info_table(l_index).hi);
                  END IF;
               ELSE
                  --
                  -- Extended case cube is not on.
                  --
                  io_r_item_info_table(l_index).case_cube_for_calc := io_r_item_info_table(l_index).case_cube;
               END IF;
            ELSE
               --
               -- The last ship slot is not a valid location.
               --
               CLOSE pl_rcv_open_po_cursors.g_c_loc_info;

               io_r_item_info_table(l_index).case_cube_for_calc :=
                                  io_r_item_info_table(l_index).case_cube;
               io_r_item_info_table(l_index).last_ship_slot_cube := 0;
               io_r_item_info_table(l_index).last_ship_slot_height := 0;
               io_r_item_info_table(l_index).put_aisle := 0;
               io_r_item_info_table(l_index).put_slot := 0;
               io_r_item_info_table(l_index).put_level := 0;

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                 ' Item[' || io_r_item_info_table(l_index).prod_id || ']'
                 || '  CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
                 || ']'
                 || '  PO/SN[' || i_erm_id || ']'
                 || '  Item Zone[' || io_r_item_info_table(l_index).zone_id
                 ||']'
                 || '  Last Ship Slot['
                 || io_r_item_info_table(l_index).last_ship_slot || ']'
                 || '  The last ship slot for this floating item is invalid.'
                 || '  This will not stop processing but should be fixed'
                 || ' by reslotting the item.',
                 NULL, NULL,
                 pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
            END IF;
         END IF;
      END IF;

      --
      -- Set the slot search order based on the area of the item which is
      -- used when a partial pallet is directed to a non-deep reserve slot.
      --
      -- Set the floating slot order by based on the area of the item.
      --
      -- Set to minimize the distance from the home slot or find the best
      -- fit by size when looking for a reserve slot for a full pallet for
      -- an item with a home slot.
      --
      IF (io_r_item_info_table(l_index).area = 'D') THEN
         --
         -- Dry item
         --
         io_r_item_info_table(l_index).partial_nondeepslot_search :=
                               i_r_syspars.partial_nondeepslot_search_dry;

         io_r_item_info_table(l_index).floating_slot_sort_order :=
                               i_r_syspars.floating_slot_sort_order_dry;

         io_r_item_info_table(l_index).full_plt_minimize_option :=
                               i_r_syspars.full_plt_minimize_option_dry;

      ELSIF (io_r_item_info_table(l_index).area = 'C') THEN
         --
         -- Cooler item
         --
         io_r_item_info_table(l_index).partial_nondeepslot_search :=
                               i_r_syspars.partial_nondeepslot_search_clr;

         io_r_item_info_table(l_index).floating_slot_sort_order :=
                               i_r_syspars.floating_slot_sort_order_clr;

         io_r_item_info_table(l_index).full_plt_minimize_option :=
                               i_r_syspars.full_plt_minimize_option_clr;

      ELSIF (io_r_item_info_table(l_index).area = 'F') THEN
         --
         -- Freezer item
         --
         io_r_item_info_table(l_index).partial_nondeepslot_search :=
                               i_r_syspars.partial_nondeepslot_search_frz;

         io_r_item_info_table(l_index).floating_slot_sort_order :=
                               i_r_syspars.floating_slot_sort_order_frz;

         io_r_item_info_table(l_index).full_plt_minimize_option :=
                               i_r_syspars.full_plt_minimize_option_frz;
      ELSE
         --
         -- Unhandled value for the item's area.  Treat as dry and write
         -- an aplog message.
         --
         io_r_item_info_table(l_index).partial_nondeepslot_search :=
                               i_r_syspars.partial_nondeepslot_search_dry;

         io_r_item_info_table(l_index).floating_slot_sort_order :=
                               i_r_syspars.floating_slot_sort_order_dry;

         io_r_item_info_table(l_index).full_plt_minimize_option :=
                               i_r_syspars.full_plt_minimize_option_dry;

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                 ' Item[' || io_r_item_info_table(l_index).prod_id || ']'
                 || '  CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
                 || ']'
                 || '  PO/SN[' || i_erm_id || ']'
                 || '  Unhandled item area['
                 || io_r_item_info_table(l_index).area || ']'
                 || '  when setting fields IN the item info record based on'
                 || ' the area.  Will treat as dry.',
                 NULL, NULL,
                 pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
      END IF;

      --
      -- Determine IF the item is clam bed tracked.
      --
      IF (pl_putaway_utilities.f_is_clam_bed_tracked_item
                      (io_r_item_info_table(l_index).category,
                       i_r_syspars.clam_bed_tracked) = TRUE) THEN
         io_r_item_info_table(l_index).clam_bed_trk := 'Y';
      ELSE
         io_r_item_info_table(l_index).clam_bed_trk := 'N';
      END IF;

      --
      -- Determine IF the item is TTI tracked.
      --
      IF (pl_putaway_utilities.f_is_tti_tracked_item
            (io_r_item_info_table(l_index).prod_id,
             io_r_item_info_table(l_index).cust_pref_vendor) = TRUE) THEN
         io_r_item_info_table(l_index).tti_trk := 'Y';
      ELSE
         io_r_item_info_table(l_index).tti_trk := 'N';
      END IF;

      --
      -- Determine IF the item is COOL tracked.
      --
      IF (pl_putaway_utilities.f_is_cool_tracked_item
            (io_r_item_info_table(l_index).prod_id,
             io_r_item_info_table(l_index).cust_pref_vendor) = TRUE) THEN
         io_r_item_info_table(l_index).cool_trk := 'Y';
      ELSE
         io_r_item_info_table(l_index).cool_trk := 'N';
      END IF;

      --
      -- Determine IF the item is an aging item.
      --
      io_r_item_info_table(l_index).aging_days :=
               pl_putaway_utilities.f_retrieve_aging_items
                      (io_r_item_info_table(l_index).prod_id,
                       io_r_item_info_table(l_index).cust_pref_vendor);

      IF (io_r_item_info_table(l_index).aging_days = -1) THEN
         io_r_item_info_table(l_index).aging_item := 'N';
      ELSE
         io_r_item_info_table(l_index).aging_item := 'Y';
      END IF;

      --
      -- Write an aplog message showing the item info.
      --
      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
           ' Item[' || io_r_item_info_table(l_index).prod_id || ']'
           || '  CPV[' || io_r_item_info_table(l_index).cust_pref_vendor
           || ']'
           || '  PO/SN[' || i_erm_id || ']'
           || '  Item zone[' || io_r_item_info_table(l_index).zone_id || ']'
           || '  Rule ID['
           || TO_CHAR(io_r_item_info_table(l_index).rule_id) || ']'
           || '  Primary put zone['
           || io_r_item_info_table(l_index).primary_put_zone_id || ']'
           || '  Primary put zone rule ID['
           || TO_CHAR(io_r_item_info_table(l_index).primary_put_zone_id_rule_id)
           || ']'
           || '  Item area['
           || io_r_item_info_table(l_index).area || ']'
           || '  Item pallet TYPE['
           || io_r_item_info_table(l_index).pallet_type || ']'
           || '  Skid cube['
           || TO_CHAR(io_r_item_info_table(l_index).pt_skid_cube) || ']'
           || '  Skid height['
           || TO_CHAR(io_r_item_info_table(l_index).pt_skid_height) || ']'
           || '  Use extended case cube['
           || io_r_item_info_table(l_index).pt_ext_case_cube_flag || ']'
           || '  Case cube['
           || TO_CHAR(io_r_item_info_table(l_index).case_cube) || ']'
           || '  Extended case cube['
           ||TRIM(TO_CHAR(io_r_item_info_table(l_index).case_cube_for_calc, 9999999.9999))
           || ']'
           || '  Ti[' || TO_CHAR(io_r_item_info_table(l_index).ti) || ']'
           || '  Hi[' || TO_CHAR(io_r_item_info_table(l_index).hi) || ']'
           || '  Case home slot['
           || io_r_item_info_table(l_index).case_home_slot || ']'
           || '  Case home slot cube['
           || TO_CHAR(io_r_item_info_table(l_index).case_home_slot_cube)
           || ']'
           || '  Case home slot true slot height['
           || TO_CHAR(io_r_item_info_table(l_index).case_home_slot_true_slot_hgt)
           || ']'
           || '  Case home slot slot TYPE['
           || io_r_item_info_table(l_index).case_home_slot_slot_type || ']'
           || '  Last ship slot['
           || io_r_item_info_table(l_index).last_ship_slot || ']'
           || '  Last ship slot cube['
           || TO_CHAR(io_r_item_info_table(l_index).last_ship_slot_cube) || ']'
           || '  Last ship slot height['
           || TO_CHAR(io_r_item_info_table(l_index).last_ship_slot_height) || ']'
           || '  Split trk[' || io_r_item_info_table(l_index).split_trk || ']'
           || '  FIFO[' || io_r_item_info_table(l_index).fIFo_trk || ']'
           || '  Exp date trk['
           || io_r_item_info_table(l_index).exp_date_trk || ']'
           || '  Mfg date trk['
           || io_r_item_info_table(l_index).mfg_date_trk || ']'
           || '  Lot trk[' || io_r_item_info_table(l_index).lot_trk || ']'
           || '  Catch wt trk['
           || io_r_item_info_table(l_index).catch_wt_trk || ']'
           || '  Temp trk[' || io_r_item_info_table(l_index).temp_trk || ']'
           || '  Clam bed trk['
           || io_r_item_info_table(l_index).clam_bed_trk || ']'
           || '  TTI trk[' || io_r_item_info_table(l_index).tti_trk || ']'
           || '  COO trk[' || io_r_item_info_table(l_index).cool_trk || ']'
           || '  Aging item[' || io_r_item_info_table(l_index).aging_item || ']'
           || '  Stackable['
           || TO_CHAR(io_r_item_info_table(l_index).stackable) || ']'
           || '  Min qty['
           || TO_CHAR(io_r_item_info_table(l_index).min_qty) || ']'
           || '  Max qty['
           || TO_CHAR(io_r_item_info_table(l_index).max_qty) || ']'
           || '  Putaway floating by max qty['
           || io_r_item_info_table(l_index).pt_putaway_floating_by_max_qty || ']'
           || '  Pallet stack['
           || TO_CHAR(io_r_item_info_table(l_index).pallet_stack) || ']'
           || '  Auto ship flag['
           || io_r_item_info_table(l_index).auto_ship_flag || ']'
           || '  Case height['
           || TO_CHAR(io_r_item_info_table(l_index).case_height) || ']'
           || '  Split zone ID['
           || io_r_item_info_table(l_index).split_zone_id || ']'
           || '  Split zone rule ID['
           || TO_CHAR(io_r_item_info_table(l_index).split_zone_rule_id) || ']'
           || '  Miniload storage ind['
           || io_r_item_info_table(l_index).miniload_storage_ind || ']'
           || '  Case induction loc['
           || io_r_item_info_table(l_index).case_induction_loc || ']'
           || '  Split induction loc['
           || io_r_item_info_table(l_index).split_induction_loc || ']'
           || '  Case qty per carrier['
           || io_r_item_info_table(l_index).case_qty_per_carrier || ']'
           || '  Max ML case carriers['
           || io_r_item_info_table(l_index).max_miniload_case_carriers || ']'
           || '  Round qty to full Ti when calculating cube of existing plts['
           || io_r_item_info_table(l_index).round_inv_cube_up_to_ti_flag || ']'
           || '  Round qty to full Ti when calculating cube of receiving plt['
           || io_r_item_info_table(l_index).round_plt_cube_up_to_ti_flag || ']'
           || '  Partial plt non-deep slot search['
           || io_r_item_info_table(l_index).partial_nondeepslot_search || ']'
           || '  Floating slot sort order['
           || io_r_item_info_table(l_index).floating_slot_sort_order || ']'
           || '  putaway_to_home_slot_method(from PALLET_TYPE table, IF Y then putaway to home by min/max qty)['
           || io_r_item_info_table(l_index).putaway_to_home_slot_method || ']'
           || ' mx_item_assign_flag[' || io_r_item_info_table(l_index).mx_item_assign_flag || ']'                    -- Vani Reddy added on 9/30/2014
           || ' mx_eligible[' || io_r_item_info_table(l_index).mx_eligible || ']'
           || ' mx_min_case[' || io_r_item_info_table(l_index).mx_min_case || ']'
           || ' mx_max_case[' || io_r_item_info_table(l_index).mx_max_case || ']'
           || ' mx_food_type[' || io_r_item_info_table(l_index).mx_food_type || ']'                                 -- Vani Reddy add end on 9/30/2014
           || ' full_plt_minimize_option[' || io_r_item_info_table(l_index).full_plt_minimize_option || ']',
           NULL, NULL,
           pl_rcv_open_po_types.ct_application_function,
           gl_pkg_name);
   END IF;  -- END IF (l_found_item_bln = FALSE)

   o_index := l_index;

   DBMS_OUTPUT.PUT_LINE(l_object_name ||
                       ' ' || io_r_item_info_table(l_index).prod_id ||
                       ' ' || io_r_item_info_table(l_index).pallet_type ||
                       ' ' || io_r_item_info_table(l_index).zone_id ||
                       ' l_index[' || TO_CHAR(l_index) || ']');

EXCEPTION
   WHEN e_item_not_found THEN
      RAISE;   -- An aplog message has already been created.
   WHEN OTHERS THEN
      -- Cursor cleanup.
      IF (pl_rcv_open_po_cursors.g_c_case_home_slots%ISOPEN) THEN
         CLOSE pl_rcv_open_po_cursors.g_c_case_home_slots;
      END IF;

      l_message := l_object_name
         || '(i_r_syspars,i_prod_id,i_cust_pref_vendor,i_erm_id,o_index'
         || ',io_r_item_info_table)'
         || '  i_prod_id[' || i_prod_id || ']'
         || '  i_cust_pref_vendor[' || i_cust_pref_vendor || ']'
         || '  PO/SN[' || i_erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      DBMS_OUTPUT.PUT_LINE(SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_message);
END get_item_info;


---------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list_from_po
--
-- Description:
--    This procedure builds the list of pallets to putaway for a PO.
--
--    A partial pallet will be first IN the list for an item.
--
--    IF the erd.uom is 0, meaning receiving cases, any qty over an even number
--    of cases is dropped.  This follows the logic IN pallet_label2.pc.
--    Example:
--       erd.uom = 0
--       SPC = 6
--       erd.qty is 25.  This is 4 cases and 1 split.
--       The qty will be processed as 24.  The 1 split will be dropped.
--       An aplog message at the warning level will be created.
--
--    IF receiving splits, erd.uom is 1, the entire qty will be one pallet.
--    This follows the logic IN pallet_label2.pc.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_erm_id
--    o_r_item_info_table  - Item info for all items on the PO.  The pallet
--                           record stores the index of the item.
--    o_r_pallet_table
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/05 prpbcb   Created
--    11/07/12 prpbcb   Added
--                         MIN(d.erm_line_id) min_erm_line_id
--                      to cursor c_erd and populated the pallet record
--                      erm_line_id with it.  MIN used because it is
--                      possible for the same item to have more than one
--                      ERD record on a PO.  We just need one of them so
--                      MIN does the job.
--    08/07/14 sred5131 Added Matrix logic for Symbotic
--   09/17/14  vred5319 Modified for Symbotic  mx_eligible
--   09/26/14  vred5319 Added mx_eligible field condition for Symbotic item
--   11/25/15  spin4795 Modified for Symbotic
---------------------------------------------------------------------------
PROCEDURE build_pallet_list_from_po
    (i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
     i_erm_id             IN  erm.erm_id%TYPE,
     o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
     o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name || '.build_pallet_list_from_po';

   l_item_index            PLS_INTEGER;  -- Index of item IN item plsql table.
   l_num_full_pallets      PLS_INTEGER;  -- Number of full pallets for
                                         -- the item.
   l_num_pallets           PLS_INTEGER;  -- Number of pallets of the item
                                         -- including full and partial.
   l_num_splits            PLS_INTEGER;  -- Extra splits when receiving cases.
                                         -- These will be dropped.
   l_pallet_index          PLS_INTEGER;  -- Index
   l_pallet_qty            PLS_INTEGER;  -- Work area to hold the qty on the
                                         -- pallet (IN splits).
   l_partial_pallet_qty    PLS_INTEGER;  -- Partial pallet qty (IN splits).
   l_previous_prod_id      pm.prod_id%TYPE;  -- Previous item processed.
   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE;  -- Previous CPV
                                                           -- processed.
   l_seq_no                PLS_INTEGER := 0;  -- Seq #.  It is used to
                                              -- populate putawaylst.seq_no.
   l_qty_to_ml             PLS_INTEGER;   -- Quantity to be sent to Mini load.
   l_qty_to_wh             PLS_INTEGER;   -- Quantity to be sent to Warehouse
                                          -- (not to Mini load).
   l_qty_to_palletize      PLS_INTEGER;   -- Quantity to be broken into pallets.
   l_partial_ml_pallet_qty PLS_INTEGER;
   l_partial_wh_pallet_qty PLS_INTEGER;
   l_num_ml_full_pallets   PLS_INTEGER;  -- Number of full pallets for
                                         -- the item.
   l_num_ml_pallets        PLS_INTEGER;  -- Number of pallets of the item
                                         -- including full and partial.
   l_num_wh_full_pallets   PLS_INTEGER;  -- Number of full pallets for
                                         -- the item.
   l_num_wh_pallets        PLS_INTEGER;  -- Number of pallets of the item
                                         -- including full and partial.
   l_overflow_qty          PLS_INTEGER;
   l_qty_to_mx             PLS_INTEGER;
   l_num_mx_full_pallets   PLS_INTEGER;
   l_num_mx_pallets        PLS_INTEGER;
   l_partial_mx_pallet_qty PLS_INTEGER;
   l_putaway_qty           PLS_INTEGER;

   l_qty_in_mx             PLS_INTEGER;
   l_qty_in_wh             PLS_INTEGER;
   l_max_mx_capacity       PLS_INTEGER;
   l_remaining_mx_capacity PLS_INTEGER;

   --
   -- This cursor selects the PO to process.
   --
   -- The order is important.
   --
   -- 11/07/2012 Brian Bent  Added selecting the erm_line_id   It is possible
   -- the same item can have more than one detail record so we will use the
   -- MIN(ERM_LINE_ID).
   --
   CURSOR c_erd(cp_erm_id erd.erm_id%TYPE) IS
      SELECT NVL(d.uom, 0) uom,
             d.prod_id,
             d.cust_pref_vendor,
             pm.brand,
             pm.mfg_sku,
             pm.category,
             erm.erm_type,
             pm.mx_max_case,   -- Added for matrix
             erm.door_no, -- Story 3840 (kchi7065) Added door number column
             SUM(d.qty) total_qty,
             MIN(d.erm_line_id) min_erm_line_id
        FROM erm,
             pm,
             erd d
       WHERE erm.erm_id          = d.erm_id
         AND d.erm_id            = cp_erm_id
         AND pm.prod_id          = d.prod_id
         AND pm.cust_pref_vendor = d.cust_pref_vendor
         AND erm.status          IN ('NEW', 'SCH', 'TRF')
       GROUP BY NVL(d.uom, 0), d.prod_id, d.cust_pref_vendor, pm.brand,
                pm.mfg_sku, pm.category, erm.erm_type, pm.mx_max_case, 
                erm.door_no -- Story 3840 (kchi7065) Added door number column
       ORDER BY NVL(d.uom, 0) DESC, d.prod_id, d.cust_pref_vendor, pm.brand,
                pm.mfg_sku, pm.category, erm.erm_type;
BEGIN



   -- Initialization
   l_pallet_index := 1;

   FOR r_erd IN c_erd(i_erm_id) LOOP
      DBMS_OUTPUT.PUT_LINE('===============================================');
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
          to_char(sysdate, 'DD-MON-YYYY HH24:MI:SS') ||  ' ' ||
           r_erd.prod_id || ' ' || r_erd.cust_pref_vendor ||
           '  uom:' ||TO_CHAR(r_erd.uom) ||
           '  erd total_qty: ' || TO_CHAR(r_erd.total_qty));

      --
      -- IF the first item or a dIFferent item then get the item information
      -- and store it IN the plsql table of item records.
      -- The index of the item will be put IN l_item_index which will be
      -- saved IN the pallet table.
      --
      IF (r_erd.prod_id != NVL(l_previous_prod_id, 'x') OR
          r_erd.cust_pref_vendor !=  NVL(l_previous_cust_pref_vendor, 'x')) THEN
         get_item_info(i_r_syspars,
                       r_erd.prod_id,
                       r_erd.cust_pref_vendor,
                       i_erm_id,
                       l_item_index,
                       o_r_item_info_table);

         l_previous_prod_id := r_erd.prod_id;
         l_previous_cust_pref_vendor := r_erd.cust_pref_vendor;
      END IF;

      show_item_info(l_item_index, o_r_item_info_table);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
                ' l_item_index: ' || TO_CHAR(l_item_index) ||
                ' UOM: ' || TO_CHAR(r_erd.uom));

      --
      -- Create the pallets based on the PO qty and the items Ti Hi.
      --

      --
      -- Determine the number of full pallets and IF there is a partial pallet.
      -- IF erd.uom is 1 then receiving splits and the entire qty will be on
      -- one pallet.
      --
      IF (r_erd.uom != 1) THEN
         --
         -- Receiving cases.
         --
         -- Any splits are dropped.  These would be on the partial pallet.
         -- Note that there should not be any splits.
         --
         l_qty_to_ml := 0;
         l_qty_to_mx := 0;
         l_qty_to_wh := r_erd.total_qty;

         l_num_ml_full_pallets := 0;
         l_partial_ml_pallet_qty := 0;
         l_num_mx_full_pallets := 0;
         l_partial_mx_pallet_qty := 0;


/* Mini-load items */

         IF (o_r_item_info_table(l_item_index).miniload_storage_ind  = 'B') THEN
            get_item_ml_capacity(o_r_item_info_table(l_item_index), l_qty_to_ml, l_overflow_qty);

             -- Do not send "ship split only" inventory to mini-load reserve.
            IF (l_qty_to_ml > r_erd.total_qty OR o_r_item_info_table(l_item_index).auto_ship_flag = 'Y') THEN
               l_qty_to_ml := r_erd.total_qty;
            END IF;
            l_qty_to_wh := r_erd.total_qty - l_qty_to_ml;
            --
            -- Handle miniload overage of one carrier or less.  We do not want a pallet
            -- with less than one carrier of product to end up IN miniload reserve.
            --
            l_partial_wh_pallet_qty := MOD(l_qty_to_wh,
               o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);

            IF (l_partial_wh_pallet_qty > 0 AND
                l_partial_wh_pallet_qty <= l_overflow_qty) THEN
               l_qty_to_ml := l_qty_to_ml +
                  (TRUNC(l_partial_wh_pallet_qty/o_r_item_info_table(l_item_index).spc) *
                  o_r_item_info_table(l_item_index).spc);
               l_qty_to_wh := l_qty_to_wh -
                  (TRUNC(l_partial_wh_pallet_qty/o_r_item_info_table(l_item_index).spc) *
                  o_r_item_info_table(l_item_index).spc);
            END IF;

            l_num_ml_full_pallets := TRUNC(l_qty_to_ml/
                  (o_r_item_info_table(l_item_index).case_qty_per_carrier * o_r_item_info_table(l_item_index).spc));
            l_partial_ml_pallet_qty := MOD(l_qty_to_ml,
                   o_r_item_info_table(l_item_index).case_qty_per_carrier * o_r_item_info_table(l_item_index).spc);

/* Matrix items */

         ELSIF (o_r_item_info_table(l_item_index).mx_item_assign_flag  = 'Y' and o_r_item_info_table(l_item_index).mx_eligible = 'Y') THEN  --VR modified
            get_mx_item_inventory(o_r_item_info_table(l_item_index), i_erm_id, l_qty_in_mx, l_qty_in_wh);
            l_max_mx_capacity := o_r_item_info_table(l_item_index).mx_max_case * o_r_item_info_table(l_item_index).spc;

            dbms_output.put_line('qty in matrix=' || to_char(l_qty_in_mx) || '  qty_in_wh=' || to_char(l_qty_in_wh));
            dbms_output.put_line('max matrix capacity=' || to_char(l_max_mx_capacity));

            IF nvl(l_qty_in_wh, 0) > 0 THEN                                                         -- pallet goes to main warehouse
               l_qty_to_mx := 0;
               l_qty_to_wh := r_erd.total_qty;
            ELSE
               IF l_qty_in_mx >= l_max_mx_capacity THEN
                  l_remaining_mx_capacity := 0;
               ELSE
                  l_remaining_mx_capacity := l_max_mx_capacity - l_qty_in_mx;
               END IF;

               IF r_erd.total_qty <= l_remaining_mx_capacity THEN
                  l_qty_to_mx := r_erd.total_qty;
               ELSE
                  l_qty_to_mx := CEIL(l_remaining_mx_capacity / o_r_item_info_table(l_item_index).full_pallet_qty_in_splits) *
                                 o_r_item_info_table(l_item_index).full_pallet_qty_in_splits;
               END IF;

               IF l_qty_to_mx > r_erd.total_qty THEN
                  l_qty_to_mx := r_erd.total_qty;
               END IF;

               l_qty_to_wh := r_erd.total_qty - l_qty_to_mx;
            END IF;

            dbms_output.put_line('remaining matrix capacity=' || to_char(l_remaining_mx_capacity));

            l_num_mx_full_pallets := TRUNC(l_qty_to_mx /
                   o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);
            l_partial_mx_pallet_qty := MOD(l_qty_to_mx,
                   o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);

         END IF;

         l_num_wh_full_pallets := TRUNC(l_qty_to_wh /
                o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);
         l_partial_wh_pallet_qty :=
             MOD(l_qty_to_wh, o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);

         IF (l_partial_wh_pallet_qty > 0) THEN
            l_num_splits := MOD(l_partial_ml_pallet_qty, o_r_item_info_table(l_item_index).spc);

            IF (l_num_splits != 0) THEN
               --
               -- The partial pallet qty is not an even number of cases.
               -- Drop the extra splits.
               --
               l_partial_wh_pallet_qty := l_partial_wh_pallet_qty - l_num_splits;

               pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                  ' Item[' || o_r_item_info_table(l_item_index).prod_id || ']'
                  ||'  CPV['
                  || o_r_item_info_table(l_item_index).cust_pref_vendor || ']'
                  || '  PO/SN[' || i_erm_id || ']'
                  || '  PO Qty(IN splits)[' || TO_CHAR(r_erd.total_qty)|| ']'
                  || '  SPC['
                  || TO_CHAR(o_r_item_info_table(l_item_index).spc) || ']'
                  || '  Cases['
                  || TRUNC(r_erd.total_qty / o_r_item_info_table(l_item_index).spc)
                  || ']'
                  || '  Extra Splits[' || TO_CHAR(l_num_splits) || ']'
                  || '  Receiving cases but the qty is not an even number'
                  || ' of cases.  The splits will be dropped.',
                  NULL, NULL);
            END IF;
         END IF;

         IF (l_partial_ml_pallet_qty > 0) THEN
            l_num_ml_pallets := l_num_ml_full_pallets + 1;
         ELSE
            l_num_ml_pallets := l_num_ml_full_pallets;
         END IF;

         IF (l_partial_mx_pallet_qty > 0) THEN
            l_num_mx_pallets := l_num_mx_full_pallets + 1;
         ELSE
            l_num_mx_pallets := l_num_mx_full_pallets;
         END IF;

         IF (l_partial_wh_pallet_qty > 0) THEN
            l_num_wh_pallets := l_num_wh_full_pallets + 1;
         ELSE
            l_num_wh_pallets := l_num_wh_full_pallets;
         END IF;
      ELSE
         --
         -- Receiving splits.
         --
         -- The entire qty will be one pallet and will be treated as a
         -- partial pallet.
         --
         l_qty_to_ml := 0;
         l_qty_to_mx := 0;
         l_qty_to_wh := r_erd.total_qty;
         l_num_ml_pallets := 0;
         l_partial_ml_pallet_qty := 0;
         l_num_mx_pallets := 0;
         l_partial_mx_pallet_qty := 0;
         l_num_wh_pallets := 1;
         l_partial_wh_pallet_qty := r_erd.total_qty;
      END IF;

      dbms_output.put_line('prod_id=' || r_erd.prod_id || '  qty=' || to_char(r_erd.total_qty));
      dbms_output.put_line(' qty to ML=' || to_char(l_qty_to_ml) || '  pallets to ML=' || to_char(l_num_ml_pallets) ||
                           '  partial pallet qty=' || to_char(l_partial_ml_pallet_qty));
      dbms_output.put_line(' qty to MX=' || to_char(l_qty_to_mx) || '  pallets to MX=' || to_char(l_num_mx_pallets) ||
                           '  partial pallet qty=' || to_char(l_partial_mx_pallet_qty));
      dbms_output.put_line(' qty to WH=' || to_char(l_qty_to_wh) || '  pallets to WH=' || to_char(l_num_wh_pallets) ||
                           '  partial pallet qty=' || to_char(l_partial_wh_pallet_qty));

      FOR rep IN 1..2 LOOP
         IF (rep = 1) THEN
            IF (o_r_item_info_table(l_item_index).miniload_storage_ind  = 'B') THEN
               l_qty_to_palletize := l_qty_to_ml;
               l_num_pallets := l_num_ml_pallets;
               l_partial_pallet_qty := l_partial_ml_pallet_qty;
            ELSE
               l_qty_to_palletize := l_qty_to_mx;
               l_num_pallets := l_num_mx_pallets;
               l_partial_pallet_qty := l_partial_mx_pallet_qty;
            END IF;
         ELSE
            l_qty_to_palletize := l_qty_to_wh;
            l_num_pallets := l_num_wh_pallets;
            l_partial_pallet_qty := l_partial_wh_pallet_qty;
         END IF;

         FOR i IN 1..l_num_pallets LOOP

            l_seq_no := l_seq_no + 1;

            --
            -- Determine IF it is a full or partial pallet.
            --
            IF (i = 1 AND l_partial_pallet_qty > 0) THEN
               -- Partial pallet
               l_pallet_qty := l_partial_pallet_qty;
               o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'Y';
            ELSE
               -- Full pallet
               IF (rep = 1 AND o_r_item_info_table(l_item_index).miniload_storage_ind  = 'B') THEN
                  l_pallet_qty := o_r_item_info_table(l_item_index).case_qty_per_carrier * o_r_item_info_table(l_item_index).spc;

               ELSE
                  l_pallet_qty :=
                     o_r_item_info_table(l_item_index).full_pallet_qty_in_splits;
               END IF;

               o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'N';
            END IF;

            DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
               ' l_pallet_index: ' || TO_CHAR(l_pallet_index));

            o_r_pallet_table(l_pallet_index).pallet_id        := f_get_new_pallet_id(i_erm_id);
            o_r_pallet_table(l_pallet_index).prod_id          := r_erd.prod_id;
            o_r_pallet_table(l_pallet_index).cust_pref_vendor := r_erd.cust_pref_vendor;
            o_r_pallet_table(l_pallet_index).qty              := l_pallet_qty;
            o_r_pallet_table(l_pallet_index).qty_expected     := l_pallet_qty;
            o_r_pallet_table(l_pallet_index).qty_received     := l_pallet_qty;
            o_r_pallet_table(l_pallet_index).uom              := r_erd.uom;
            o_r_pallet_table(l_pallet_index).item_index       := l_item_index;
            o_r_pallet_table(l_pallet_index).erm_id           := i_erm_id;
            o_r_pallet_table(l_pallet_index).erm_type         := r_erd.erm_type;
            o_r_pallet_table(l_pallet_index).seq_no           := l_seq_no;
            o_r_pallet_table(l_pallet_index).po_no            := i_erm_id;
            o_r_pallet_table(l_pallet_index).erm_line_id      := r_erd.min_erm_line_id;
            -- Story 3840 (kchi7065) Added door number column
            o_r_pallet_table(l_pallet_index).door_no          := r_erd.door_no;
            -- o_r_pallet_table(l_pallet_index).case_pallet := r_erd.case_pallet;
            
            IF (o_r_item_info_table(l_item_index).mx_item_assign_flag = 'Y' AND o_r_item_info_table(l_item_index).mx_eligible = 'Y') THEN  --VR modified
               -- Vani Reddy modified on 9/17/2014
               dbms_output.put_line('vani ----going ---l_qty_to_wh'||l_qty_to_wh );
               dbms_output.put_line('max_case * spc'||(o_r_item_info_table(l_item_index).mx_max_case * o_r_item_info_table(l_item_index).spc) );

               IF rep = 1 OR l_qty_to_wh = 0 THEN
                  o_r_pallet_table(l_pallet_index).matrix_reserve := FALSE;
                  o_r_pallet_table(l_pallet_index).direct_to_mx_induction_loc_bln := TRUE; -- The pallet is going to the matrix induction location.
               ELSE
                  o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;
               END IF;
            ELSIF (o_r_item_info_table(l_item_index).miniload_storage_ind = 'B') THEN
               --
               -- Miniload item with cases/splits in the miniloader.
               -- Flag if the pallet is going to the induction location or the main warehouse.
               --
               IF rep = 1 OR l_qty_to_wh = 0 THEN
                  o_r_pallet_table(l_pallet_index).miniload_reserve               := FALSE;  -- The pallet is not going to the main warehouse reserve. 
                  o_r_pallet_table(l_pallet_index).direct_to_ml_induction_loc_bln := TRUE;   -- The pallet as going to the miniloader induction location.
               ELSE
                  o_r_pallet_table(l_pallet_index).miniload_reserve := TRUE;  -- The pallet is going to the main warehouse reserve.
               END IF;

            ELSIF (o_r_item_info_table(l_item_index).mx_item_assign_flag = 'Y' AND nvl(o_r_item_info_table(l_item_index).mx_eligible, 'X') <> 'Y') THEN  
               o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;        -- pallet goes to main warehouse               -- Vani Reddy modification end on 9/17/2014
            END IF;

            dbms_output.put(' pallet index=' || to_char(l_pallet_index));
            IF o_r_pallet_table(l_pallet_index).miniload_reserve THEN
               dbms_output.put('  miniload reserve');
            END IF;
            IF o_r_pallet_table(l_pallet_index).matrix_reserve THEN
               dbms_output.put('  matrix reserve');
            END IF;
            dbms_output.put_line('');

            --
            -- Determine IF the pallet should be directed only to empty slots.
            -- This applies when going to reserve or floating.  It does not apply
            -- for bulk rule zones.
            --
            -- Receiving splits will always to an empty reserve/floating slot
            -- IF the splits cannot go to the home slot.
            --

            IF (o_r_pallet_table(l_pallet_index).uom = 1) THEN
               o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln := TRUE;

               pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  ' Item[' || o_r_item_info_table(l_item_index).prod_id || ']'
                  ||' CPV[' || o_r_item_info_table(l_item_index).cust_pref_vendor
                  || ']'
                  || ' PO/SN[' || i_erm_id || ']'
                  || '  Receiving splits.  The pallet will be directed only to'
                  || ' open slots IF it cannot go to the home slot or it is'
                  || ' a floating item.  The pallet will always be'
                  || ' considered a partial pallet.',
                  NULL, NULL);
            ELSE
               o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln := FALSE;

            END IF;

            --
            -- Calculate the cube and height of the pallet and other stuff.
            --

            determine_pallet_attributes(o_r_item_info_table(l_item_index),
                                        l_pallet_index,
                                        o_r_pallet_table);

            l_pallet_index := l_pallet_index + 1;
         END LOOP;  -- end pallet loop
      END LOOP; -- end rep loop
   END LOOP;  -- end erd loop
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,i_erm_id,o_r_item_info_table,o_r_pallet_table)'
         || '  PO/SN[' || i_erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END build_pallet_list_from_po;


---------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list_from_sn
--
-- Description:
--    This procedure builds the list of pallets to putaway for a SN.
--    Each line item on the SN is a pallet except for MSKU pallets.
--    MSKU pallets are handled by pl_msku.sql
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_erm_id             - SN number to build pallet list for.
--    o_r_item_info_table  - Item info for all items on the SN.  The pallet
--                           record stores the index of the item.
--    o_r_pallet_table     - List of pallets to putaway.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/05 prpbcb   Created
--
--    04/01/10 ctvgg000 Included a union to cursor c_sn_line_item to select
--            VNs related pallet information from the ERD LPN
--            table and do not consider the ERD table as it might
--            have a the dIFferent PO line number than what is IN
--            IN ERD_LPN. - DN 12572
--
--    11/07/12 prpbcb      Populate the pallet record erm_line_id.
--    09/30/14 Vani Reddy  Added Matrix logic for Symbotic
---------------------------------------------------------------------------
PROCEDURE build_pallet_list_from_sn
      (i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
       i_erm_id             IN  erm.erm_id%TYPE,
       o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
       o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := gl_pkg_name || '.build_pallet_list_from_sn';

   l_item_index            PLS_INTEGER;  -- Index of item IN item plsql table.
   l_num_full_pallets      PLS_INTEGER;  -- Number of full pallets for
                                         -- the item.
   l_num_pallets           PLS_INTEGER;  -- Number of pallets of the item
                                         -- including full and partial.
   l_pallet_index          PLS_INTEGER;  -- Index
   l_partial_pallet_qty    PLS_INTEGER;  -- Partial pallet qty (IN splits).
   l_previous_prod_id      pm.prod_id%TYPE := 'x';  -- Previous item
                                                    -- processed.
   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE := 'x'; --Previous CPV
                                                                 -- processed.
   l_qty_in_mx             PLS_INTEGER;
   l_num_mx_full_pallets   PLS_INTEGER;
   l_partial_mx_pallet_qty PLS_INTEGER;
   l_overflow_qty          PLS_INTEGER;
   l_qty_in_wh             PLS_INTEGER;
   l_partial_wh_pallet_qty PLS_INTEGER;
   l_qty_added_to_mx       PLS_INTEGER;                 -- Vani Reddy added on 9/30/2014
   --
   -- This cursor selects the SN line item info for non-MKSU pallets.
   -- For each record a pallet is created IN the pallet list.
   --
   -- The ordering is important.
   --
   CURSOR c_sn_line_item(cp_erm_id erd.erm_id%TYPE) IS
    SELECT NVL(d.UOM, 0)         UOM,
             d.prod_id            prod_id,
             d.cust_pref_vendor        cust_pref_vendor,
             PM.brand            brand,
             PM.mfg_sku            mfg_sku,
             PM.category        category,
             d.qty            qty,
             erm.erm_id            erm_id,
             ERM.erm_type        erm_type,
             d.erm_line_id        erm_line_id,
             ERD_LPN.po_no        po_no,
             ERD_LPN.po_line_id        po_line_id,
             ERD_LPN.pallet_id        pallet_id,
             ERD_LPN.shipped_ti        shipped_ti,
             ERD_LPN.shipped_hi        shipped_hi,
             ERD_LPN.temp        temp,
             ERD_LPN.pallet_type    pallet_type,
             ERD_LPN.catch_weight    catch_weight,
             ERD_LPN.exp_date        exp_date,
             ERD_LPN.mfg_date        mfg_date,
             ERD_LPN.lot_id        lot_id, 
             -- Story 3840 (kchi7065) Added door number column
             erm.door_no           door_no
        FROM ERM,
             PM,
             ERD d,
             ERD_LPN
       WHERE erm.erm_id                    = d.erm_id
         AND d.erm_id                    = cp_erm_id
         AND d.erm_line_id                = ERD_LPN.erm_line_id
         AND ERD_LPN.sn_no                = cp_erm_id
         AND PM.prod_id                    = d.prod_id
         AND PM.cust_pref_vendor            = d.cust_pref_vendor
         AND ERD_LPN.parent_pallet_id  IS NULL
         AND NVL(ERD_LPN.pallet_assigned_flag, 'N')     = 'N'
         AND ERM.status                            IN ('NEW', 'SCH')
     AND ERM.ERM_TYPE                 = 'SN'
    UNION ALL
       SELECT 0               UOM,
         -- Always UOM from vendor is 0, Vendor will always send cases.
             ERD_LPN.prod_id           prod_id,
             ERD_LPN.cust_pref_vendor    cust_pref_vendor,
             PM.brand            brand,
             PM.mfg_sku            mfg_sku,
             PM.category        category,
             ERD_LPN.qty        qty,
             erm.erm_id            erm_id,
             ERM.erm_type        erm_type,
             ERD_LPN.erm_line_id    erm_line_id,
             ERD_LPN.po_no        po_no,
             ERD_LPN.po_line_id        po_line_id,
             ERD_LPN.pallet_id        pallet_id,
             ERD_LPN.shipped_ti        shipped_ti,
             ERD_LPN.shipped_hi        shipped_hi,
             ERD_LPN.temp        temp,
             ERD_LPN.pallet_type    pallet_type,
             ERD_LPN.catch_weight    catch_weight,
             ERD_LPN.exp_date        exp_date,
             ERD_LPN.mfg_date        mfg_date,
             ERD_LPN.lot_id        lot_id, 
             -- Story 3840 (kchi7065) Added door number column
             erm.door_no           door_no
        FROM ERM,
             PM,
             ERD_LPN
       WHERE erm.erm_id            = erd_lpn.sn_no
         AND ERD_LPN.sn_no        = cp_erm_id
         AND ERD_LPN.prod_id         = PM.prod_id
         AND ERD_LPN.cust_pref_vendor    = PM.cust_pref_vendor
         AND ERD_LPN.parent_pallet_id   IS NULL
         AND NVL(ERD_LPN.pallet_assigned_flag, 'N') = 'N'
            AND ERM.status                    IN ('NEW', 'SCH')
     AND ERM.ERM_TYPE         = 'VN'
       ORDER BY 1 DESC, -- uom
                2,     -- prod_id
                3,       -- cpv
                19,     -- exp_date
                7,      -- qty
                4,      -- brand,
                5,      -- mfg_sku,
                6,      -- category,
                13;     -- pallet_id

BEGIN

   --
   -- Initialization
   --
   l_pallet_index := 1;

   --
   -- Process each line item on the SN.  Each line item will be a pallet.
   --
   FOR r_sn_line_item IN c_sn_line_item(i_erm_id) LOOP
      DBMS_OUTPUT.PUT_LINE('=================================================================');
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
           r_sn_line_item.prod_id || ' ' || r_sn_line_item.cust_pref_vendor ||
           '  uom:' ||TO_CHAR(r_sn_line_item.uom) ||
           '  erd qty: ' || TO_CHAR(r_sn_line_item.qty));

      --
      -- IF the first item or a dIFferent item then get the item information
      -- and store it IN the plsql table of item records.
      -- The index of the item will be put IN l_item_index which will be
      -- saved IN the pallet table.
      --
      IF (r_sn_line_item.prod_id != NVL(l_previous_prod_id, 'x') OR
  r_sn_line_item.cust_pref_vendor != NVL(l_previous_cust_pref_vendor, 'x')) THEN
         get_item_info(i_r_syspars,
                       r_sn_line_item.prod_id,
                       r_sn_line_item.cust_pref_vendor,
                       i_erm_id,
                       l_item_index,
                       o_r_item_info_table);

         l_num_full_pallets := 1;
         l_num_pallets := 1;
         l_previous_prod_id := r_sn_line_item.prod_id;
         l_previous_cust_pref_vendor := r_sn_line_item.cust_pref_vendor;
         l_qty_added_to_mx := 0;

DBMS_OUTPUT.PUT_LINE('o_r_item_info_table.COUNT: ' ||
                  o_r_item_info_table.COUNT);

      END IF;

         l_num_mx_full_pallets := 0;
         l_partial_mx_pallet_qty := 0;
         l_qty_in_mx := 0;
      
      -- Vani Reddy added on 9/30/2014
      IF (o_r_item_info_table(l_item_index).mx_item_assign_flag = 'Y' AND
          NVL(o_r_item_info_table(l_item_index).mx_eligible,'N') = 'Y' )
      THEN
            get_mx_item_inventory(o_r_item_info_table(l_item_index), i_erm_id, l_qty_in_mx, l_qty_in_wh);     
      END IF;

      show_item_info(l_item_index, o_r_item_info_table);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
                ' l_item_index: ' || TO_CHAR(l_item_index));
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
                  ' l_pallet_index: ' || TO_CHAR(l_pallet_index));

      o_r_pallet_table(l_pallet_index).pallet_id   := r_sn_line_item.pallet_id;
      o_r_pallet_table(l_pallet_index).prod_id     := r_sn_line_item.prod_id;
      o_r_pallet_table(l_pallet_index).cust_pref_vendor :=
                                             r_sn_line_item.cust_pref_vendor;
      o_r_pallet_table(l_pallet_index).qty           := r_sn_line_item.qty;
      o_r_pallet_table(l_pallet_index).qty_expected  := r_sn_line_item.qty;
      o_r_pallet_table(l_pallet_index).qty_received  := r_sn_line_item.qty;
      o_r_pallet_table(l_pallet_index).uom         := r_sn_line_item.uom;
      o_r_pallet_table(l_pallet_index).item_index  := l_item_index;
      o_r_pallet_table(l_pallet_index).erm_id      := r_sn_line_item.erm_id;
      o_r_pallet_table(l_pallet_index).erm_type    := r_sn_line_item.erm_type;
      o_r_pallet_table(l_pallet_index).erm_line_id  := r_sn_line_item.erm_line_id;
      o_r_pallet_table(l_pallet_index).seq_no    := r_sn_line_item.erm_line_id;
      o_r_pallet_table(l_pallet_index).sn_no       := r_sn_line_item.erm_id;
      o_r_pallet_table(l_pallet_index).po_no       := r_sn_line_item.po_no;
      o_r_pallet_table(l_pallet_index).po_line_id  := r_sn_line_item.po_line_id;
      o_r_pallet_table(l_pallet_index).shipped_ti  :=
                                                r_sn_line_item.shipped_ti;
      o_r_pallet_table(l_pallet_index).shipped_hi  :=
                                                r_sn_line_item.shipped_hi;
      o_r_pallet_table(l_pallet_index).temp        := r_sn_line_item.temp;
      o_r_pallet_table(l_pallet_index).sn_pallet_type :=
                                               r_sn_line_item.pallet_type;
      o_r_pallet_table(l_pallet_index).catch_weight :=
                                               r_sn_line_item.catch_weight;
      o_r_pallet_table(l_pallet_index).exp_date := r_sn_line_item.exp_date;
      o_r_pallet_table(l_pallet_index).mfg_date := r_sn_line_item.mfg_date;
      o_r_pallet_table(l_pallet_index).lot_id   := r_sn_line_item.lot_id;
      -- Story 3840 (kchi7065) Added door number column
      o_r_pallet_table(l_pallet_index).door_no  := r_sn_line_item.door_no;

      l_message := ' Item['                  || o_r_item_info_table(l_item_index).prod_id              || ']'
           || '  SPC['                       || TO_CHAR(o_r_item_info_table(l_item_index).spc)         || ']'
           || '  Item mx_eligible['          || o_r_item_info_table(l_item_index).mx_eligible          || ']'
           || '  Item mx_item_assign_flag['  || o_r_item_info_table(l_item_index).mx_item_assign_flag  || ']'
           || '  Item mx_max_splits['
           || TO_CHAR(o_r_item_info_table(l_item_index).mx_max_case * o_r_item_info_table(l_item_index).spc) || ']'
           || '  PO/SN['                     || i_erm_id                           || ']'
           || '  o_mx_qty_in_splits['        || TO_CHAR(l_qty_in_mx)        || ']'
           || '  o_warehouse_qty_in_splits[' || TO_CHAR(l_qty_in_wh) || ']';

      --
      -- Determine IF the pallet should be directed only to empty slots.
      -- This applies when going to reserve or floating.  Does not apply
      -- for bulk rule zones.
      --
      -- Receiving splits will always to an empty reserve/floating slot
      -- IF the splits cannot go to the home slot.
      -- Note: A SN should not have splits.
      --

      IF (o_r_item_info_table(l_item_index).mx_item_assign_flag  = 'Y' AND
          NVL(o_r_item_info_table(l_item_index).mx_eligible,'N') = 'Y') THEN  
            IF NVL(l_qty_in_wh, 0) > 0 THEN
                -- pallet goes to main warehouse
                o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;
                l_message := l_message || '  Send to warehouse (item in warehouse)';
                dbms_output.put_line('to warehouse (item in warehouse)');
            ELSIF (NVL(l_qty_in_mx, 0) + l_qty_added_to_mx) >=
                   (o_r_item_info_table(l_item_index).mx_max_case * o_r_item_info_table(l_item_index).spc) THEN
                -- pallet goes to main warehouse
                o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;
                l_message := l_message || '  Send to warehouse (matrix full)';
                dbms_output.put_line('to warehouse (matrix full)');
            ELSE    
                o_r_pallet_table(l_pallet_index).matrix_reserve := FALSE;
                -- pallet goes to matrix             l_qty_added_to_mx := l_qty_added_to_mx + o_r_pallet_table(l_pallet_index).qty_received;
                l_message := l_message || '  Send to matrix';
                dbms_output.put_line('to matrix (qty_in_mx: ' || to_char(l_qty_in_mx) || 
                                  '  qty_added_to_mx: ' || to_char(l_qty_added_to_mx) || ')');
            END IF; 
      ELSIF (o_r_item_info_table(l_item_index).mx_item_assign_flag  = 'Y' AND 
             NVL(o_r_item_info_table(l_item_index).mx_eligible,'N') <> 'Y') THEN  
            o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;  -- pallet goes to main warehouse
            l_message := l_message || '  Send to warehouse (mx item not eligible)';
            dbms_output.put_line('to warehouse (mx item not eligible)');
      ELSE
         IF (o_r_pallet_table(l_pallet_index).uom = 1) THEN
             o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln := TRUE;
             pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  ' Item[' || o_r_item_info_table(l_item_index).prod_id || ']'
                  ||' CPV[' || o_r_item_info_table(l_item_index).cust_pref_vendor
                  || ']'
                  || ' PO/SN[' || i_erm_id || ']'
                  || '  Receiving splits.  The pallet will be directed only to'
                  || ' open slots IF it cannot go to the home slot or it is'
                  || ' a floating item.  The pallet will always be'
                  || ' considered a partial pallet.',
                  NULL, NULL);
         ELSE
             o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln := FALSE;
             dbms_output.put_line('do not direct only to open slot');
         END IF;
      END IF;

      --
      -- Determine IF it is a full or partial pallet.
      --
      IF (o_r_pallet_table(l_pallet_index).qty_received >=
                                  (o_r_item_info_table(l_item_index).spc *
                                   o_r_item_info_table(l_item_index).ti *
                                   o_r_item_info_table(l_item_index).hi)) THEN
         o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'N';
      ELSE
         o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'Y';
      END IF;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
           l_message, NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      --
      -- Calculate the cube and height of the pallet and other stuff.
      --
      determine_pallet_attributes(o_r_item_info_table(l_item_index),
                                  l_pallet_index,
                                  o_r_pallet_table);

      l_pallet_index := l_pallet_index + 1;

   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,i_erm_id,o_r_item_info_table,o_r_pallet_table)'
         || '  PO/SN[' || i_erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END build_pallet_list_from_sn;

---------------------------------------------------------------------------
-- Procedure:
--    log_how_sn_pallet_split
--
-- Description:
--    This procedure logs how an SN pallet was split.
--
--    The messages will look something like this:
--           SN pallet ___ split into ___ new pallet(s).
--           Original SN pallet qty: ___  Exp Date: ___  Mfg Date: ___
--           The new pallets are:
--           New pallet: ___  Qty: ___  Exp Date: ___  Mfg Date: ___
--           ......
--
--           New pallet ______ created from SN pallet(s):
--           New pallet qty: ___  Exp Date: ___  Mfg Date: ___
--           The SN pallets the new pallet was created from are:
--           SN pallet: ___  Qty: ___  Exp Date: ___  Mfg Date: ___
--           ...  ...
--
-- Parameters:
--    i_r_how_sn_pallet_split_table  - PL/SQL table with details on how the SN
--                                 pallets were split.
--    i_r_item_info_table  - Item info for all items on the PO.  The pallet
--                           record stores the index of the item.
--    i_r_pallet_table     - List of pallets to putaway.
--
--    i_erm_id - PO/SN being processed.  Used only IN the log messages.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list_from_sn_splt
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/05/09 prpbcb   Created as part of the changes to split a SN
--                      pallet when the qty is greater than the SWMS
--                      Ti Hi.
---------------------------------------------------------------------------
PROCEDURE log_how_sn_pallet_split
 (i_r_how_sn_pallet_split_table  IN
                        pl_rcv_open_po_types.t_r_how_sn_pallet_split_table,
  i_r_item_info_table        IN pl_rcv_open_po_types.t_r_item_info_table,
  i_r_pallet_table           IN pl_rcv_open_po_types.t_r_pallet_table,
  i_erm_id                   IN erm.erm_id%TYPE)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'log_how_sn_pallet_split';

   l_index             PLS_INTEGER;
   l_item_index        PLS_INTEGER;  -- Index an item IN i_r_item_info_table
   l_new_pallet_index  PLS_INTEGER;  -- Index of SN pallet IN i_r_pallet_table
   l_sn_pallet_index   PLS_INTEGER;  -- Index of new pallet IN i_r_pallet_table
BEGIN
   l_index := i_r_how_sn_pallet_split_table.FIRST;

   DBMS_OUTPUT.PUT_LINE('======== Start log_how_sn_pallet_split ============');

   WHILE (l_index <= i_r_how_sn_pallet_split_table.LAST) LOOP
      --
      -- Assign index values to local variables so we can use shorter variable
      -- names.
      --
      l_new_pallet_index :=
                    i_r_how_sn_pallet_split_table(l_index).new_pallet_index;
      l_sn_pallet_index :=
                    i_r_how_sn_pallet_split_table(l_index).sn_pallet_index;
      l_item_index := i_r_pallet_table(l_sn_pallet_index).item_index;


      l_message := 'l_index: ' || TO_CHAR(l_index)
           || '  SN pallet index: '
           || TO_CHAR(i_r_how_sn_pallet_split_table(l_index).sn_pallet_index)
           || '  Qty: '
           || TO_CHAR(i_r_how_sn_pallet_split_table(l_index).qty)
           || '  New pallet index: '
           || TO_CHAR(i_r_how_sn_pallet_split_table(l_index).new_pallet_index);

      --
      -- Debug stuff
      -- pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
      --             NULL, NULL,
      --             pl_rcv_open_po_types.ct_application_function,
      --             gl_pkg_name);
      --

      DBMS_OUTPUT.PUT_LINE(l_message);

      --
      --  6/10/09 Brian Bent  old style message
      -- l_message := 'SN LP '
      -- || i_r_pallet_table(l_sn_pallet_index).pallet_id
      -- || ' Exp Date: '
      -- || TO_CHAR(i_r_pallet_table(l_sn_pallet_index).exp_date, 'MM/DD/YYYY')
      -- || ' Mfg Date: '
      -- || TO_CHAR(i_r_pallet_table(l_sn_pallet_index).mfg_date, 'MM/DD/YYYY')
      -- || ' '
      -- || TO_CHAR(i_r_how_sn_pallet_split_table(l_index).qty /
      --                    i_r_item_info_table(l_item_index).spc)
      -- || ' cases moved to LP:'
      -- || i_r_pallet_table(l_new_pallet_index).pallet_id
      -- || ' Exp Date: '
      -- || TO_CHAR(i_r_pallet_table(l_new_pallet_index).exp_date, 'MM/DD/YYYY')
      -- || ' Mfg Date: '
      -- || TO_CHAR(i_r_pallet_table(l_new_pallet_index).mfg_date, 'MM/DD/YYYY');
      --

      l_message := 'SN ' || i_erm_id
       || '  SN LP '
       || i_r_pallet_table(l_sn_pallet_index).pallet_id
       || ' split.  '
       || TO_CHAR(i_r_how_sn_pallet_split_table(l_index).qty /
                          i_r_item_info_table(l_item_index).spc)
       || ' case(s) moved to LP '
       || i_r_pallet_table(l_new_pallet_index).pallet_id;

      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      l_index := i_r_how_sn_pallet_split_table.NEXT(l_index);
   END LOOP;

   DBMS_OUTPUT.PUT_LINE('======== End log_how_sn_pallet_split ============');

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
                   || '(i_r_how_sn_pallet_split_table,'
                   || '  PO/SN[' || i_erm_id || '])';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END log_how_sn_pallet_split;


---------------------------------------------------------------------------
-- Procedure:
--    build_additional_pallets
--
-- Description:
--    This procedure builds the new pallets as the result of splitting a
--    SN pallet.
--
--    The program logic is similar to that IN procedure
--    build_pallet_list_from_po().
--
--    This handles receiving cases only.  Do not use this procedure when
--    receiving splits.
--
-- Parameters:
--    io_r_pallet_table
--    io_seq_no
--    i_r_item_info
--    i_qty_over_ti_hi_in_splits
--    i_oldest_exp_date
--    i_oldest_mfg_date
--    i_new_lp_catch_weight
--    i_last_sn_pallet_exp_date  - Expiration date to use for 2nd new pallet
--                                 (IF two new pallets created)
--    i_last_sn_pallet_mfg_date  - Mfg date to use for 2nd new pallet.
--                                 (IF two new pallets created)
--    io_r_how_sn_pallet_split_table - PL/SQL table with details on how the SN
--                                 pallet was split.
--                                 Used to create log messages.
--    i_sn_pallet_index - The index IN the PL/SQL table of the SN pallet being
--                        split.  Used to populate the sn_pallet_index field IN
--                        the io_r_how_sn_pallet_split_table PL/SQL table
--                        when addition records are created IN
--                        io_r_how_sn_pallet_split_table
--    i_erm_id
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list_from_sn_splt
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/13/09 prpbcb   Created as part of the changes to split a SN
--                      pallet when the qty is greater than the SWMS
--                      Ti Hi.
---------------------------------------------------------------------------
PROCEDURE build_additional_pallets
    (io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table,
     io_seq_no                   IN OUT PLS_INTEGER,
     i_r_item_info               IN     pl_rcv_open_po_types.t_r_item_info,
     i_qty_over_ti_hi_in_splits  IN     NUMBER,
     i_oldest_exp_date           IN     DATE,
     i_oldest_mfg_date           IN     DATE,
     i_new_lp_catch_weight       IN     NUMBER,
     i_last_sn_pallet_exp_date   IN     DATE,
     i_last_sn_pallet_mfg_date   IN     DATE,
     io_r_how_sn_pallet_split_table  IN OUT NOCOPY
                           pl_rcv_open_po_types.t_r_how_sn_pallet_split_table,
     i_sn_pallet_index           IN     PLS_INTEGER,
     i_erm_id                    IN     erm.erm_id%TYPE)  -- for error msgs
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(61) := 'build_additional_pallets';

   l_r_source_pallet       pl_rcv_open_po_types.t_r_pallet;  -- The pallet
                                         -- that will be used as the "source
                                         -- information" pallet for the new
                                         -- pallet.

   l_item_index            PLS_INTEGER;  -- Index of item IN item plsql table.
   l_num_full_pallets      PLS_INTEGER;  -- Number of full pallets for
                                         -- the item.
   l_num_pallets           PLS_INTEGER;  -- Number of pallets of the item
                                         -- including full and partial.
   l_num_splits            PLS_INTEGER;  -- Extra splits when receiving cases.
                                         -- These will be dropped.
   l_pallet_index          PLS_INTEGER;  -- Index
   l_pallet_qty            PLS_INTEGER;  -- Work area to hold the qty on the
                                         -- pallet (IN splits).
   l_partial_pallet_qty    PLS_INTEGER;  -- Partial pallet qty (IN splits).

   l_split_pallet_index    PLS_INTEGER;  -- Index for the PL/SQL table that
                                         -- has the details on how the SN
                                         -- pallet was split.  This PL/SQL
                                         -- table will be used to create log
                                         -- message detailing how the SN pallet
                                         -- was split.

BEGIN
   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
              ' Starting procedure'
              || '  i_erm_id[' || i_erm_id || ']'
              || '  i_qty_over_ti_hi_in_splits['
              || TO_CHAR(i_qty_over_ti_hi_in_splits) || ']'
              || '  i_r_item_info.prod_id[' || i_r_item_info.prod_id || ']',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function,
              gl_pkg_name);

   --
   -- Initialization
   --
   l_pallet_index := NVL(io_r_pallet_table.LAST, 0) + 1;  -- Used NVL though
                                        -- at this point IN the processing
                                        -- there should be least one pallet IN
                                        -- the PL/SQL table.

   -- Brian Bent - I need to add more validation to this such as checking
   -- the plsql table is not empty.
   l_r_source_pallet := io_r_pallet_table(io_r_pallet_table.LAST);


   DBMS_OUTPUT.PUT_LINE('Starting ' || l_object_name
     || '  l_pallet_index: ' || TO_CHAR(l_pallet_index)
     || '  l_r_source_pallet.prod_id: ' || l_r_source_pallet.prod_id
     || '  i_qty_over_ti_hi_in_splits: ' || TO_CHAR(i_qty_over_ti_hi_in_splits)
     || '  i_new_lp_catch_weight: '
     || TO_CHAR(i_new_lp_catch_weight, '99999.999'));
   DBMS_OUTPUT.PUT_LINE(l_object_name
     || '  i_oldest_exp_date: ' || TO_CHAR(i_oldest_exp_date, 'MM/DD/YYYY')
     || '  i_oldest_mfg_date: ' || TO_CHAR(i_oldest_mfg_date, 'MM/DD/YYYY')
     || '  i_last_sn_pallet_exp_date: '
     || TO_CHAR(i_last_sn_pallet_exp_date, 'MM/DD/YYYY')
     || '  i_last_sn_pallet_mfg_date: '
     || TO_CHAR(i_last_sn_pallet_mfg_date, 'MM/DD/YYYY'));

   --
   -- Create the pallets based on i_qty_over_ti_hi_in_splits and the items
   -- Ti Hi.
   --
   -- Determine the number of full pallets and IF there is a partial pallet.
   --
   -- Any splits are dropped.  These would be on the partial pallet.
   -- Note that there should not be any splits.
   --
   l_num_full_pallets := TRUNC(i_qty_over_ti_hi_in_splits /
                         i_r_item_info.full_pallet_qty_in_splits);

   l_partial_pallet_qty := MOD(i_qty_over_ti_hi_in_splits,
                               i_r_item_info.full_pallet_qty_in_splits);

   IF (l_partial_pallet_qty > 0) THEN
      l_num_splits :=
            MOD(l_partial_pallet_qty, i_r_item_info.spc);

      IF (l_num_splits != 0) THEN
         --
         -- The partial pallet qty is not an even number of cases.
         -- Drop the extra splits.
         --
         l_partial_pallet_qty := l_partial_pallet_qty  - l_num_splits;

         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                  ' Item[' || i_r_item_info.prod_id || ']'
                  ||'  CPV['
                  || i_r_item_info.cust_pref_vendor || ']'
                  || '  PO/SN[' || l_r_source_pallet.po_no || ']'
                  || '  i_qty_over_ti_hi_in_splits(IN splits)['
                  || TO_CHAR(i_qty_over_ti_hi_in_splits) || ']'
                  || '  SPC['
                  || TO_CHAR(i_r_item_info.spc) || ']'
                  || '  Cases['
                  || TRUNC(i_qty_over_ti_hi_in_splits / i_r_item_info.spc)
                  || ']'
                  || '  Extra Splits[' || TO_CHAR(l_num_splits) || ']'
                  || '  Processing qty as cases but the qty is not an even'
                  || ' number of cases.  The splits will be dropped.',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      END IF;
   END IF;  -- END IF (l_partial_pallet_qty > 0)

   IF (l_partial_pallet_qty > 0) THEN
      l_num_pallets := l_num_full_pallets + 1;
   ELSE
      l_num_pallets := l_num_full_pallets;
   END IF;

   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
              '  l_num_pallets[' || TO_CHAR(l_num_pallets) || ']',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function,
              gl_pkg_name);



   l_split_pallet_index := io_r_how_sn_pallet_split_table.FIRST;

   WHILE (l_split_pallet_index <= io_r_how_sn_pallet_split_table.LAST
          AND
        io_r_how_sn_pallet_split_table(l_split_pallet_index).new_pallet_index
                                            IS NOT NULL)
   LOOP
      l_split_pallet_index :=
                  io_r_how_sn_pallet_split_table.NEXT(l_split_pallet_index);
   END LOOP;

   IF (l_split_pallet_index IS NULL) THEN
      l_split_pallet_index := io_r_how_sn_pallet_split_table.LAST + 1;
   END IF;

   DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
               ' l_split_pallet_index: ' || TO_CHAR(l_split_pallet_index));


   FOR i IN 1..l_num_pallets LOOP

      io_seq_no := io_seq_no + 1;

      --
      -- Determine IF it is a full or partial pallet.
      --
      IF (i = 1 AND l_partial_pallet_qty > 0) THEN
         -- Partial pallet
         l_pallet_qty := l_partial_pallet_qty;
         io_r_pallet_table(l_pallet_index).partial_pallet_flag := 'Y';
      ELSE
         -- Full pallet
         l_pallet_qty :=
            i_r_item_info.full_pallet_qty_in_splits;
         io_r_pallet_table(l_pallet_index).partial_pallet_flag := 'N';
      END IF;

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
               ' l_pallet_index: ' || TO_CHAR(l_pallet_index));

      io_r_pallet_table(l_pallet_index).pallet_id :=
                                f_get_new_pallet_id(l_r_source_pallet.erm_id);
      io_r_pallet_table(l_pallet_index).prod_id   := l_r_source_pallet.prod_id;
      io_r_pallet_table(l_pallet_index).cust_pref_vendor :=
                                          l_r_source_pallet.cust_pref_vendor;
      io_r_pallet_table(l_pallet_index).qty       := l_pallet_qty;
      io_r_pallet_table(l_pallet_index).uom       := l_r_source_pallet.uom;
      io_r_pallet_table(l_pallet_index).item_index :=
                                          l_r_source_pallet.item_index;
      io_r_pallet_table(l_pallet_index).erm_id    := l_r_source_pallet.erm_id;
      io_r_pallet_table(l_pallet_index).erm_type  := l_r_source_pallet.erm_type;
      io_r_pallet_table(l_pallet_index).erm_line_id  :=
                                               l_r_source_pallet.erm_line_id;
      io_r_pallet_table(l_pallet_index).seq_no    := io_seq_no;
      io_r_pallet_table(l_pallet_index).sn_no     := l_r_source_pallet.sn_no;
      io_r_pallet_table(l_pallet_index).po_no     := l_r_source_pallet.po_no;
      io_r_pallet_table(l_pallet_index).po_line_id  :=
                                               l_r_source_pallet.po_line_id;
      io_r_pallet_table(l_pallet_index).temp        := l_r_source_pallet.temp;
      io_r_pallet_table(l_pallet_index).sn_pallet_type :=
                                               l_r_source_pallet.sn_pallet_type;
      io_r_pallet_table(l_pallet_index).catch_weight := i_new_lp_catch_weight;

      --
      -- First time through loop the old dates used.
      -- There after the last SN pallets dates used.
      --
      IF (i = 1) THEN
         --
         -- First time through loop.  Use the old dates.
         --
 DBMS_OUTPUT.PUT_LINE(l_object_name || ' 88888888888888888888888');
         io_r_pallet_table(l_pallet_index).exp_date := i_oldest_exp_date;
         io_r_pallet_table(l_pallet_index).mfg_date := i_oldest_mfg_date;
      ELSE
 DBMS_OUTPUT.PUT_LINE(l_object_name || ' 99999999999999999999999');
         io_r_pallet_table(l_pallet_index).exp_date :=
                                             i_last_sn_pallet_exp_date;
         io_r_pallet_table(l_pallet_index).mfg_date :=
                                             i_last_sn_pallet_mfg_date;
      END IF;

      io_r_pallet_table(l_pallet_index).lot_id   := l_r_source_pallet.lot_id;

      --
      -- Determine IF the pallet should be directed only to empty slots.
      -- This applies when going to reserve or floating.  It does not apply
      -- for bulk rule zones.
      --
      -- This procedure is only processing cases and we want to use the
      -- normal procesing when finding a slot so set the flag to FALSE.
      --
      io_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln :=
                                                                FALSE;

      --
      -- These pallets are created by splitting a SN pallet so set
      -- the flag to show this.  Later, when the putawaylst record is
      -- created putawaylst.from_splitting_sn_pallet_flag is populated
      -- with this value.
      --
      io_r_pallet_table(l_pallet_index).from_splitting_sn_pallet_flag := 'Y';


      --
      -- Calculate the cube and height of the pallet and other stuff.
      --
      determine_pallet_attributes(i_r_item_info,
                                  l_pallet_index,
                                  io_r_pallet_table);
DBMS_OUTPUT.PUT_LINE(l_object_name || ' i_sn_pallet_index: '
   || TO_CHAR(i_sn_pallet_index));
DBMS_OUTPUT.PUT_LINE(l_object_name || ' aaaaaaaa'
   || ' l_split_pallet_index: ' || TO_CHAR(l_split_pallet_index));


      io_r_how_sn_pallet_split_table(l_split_pallet_index).new_pallet_index
                                            := l_pallet_index;
DBMS_OUTPUT.PUT_LINE(l_object_name || ' aaaaaaaa11111');

      IF (NVL(io_r_how_sn_pallet_split_table(l_split_pallet_index).qty, 0) = 0)
      THEN
         io_r_how_sn_pallet_split_table(l_split_pallet_index).qty
                                          := l_pallet_qty;
      END IF;

      --
      -- IF sn_pallet_index is null then this indicates additional split log
      -- records are being created.  The pallet index of the SN pallet being
      -- split needs to be assigned.
      --
      IF (io_r_how_sn_pallet_split_table(l_split_pallet_index).sn_pallet_index
            IS NULL) THEN
         io_r_how_sn_pallet_split_table(l_split_pallet_index).sn_pallet_index
                                             := i_sn_pallet_index;
      END IF;


DBMS_OUTPUT.PUT_LINE(l_object_name || ' bbbbbbbb');
      l_split_pallet_index :=
               io_r_how_sn_pallet_split_table.NEXT(l_split_pallet_index);
      IF (l_split_pallet_index IS NULL) THEN
         l_split_pallet_index := io_r_how_sn_pallet_split_table.LAST + 1;
      END IF;
DBMS_OUTPUT.PUT_LINE(l_object_name || ' cccccccc');

      l_pallet_index := l_pallet_index + 1;
   END LOOP;  -- end pallet loop

   DBMS_OUTPUT.PUT_LINE(l_object_name || ' after main LOOP');

   --
   -- For the remaining log entries assign the new pallet index to them.
   -- Subtract 1 from l_pallet_index because it got incremented at the end
   -- of the loop above.
   --
   WHILE (l_split_pallet_index <= io_r_how_sn_pallet_split_table.LAST) LOOP
      io_r_how_sn_pallet_split_table(l_split_pallet_index).new_pallet_index
                                            := l_pallet_index - 1;
      l_split_pallet_index :=
                  io_r_how_sn_pallet_split_table.NEXT(l_split_pallet_index);
   END LOOP;


EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_r_pallet_table, i_r_item_info, i_qty_over_ti_hi_in_splits...)'
         || '  PO/SN[' || i_erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END build_additional_pallets;


---------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list_from_sn_splt
--
-- Description:
--    This procedure builds the list of pallets to putaway for a SN
--    splitting the SN pallet IF the qty on the pallet is greater
--    than the SWMS Ti HI.
--
--    When splitting a SN pallet the qty will be reduced to the SWMS Ti Hi
--    and the quantity over the SWMS Ti Hi will be put on a new pallet.
--
--    IF the new pallet is made up of cases from dIFferent SN pallets with
--    dIFferent expiration dates then the oldest expiration date is used for
--    the new pallet.  Same thing applies for the manufacturer date.
--
--    The catch weight, which comes from the ERD_LPN.CATCH_WEIGHT column,
--    will be distributed among the original SN pallet(s) and the new
--    pallet(s).
--
--    The item will not be checked IF it is expiration date tracked or
--    manufacturer date tracked or catch weight tracked when creating a
--    new pallet.  We want to build the new pallets with the information
--    from the SN pallets.  At this point IN the processing we do not care
--    about what is tracked for the item.  The exp_date and mfg_date from the
--    ERD_LPN table will be looked at and IF they are populated then the
--    oldest date used.  IF ERD_LPN has a catch weight then that weight gets
--    used.   Further along IN the processing procedure
--    validate_set_sn_data_capture() IN package pl_rcv_open_po_find_slot will
--    validate and set the dates and clear or not clear the catch weight based
--    on what is tracked for the item.
--
--    A new syspar called "Split RDC SN Pallet" controls splitting or not
--    splitting the SN pallet.
--
--    Each line item on the SN is a pallet except for MSKU pallets.
--    MSKU are not handled by this procedure.  MSKU pallets are handled
--    by pl_msku.sql
--
--    The seq_no for the putawaylst table record will be a sequence kept track
--    of IN this procedure.  We will not use the erd.erm_line_id as is done
--    IN procedure build_pallet_list_from_sn.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_erm_id             - PO/SN number.
--    o_r_item_info_table  - Item info for all items on the PO.  The pallet
--                           record stores the index of the item.
--    o_r_pallet_table     - List of pallets to putaway.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - build_pallet_list
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/13/09 prpbcb   Created as part of the changes to split a SN
--                      pallet when the qty is greater than the SWMS
--                      Ti Hi.
--
--                      It was created by copying and modIFying
--                      procedure build_pallet_list_from_sn().
--
--    06/08/10 ctvgg000 Included a union to cursor c_sn_line_item to select
--                      VNs related pallet information from the ERD LPN
--                      table and do not consider the ERD table as it might
--                      have a the dIFferent PO line number than what is IN
--                      IN ERD_LPN. - DN 12587
---------------------------------------------------------------------------
PROCEDURE build_pallet_list_from_sn_splt
      (i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
       i_erm_id             IN  erm.erm_id%TYPE,
       o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
       o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'build_pallet_list_from_sn_splt';

   l_split_catch_weight      NUMBER; -- The erd_lpn.catch_weight / erd_lpn.qty
                                     -- It is used to re-calculate the catch
                                     -- weight of the SN pallet and of the
                                     -- new pallet as the result of splitting
                                     -- the SN pallet.

   l_new_lp_catch_weight     NUMBER; -- The catchweight to use for the new
                                   -- pallet created as the result of splitting
                                   -- the SN pallet.

   l_item_index            PLS_INTEGER;  -- Index of item IN item plsql table.

   l_last_sn_pallet_exp_date       DATE;
   l_last_sn_pallet_mfg_date       DATE;

   l_last_sn_pallet_index  PLS_INTEGER;  -- Index into the pallet plsql table
                                         -- of the last SN pallet processed.
                                         -- Used IN logging how the SN pallet
                                         -- was split.

   l_oldest_exp_date       DATE;  -- The expiration date to use for the new
                                  -- pallet created as the result of splitting
                                  -- the SN pallet.

   l_oldest_mfg_date       DATE;  -- The manufacturer date to use for the new
                                  -- pallet created as the result of splitting
                                  -- the SN pallet.

   l_pallet_index          PLS_INTEGER;  -- Index into the pallet plsql table

   l_partial_pallet_qty    PLS_INTEGER;  -- Partial pallet qty (IN splits).
   l_previous_prod_id      pm.prod_id%TYPE := 'x';  -- Previous item
                                                    -- processed.
   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE := 'x'; --Previous CPV
                                                                 -- processed.

   l_qty_over_ti_hi_in_splits PLS_INTEGER;  -- Quantity (IN splits) on pallets
                                       -- over the items Ti Hi.  Will be used
                                       -- to create additional pallets.  This
                                       -- qty can end up on one or more new
                                       -- pallets.

   l_qty_to_put_on_new_lp_splits  PLS_INTEGER; -- Quantity (IN splits) on the
                                               -- SN pallet to be put on the
                                               -- next new pallet.

   l_seq_no                PLS_INTEGER := 0;  -- Seq #.  It is used to
                                              -- populate putawaylst.seq_no.

   l_full_pallets_in_splits    NUMBER;     -- How many full pallets, IN splits,
                                           -- for an item that have been
                                           -- accumulated on the SN pallet(s)
                                           -- over the Ti Hi.

   l_split_pallet_index        PLS_INTEGER;  -- PL/SQL table index

   --
   -- PL/SQL table for storing information on how the SN pallet was split.
   -- This information will be used to create log messages.
   --
   l_r_how_sn_pallet_split_table   pl_rcv_open_po_types.t_r_how_sn_pallet_split_table;

   --
   -- This cursor selects the SN line item info for non-MKSU pallets.
   -- For each record a pallet is created IN the pallet list.
   --
   -- The ordering is important.
   --

   -- Changed this cursor for DN 12587

   CURSOR c_sn_line_item(cp_erm_id erd.erm_id%TYPE) IS
        SELECT NVL(d.UOM, 0)            UOM,
             d.prod_id                  prod_id,
             d.cust_pref_vendor         cust_pref_vendor,
             PM.brand                   brand,
             PM.mfg_sku                 mfg_sku,
             PM.category                category,
             d.qty                      qty,
             erm.erm_id                 erm_id,
             ERM.erm_type               erm_type,
             d.erm_line_id              erm_line_id,
             ERD_LPN.po_no              po_no,
             ERD_LPN.po_line_id         po_line_id,
             ERD_LPN.pallet_id          pallet_id,
             ERD_LPN.shipped_ti         shipped_ti,
             ERD_LPN.shipped_hi         shipped_hi,
             ERD_LPN.temp               temp,
             ERD_LPN.pallet_type        pallet_type,
             ERD_LPN.catch_weight       catch_weight,
             ERD_LPN.exp_date           exp_date,
             ERD_LPN.mfg_date           mfg_date,
             ERD_LPN.lot_id             lot_id
        FROM ERM,
             PM,
             ERD d,
             ERD_LPN
       WHERE erm.erm_id                                 = d.erm_id
         AND d.erm_id                                   = cp_erm_id
         AND d.erm_line_id                              = ERD_LPN.erm_line_id
         AND ERD_LPN.sn_no                              = cp_erm_id
         AND PM.prod_id                                 = d.prod_id
         AND PM.cust_pref_vendor                        = d.cust_pref_vendor
         AND ERD_LPN.parent_pallet_id  IS NULL
         AND NVL(ERD_LPN.pallet_assigned_flag, 'N')     = 'N'
         AND ERM.status                                 IN ('NEW', 'SCH')
         AND ERM.ERM_TYPE                               = 'SN'
        UNION ALL
       SELECT 0                         UOM,
                -- Always UOM from vendor is 0, Vendor will always send cases.
             ERD_LPN.prod_id            prod_id,
             ERD_LPN.cust_pref_vendor   cust_pref_vendor,
             PM.brand                   brand,
             PM.mfg_sku                 mfg_sku,
             PM.category                category,
             ERD_LPN.qty                qty,
             erm.erm_id                 erm_id,
             ERM.erm_type               erm_type,
             ERD_LPN.erm_line_id        erm_line_id,
             ERD_LPN.po_no              po_no,
             ERD_LPN.po_line_id         po_line_id,
             ERD_LPN.pallet_id          pallet_id,
             ERD_LPN.shipped_ti         shipped_ti,
             ERD_LPN.shipped_hi         shipped_hi,
             ERD_LPN.temp               temp,
             ERD_LPN.pallet_type        pallet_type,
             ERD_LPN.catch_weight       catch_weight,
             ERD_LPN.exp_date           exp_date,
             ERD_LPN.mfg_date           mfg_date,
             ERD_LPN.lot_id             lot_id
        FROM ERM,
             PM,
             ERD_LPN
       WHERE erm.erm_id                 = erd_lpn.sn_no
         AND ERD_LPN.sn_no              = cp_erm_id
         AND ERD_LPN.prod_id            = PM.prod_id
         AND ERD_LPN.cust_pref_vendor   = PM.cust_pref_vendor
         AND ERD_LPN.parent_pallet_id   IS NULL
         AND NVL(ERD_LPN.pallet_assigned_flag, 'N') = 'N'
         AND ERM.status                 IN ('NEW', 'SCH')
         AND ERM.ERM_TYPE               = 'VN'
       ORDER BY 1 DESC, -- uom
                2,      -- prod_id
                3,      -- cpv
                19,     -- exp_date
                7,      -- qty
                4,      -- brand,
                5,      -- mfg_sku,
                6,      -- category,
                13;     -- pallet_id


BEGIN
   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
              ' Starting procedure'
              || '  i_erm_id[' || i_erm_id || ']',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function,
              gl_pkg_name);

   --
   -- Initialization
   --
   l_pallet_index             := 1;
   l_qty_over_ti_hi_in_splits := 0;



   --
   -- Process each line item on the SN.  Each line item will be a pallet
   -- plus there will be additional pallets IF the qty on a pallet is
   -- greater than the SWMS Ti Hi.
   --
   DBMS_OUTPUT.PUT_LINE(l_object_name || ' BEFORE LOOP    BEFORE LOOP    BEFORE LOOP');
   FOR r_sn_line_item IN c_sn_line_item(i_erm_id) LOOP
      DBMS_OUTPUT.PUT_LINE('=================================================================');
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
           r_sn_line_item.prod_id || ' ' || r_sn_line_item.cust_pref_vendor ||
           '  uom:' ||TO_CHAR(r_sn_line_item.uom) ||
           '  erd qty: ' || TO_CHAR(r_sn_line_item.qty) ||
           '  erd_lpn catch weight: ' || TO_CHAR(r_sn_line_item.catch_weight));


      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
              ' IN sn pallet loop l_qty_over_ti_hi_in_splits['
              || TO_CHAR(l_qty_over_ti_hi_in_splits) || ']',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function,
              gl_pkg_name);

      --
      -- IF the first item or a dIFferent item then get the item information
      -- and store it IN the plsql table of item records.
      -- The index of the item will be put IN l_item_index which will be
      -- saved IN the pallet table.
      --
      IF (r_sn_line_item.prod_id != NVL(l_previous_prod_id, 'x') OR
  r_sn_line_item.cust_pref_vendor != NVL(l_previous_cust_pref_vendor, 'x')) THEN

         DBMS_OUTPUT.PUT_LINE(' 00000000000000  new item  000000000000000');

         --
         -- Processing first item or a dIFferent item.
         --
         -- Build new pallets for the qty over the SWMS Ti Hi for the item
         -- just processed.
         --
         IF (l_qty_over_ti_hi_in_splits > 0) THEN

            DBMS_OUTPUT.PUT_LINE('l_qty_over_ti_hi_in_splits: ' || TO_CHAR(l_qty_over_ti_hi_in_splits)
               || '   l_new_lp_catch_weight: ' || TO_CHAR(l_new_lp_catch_weight, '99999.999'));

            l_last_sn_pallet_index := l_pallet_index;

            build_additional_pallets
                     (o_r_pallet_table,
                      l_seq_no,
                      o_r_item_info_table(l_item_index),
                      l_qty_over_ti_hi_in_splits,
                      l_oldest_exp_date,
                      l_oldest_mfg_date,
                      l_new_lp_catch_weight,
                      l_last_sn_pallet_exp_date,
                      l_last_sn_pallet_mfg_date,
                      l_r_how_sn_pallet_split_table,
                      l_last_sn_pallet_index,
                      i_erm_id);


            --
            -- Adjust the pallet table index since additional pallets
            -- were added.
            --
            l_pallet_index := NVL(o_r_pallet_table.LAST, 0) + 1;
         END IF;

-- Do at end.
--       log_how_sn_pallet_split(l_r_how_sn_pallet_split_table,
--                               o_r_item_info_table,
--                               o_r_pallet_table,
--                               i_erm_id);

         --
         -- Initialization appropriate variables.
         --
         l_qty_over_ti_hi_in_splits := 0;
         l_full_pallets_in_splits   := 0;
         l_oldest_exp_date          := NULL;
         l_oldest_mfg_date          := NULL;
         l_new_lp_catch_weight      := 0;
         l_last_sn_pallet_exp_date  := NULL;
         l_last_sn_pallet_mfg_date  := NULL;

         get_item_info(i_r_syspars,
                       r_sn_line_item.prod_id,
                       r_sn_line_item.cust_pref_vendor,
                       i_erm_id,
                       l_item_index,
                       o_r_item_info_table);

         l_previous_prod_id := r_sn_line_item.prod_id;
         l_previous_cust_pref_vendor := r_sn_line_item.cust_pref_vendor;

         DBMS_OUTPUT.PUT_LINE('o_r_item_info_table.COUNT: '
                              || o_r_item_info_table.COUNT);
      END IF;

      show_item_info(l_item_index, o_r_item_info_table);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
                ' l_item_index: ' || TO_CHAR(l_item_index));
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
                  ' l_pallet_index: ' || TO_CHAR(l_pallet_index));

      l_seq_no := l_seq_no + 1;   -- Sequence for the putawaylst record

      o_r_pallet_table(l_pallet_index).pallet_id   := r_sn_line_item.pallet_id;
      o_r_pallet_table(l_pallet_index).prod_id     := r_sn_line_item.prod_id;
      o_r_pallet_table(l_pallet_index).cust_pref_vendor :=
                                             r_sn_line_item.cust_pref_vendor;
      o_r_pallet_table(l_pallet_index).qty          := r_sn_line_item.qty;
      o_r_pallet_table(l_pallet_index).qty_expected := r_sn_line_item.qty;
      o_r_pallet_table(l_pallet_index).qty_received := r_sn_line_item.qty;
      o_r_pallet_table(l_pallet_index).uom          := r_sn_line_item.uom;
      o_r_pallet_table(l_pallet_index).item_index   := l_item_index;
      o_r_pallet_table(l_pallet_index).erm_id       := r_sn_line_item.erm_id;
      o_r_pallet_table(l_pallet_index).erm_type     := r_sn_line_item.erm_type;
      o_r_pallet_table(l_pallet_index).erm_line_id  := r_sn_line_item.erm_line_id;
      o_r_pallet_table(l_pallet_index).seq_no       := l_seq_no;
      o_r_pallet_table(l_pallet_index).sn_no        := r_sn_line_item.erm_id;
      o_r_pallet_table(l_pallet_index).po_no        := r_sn_line_item.po_no;
      o_r_pallet_table(l_pallet_index).po_line_id   := r_sn_line_item.po_line_id;
      o_r_pallet_table(l_pallet_index).shipped_ti   :=
                                                r_sn_line_item.shipped_ti;
      o_r_pallet_table(l_pallet_index).shipped_hi  :=
                                                r_sn_line_item.shipped_hi;
      o_r_pallet_table(l_pallet_index).temp        := r_sn_line_item.temp;
      o_r_pallet_table(l_pallet_index).sn_pallet_type :=
                                               r_sn_line_item.pallet_type;
      o_r_pallet_table(l_pallet_index).catch_weight :=
                                               r_sn_line_item.catch_weight;
      o_r_pallet_table(l_pallet_index).exp_date := r_sn_line_item.exp_date;
      o_r_pallet_table(l_pallet_index).mfg_date := r_sn_line_item.mfg_date;
      o_r_pallet_table(l_pallet_index).lot_id   := r_sn_line_item.lot_id;

      --
      -- Determine IF the pallet should be directed only to empty slots.
      -- This applies when going to reserve or floating.  Does not apply
      -- for bulk rule zones.
      --
      -- Receiving splits will always go to an empty reserve/floating slot
      -- IF the splits cannot go to the home slot.
      -- Note: A SN from the RDC should not have splits.
      --
      IF (o_r_pallet_table(l_pallet_index).uom = 1) THEN
         o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln :=
                                                                   TRUE;
         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
              ' Item[' || o_r_item_info_table(l_item_index).prod_id || ']'
              ||' CPV[' || o_r_item_info_table(l_item_index).cust_pref_vendor
              || ']'
              || ' PO/SN[' || i_erm_id || ']'
              || '  Receiving splits.  The pallet will be directed only to'
              || ' open slots IF it cannot go to the home slot or it is'
              || ' a floating item.  The pallet will always be'
              || ' considered a partial pallet.',
              NULL, NULL,
              pl_rcv_open_po_types.ct_application_function,
              gl_pkg_name);
      ELSE
         o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln :=
                                                                   FALSE;
      END IF;

      --
      -- Determine the catch weight of a split using the ERD_LPN
      -- catch weight.  It will be used to set the PUTAWAYLST
      -- weight when a SN pallet is split.
      -- Handle the outside chance the qty is 0 or null.
      --
      IF (r_sn_line_item.qty > 0) THEN
         l_split_catch_weight :=
                       r_sn_line_item.catch_weight / r_sn_line_item.qty;
      ELSE
         l_split_catch_weight := r_sn_line_item.catch_weight;
      END IF;

      DBMS_OUTPUT.PUT_LINE('************ l_split_catch_weight: '
             || TO_CHAR(l_split_catch_weight, '99999.999'));

      --
      -- When receiving cases and cases are not IN the minloader
      -- reduce the qty to a SWMS Ti Hi IF it is greater
      -- than SWMS Ti Hi and accumulate the qty over the Ti Hi.
      --
      IF (o_r_pallet_table(l_pallet_index).uom <> 1) THEN
         --
         -- Receiving cases.
         -- IF the qty on the pallet is greater than the SWMS Ti Hi and
         -- cases are not stored IN the miniloader then split the SN pallet.
         --

         l_last_sn_pallet_exp_date := r_sn_line_item.exp_date;
         l_last_sn_pallet_mfg_date := r_sn_line_item.mfg_date;

         IF (r_sn_line_item.qty
                 > o_r_item_info_table(l_item_index).full_pallet_qty_in_splits
             AND o_r_item_info_table(l_item_index).miniload_storage_ind <> 'B')
         THEN
            --
            -- The qty on the pallet is greater than the SWMS Ti Hi and
            -- cases are not stored IN the miniloader.  Split the SN pallet.
            --
            -- Determine the qty on the SN pallet to put on the next new pallet.
            -- It is possible some of the qty over the SWMS Ti Hi will go on
            -- the next new pallet and the rest on the new pallet after that.
            --
            l_qty_to_put_on_new_lp_splits :=
                 LEAST(o_r_pallet_table(l_pallet_index).qty_received -
                        o_r_item_info_table(l_item_index).full_pallet_qty_in_splits,
                 (o_r_item_info_table(l_item_index).full_pallet_qty_in_splits - l_qty_over_ti_hi_in_splits));

DBMS_OUTPUT.PUT_LINE('444 l_qty_to_put_on_new_lp_splits: ' || TO_CHAR(l_qty_to_put_on_new_lp_splits));

            --
            -- Accumulate the qty over the SWMS Ti Hi.
            --
            l_qty_over_ti_hi_in_splits := l_qty_over_ti_hi_in_splits +
                    (o_r_pallet_table(l_pallet_index).qty_received -
                 o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);


DBMS_OUTPUT.PUT_LINE('555 l_qty_over_ti_hi_in_splits: ' || TO_CHAR(l_qty_over_ti_hi_in_splits));

            --
            -- Reduce the qty on the SN pallet qty to the SWMS Ti Hi.
            --
            o_r_pallet_table(l_pallet_index).qty :=
                 o_r_item_info_table(l_item_index).full_pallet_qty_in_splits;
            o_r_pallet_table(l_pallet_index).qty_expected := o_r_pallet_table(l_pallet_index).qty;
            o_r_pallet_table(l_pallet_index).qty_received := o_r_pallet_table(l_pallet_index).qty;

            --
            -- Calculate the SN pallet catch weight based on the new qty on
            -- the pallet.
            --
            o_r_pallet_table(l_pallet_index).catch_weight :=
                 o_r_pallet_table(l_pallet_index).qty_received * l_split_catch_weight;

            DBMS_OUTPUT.PUT_LINE('SN pallet adjusted catch weight: '
             || TO_CHAR(o_r_pallet_table(l_pallet_index).catch_weight));

            --
            -- Keep track of the catch weight for the new pallet that will
            -- get created.
            --
            DBMS_OUTPUT.PUT_LINE('666 l_new_lp_catch_weight: ' || TO_CHAR(l_new_lp_catch_weight));

            --
            -- IF (l_qty_over_ti_hi_in_splits <=
            --      o_r_item_info_table(l_item_index).full_pallet_qty_in_splits)
            -- THEN
            --    l_new_lp_catch_weight := l_new_lp_catch_weight +
            --  (l_split_catch_weight *
            --   (r_sn_line_item.qty -
            --      o_r_item_info_table(l_item_index).full_pallet_qty_in_splits));
            -- ELSE
            --    l_new_lp_catch_weight := l_new_lp_catch_weight +
            --  (l_split_catch_weight *
            --      (l_qty_over_ti_hi_in_splits -
            --          o_r_pallet_table(l_item_index).qty_received));
            -- END IF;
            --

            l_new_lp_catch_weight := l_new_lp_catch_weight +
                (l_split_catch_weight * l_qty_to_put_on_new_lp_splits);

            DBMS_OUTPUT.PUT_LINE('777 l_new_lp_catch_weight: ' || TO_CHAR(l_new_lp_catch_weight));
         END IF;
      END IF;

      --
      -- Determine IF it is a full or partial pallet.
      --
      IF (o_r_pallet_table(l_pallet_index).qty_received >=
                                  (o_r_item_info_table(l_item_index).spc *
                                   o_r_item_info_table(l_item_index).ti *
                                   o_r_item_info_table(l_item_index).hi)) THEN
         o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'N';
      ELSE
         o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'Y';
      END IF;

      --
      -- Calculate the cube and height of the pallet and other stuff.
      --
      determine_pallet_attributes(o_r_item_info_table(l_item_index),
                                  l_pallet_index,
                                  o_r_pallet_table);

      --
      -- Keep track of the oldest exp date and mfg date to use IN creating
      -- the new pallets.
      --
      IF (l_oldest_exp_date IS NULL
          OR l_oldest_exp_date > o_r_pallet_table(l_pallet_index).exp_date)
      THEN
          l_oldest_exp_date := o_r_pallet_table(l_pallet_index).exp_date;
      END IF;

      IF (l_oldest_mfg_date IS NULL
          OR l_oldest_mfg_date > o_r_pallet_table(l_pallet_index).mfg_date)
      THEN
          l_oldest_mfg_date := o_r_pallet_table(l_pallet_index).mfg_date;
      END IF;


      l_split_pallet_index := NVL(l_r_how_sn_pallet_split_table.LAST, 0) + 1;


      IF (l_qty_to_put_on_new_lp_splits > 0) THEN
         l_r_how_sn_pallet_split_table(l_split_pallet_index).sn_pallet_index :=
                                                l_pallet_index;
         l_r_how_sn_pallet_split_table(l_split_pallet_index).qty :=
                                                l_qty_to_put_on_new_lp_splits;
      END IF;



      -- AAAAA
      --
      -- IF enough "over Ti Hi" qty is accumulated then build new full
      -- pallet(s).
      --
      IF (l_qty_over_ti_hi_in_splits >=
               o_r_item_info_table(l_item_index).full_pallet_qty_in_splits)
      THEN
         --
         -- Enough "over Ti Hi" qty is accumulated to build a new full
         -- pallet.
         --
         -- Determine how many full pallets have been accumulated.
         --
         l_full_pallets_in_splits :=
                  o_r_item_info_table(l_item_index).full_pallet_qty_in_splits
              * (TRUNC(l_qty_over_ti_hi_in_splits /
                 o_r_item_info_table(l_item_index).full_pallet_qty_in_splits));

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  'AAA IN sn pallet loop l_qty_over_ti_hi_in_splits['
                  || TO_CHAR(l_qty_over_ti_hi_in_splits) || ']'
                  || '  l_full_pallets_in_splits['
                  || TO_CHAR(l_full_pallets_in_splits) || ']',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

         l_qty_over_ti_hi_in_splits :=
                        l_qty_over_ti_hi_in_splits - l_full_pallets_in_splits;

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                  'BBB IN sn pallet loop l_qty_over_ti_hi_in_splits['
                  || TO_CHAR(l_qty_over_ti_hi_in_splits) || ']'
                  || '  l_full_pallets_in_splits['
                  || TO_CHAR(l_full_pallets_in_splits) || ']',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

         l_last_sn_pallet_index := l_pallet_index;

         build_additional_pallets
                     (o_r_pallet_table,
                      l_seq_no,
                      o_r_item_info_table(l_item_index),
                      l_full_pallets_in_splits,
                      l_oldest_exp_date,
                      l_oldest_mfg_date,
                      l_new_lp_catch_weight,
                      l_last_sn_pallet_exp_date,
                      l_last_sn_pallet_mfg_date,
                      l_r_how_sn_pallet_split_table,
                      l_last_sn_pallet_index,
                      i_erm_id);

         l_new_lp_catch_weight := l_split_catch_weight *
                    l_qty_over_ti_hi_in_splits;

         l_oldest_exp_date  := l_last_sn_pallet_exp_date;
         l_oldest_mfg_date  := l_last_sn_pallet_mfg_date;

         l_pallet_index := NVL(o_r_pallet_table.LAST, 0);
      END IF;
      -- AAAAA

      l_pallet_index := l_pallet_index + 1;

   END LOOP;

   DBMS_OUTPUT.PUT_LINE(l_object_name || ' AFTER LOOP    AFTER LOOP    AFTER LOOP');

   IF (l_qty_over_ti_hi_in_splits > 0) THEN

      l_new_lp_catch_weight := l_split_catch_weight *
                                          l_qty_over_ti_hi_in_splits;

      IF (l_oldest_exp_date  IS NULL) THEN
         l_oldest_exp_date := l_last_sn_pallet_exp_date;
      END IF;

      IF (l_oldest_mfg_date  IS NULL) THEN
         l_oldest_mfg_date := l_last_sn_pallet_mfg_date;
      END IF;

      build_additional_pallets
                     (o_r_pallet_table,
                      l_seq_no,
                      o_r_item_info_table(l_item_index),
                      l_qty_over_ti_hi_in_splits,
                      l_oldest_exp_date,
                      l_oldest_mfg_date,
                      l_new_lp_catch_weight,
                      l_last_sn_pallet_exp_date,
                      l_last_sn_pallet_mfg_date,
                      l_r_how_sn_pallet_split_table,
                      l_last_sn_pallet_index,
                      i_erm_id);
   END IF;

-- DN 12587 - Commented logging as per brian

--   log_how_sn_pallet_split(l_r_how_sn_pallet_split_table,
--                           o_r_item_info_table,
--                           o_r_pallet_table,
--                           i_erm_id);

EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_r_syspars,i_erm_id,o_r_item_info_table,o_r_pallet_table)'
         || '  PO/SN[' || i_erm_id || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM,
                           pl_rcv_open_po_types.ct_application_function,
                           gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END build_pallet_list_from_sn_splt;


---------------------------------------------------------------------------
-- End Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    show_pallets
--
-- Description:
--    Output the pallets IN the pallet PL/SQL table.  Used for debugging.
--
-- Parameters:
--    i_r_pallet_table - Pallet plsql table of records.
---------------------------------------------------------------------------
PROCEDURE show_pallets
              (i_r_pallet_table  IN pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_counter PLS_INTEGER;
   l_index   PLS_INTEGER;

BEGIN
   -- return;

   l_index := i_r_pallet_table.FIRST;

   DBMS_OUTPUT.PUT_LINE('======== Start show_pallets =====================================');

   WHILE (l_index <= i_r_pallet_table.LAST) LOOP
      DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------');
      DBMS_OUTPUT.PUT_LINE('l_index: ' || TO_CHAR(l_index));
      DBMS_OUTPUT.PUT_LINE('pallet_id: ' ||
                           i_r_pallet_table(l_index).pallet_id);
      DBMS_OUTPUT.PUT_LINE('prod_id: ' || i_r_pallet_table(l_index).prod_id);
      DBMS_OUTPUT.PUT_LINE('cust_pref_vendor: ' ||
                           i_r_pallet_table(l_index).cust_pref_vendor);
      DBMS_OUTPUT.PUT_LINE('qty: ' ||
                           TO_CHAR(i_r_pallet_table(l_index).qty));
      DBMS_OUTPUT.PUT_LINE('qty_received: ' ||
                           TO_CHAR(i_r_pallet_table(l_index).qty_received));
      DBMS_OUTPUT.PUT_LINE('uom: ' ||
                           TO_CHAR(i_r_pallet_table(l_index).uom));
      -- Story 3840 (kchi7065) Added door number column
      DBMS_OUTPUT.PUT_LINE('door_no: ' || i_r_pallet_table(l_index).door_no);
      DBMS_OUTPUT.PUT_LINE('dest_loc: ' ||
                           i_r_pallet_table(l_index).dest_loc);
      DBMS_OUTPUT.PUT_LINE('item_index: ' ||
                           TO_CHAR(i_r_pallet_table(l_index).item_index));
      DBMS_OUTPUT.PUT_LINE('cube_without_skid: ' ||
                         TO_CHAR(i_r_pallet_table(l_index).cube_without_skid));
      DBMS_OUTPUT.PUT_LINE('cube_with_skid: ' ||
                           TO_CHAR(i_r_pallet_table(l_index).cube_with_skid));
      DBMS_OUTPUT.PUT_LINE('pallet_height_without_skid: ' ||
              TO_CHAR(i_r_pallet_table(l_index).pallet_height_without_skid));
      DBMS_OUTPUT.PUT_LINE('pallet_height_with_skid: ' ||
                  TO_CHAR(i_r_pallet_table(l_index).pallet_height_with_skid));

      DBMS_OUTPUT.PUT_LINE('partial_pallet_flag: ' ||
                  i_r_pallet_table(l_index).partial_pallet_flag);

      DBMS_OUTPUT.PUT_LINE('direct_only_to_open_slot_bln: ' ||
       f_boolean_text(i_r_pallet_table(l_index).direct_only_to_open_slot_bln));

       DBMS_OUTPUT.PUT_LINE('matrix_reserve: ' ||
       f_boolean_text(i_r_pallet_table(l_index).matrix_reserve));

      DBMS_OUTPUT.PUT_LINE('direct_to_ml_induction_loc_bln: ' ||
       f_boolean_text(i_r_pallet_table(l_index).direct_to_ml_induction_loc_bln));

      l_index := i_r_pallet_table.NEXT(l_index);
   END LOOP;

   DBMS_OUTPUT.PUT_LINE('======== End show_pallets =====================================');
End Show_Pallets;

------------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list
--
-- Description:
--    This procedure builds the list of pallets to putaway.
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_erm_id             - PO/SN being processed.
--    o_r_item_info_table  - Item info for all items on the PO/SN.
--                           The pallet record stores the index of the item.
--    o_r_pallet_table     - PL/SQL table of pallet records.
--
-- Exceptions Raised:
--    pl_exc.ct_data_error     - Did not find the PO/SN.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - pl_rcv_open_po_find_slot.find_slot
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------------
--    08/22/05 prpbcb   Created
--    10/19/09 ctvgg000 Changed for ASN to all OPCOs project
--            A VSN (ASN) will be shipped with pallets already built
--            by the vendor, similar to an SN from RDC. Hence treat
--            VSN like an SN only for building pallets.
--
--    06/08/10 ctvgg000 Always split pallets over ti hi for a VN regardless
--            of the syspar SPLIT_RDC_SN_PALLET.
--    07/10/18 mpha8134 Meat Company Project Jira 438: 
--                      Add call to build_pallet_list_from_int_po if it's 
--                      an internal production PO
--    12/11/18 mpha8134 Add new erm_type FG  
------------------------------------------------------------------------------
PROCEDURE build_pallet_list (
    i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
    i_erm_id             IN  erm.erm_id%TYPE,
    o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
    o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
    l_message       VARCHAR2(256);    -- Message buffer
    l_object_name   VARCHAR2(61) := gl_pkg_name || '.build_pallet_list';

    l_erm_type      erm.erm_type%TYPE;
    l_vendor_id     erm.source_id%TYPE;
BEGIN
    -- Find out the erm TYPE.
    BEGIN
        SELECT erm_type
          INTO l_erm_type
          FROM erm
         WHERE erm_id = i_erm_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Did not find the erm id.  This is a fatal error.
            l_message := l_object_name
                || '  TABLE=erm'
                || '  KEY=[' || i_erm_id || '](PO/SN)'
                || '  ACTIONK=SELECT'
                || '  PO/SN[' || i_erm_id || ']'
                || '  Did not find the PO/SN.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                            SQLCODE, SQLERRM,
                            pl_rcv_open_po_types.ct_application_function,
                            gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                                    l_object_name || ': ' || SQLERRM);
    END;

    IF (l_erm_type  IN ('PO', 'FG', 'TR')) THEN

        IF pl_common.f_is_internal_production_po(i_erm_id) THEN

            build_pallet_list_from_prod_po (
                i_r_syspars,
                i_erm_id,
                o_r_item_info_table,
                o_r_pallet_table);

        ELSE
            DBMS_OUTPUT.PUT_LINE(l_object_name
                            || ' Processing PO[' || i_erm_id || ']');
                            dbms_output.put_line('test_build_palletlist_4');
            build_pallet_list_from_po(i_r_syspars,
                                    i_erm_id,
                                    o_r_item_info_table,
                                    o_r_pallet_table);
            dbms_output.put_line('AAAAA o_r_item_info_table.count:[' ||
            o_r_item_info_table.COUNT || ']');
            dbms_output.put_line('AAAAA o_r_pallet_table.count:[' ||
            o_r_pallet_table.COUNT || ']');
        END IF;

    -- 10/19/09 -ctvgg000 - Changed for ASN to all OPCOs project
    -- A VSN (ASN) will be shipped with pallets already built
    -- by the vendor, similar to an SN from RDC. Hence treat
    -- VSN like an SN only for building pallets.

    ELSIF (l_erm_type IN ('SN','VN')) THEN
        DBMS_OUTPUT.PUT_LINE(l_object_name
                            || ' Processing SN[' || i_erm_id || ']');


        -- 06/07/10 -ctvgg000 - Users wanted the system to split vendor
        -- pallets which are over SWMS TI HI and also to print the Demand
        -- Labels for the excess pallets for a VN regardless of the syspar
        -- SPLIT_RDC_SN_PALLET.

        IF (i_r_syspars.split_rdc_sn_pallet = 'Y' OR l_erm_type = 'VN') THEN

            -- 06/27/11 - vgur0337 - Pallet redisribution for VSN's

            -- Before building new pallets try to redistribute the cases
            -- from over the TIHI pallets among other partial pallets for the
            -- same item. Do this only for VSN's.

            IF (l_erm_type = 'VN') THEN

                pallet_split_optimize(i_erm_id);

            END IF;

            build_pallet_list_from_sn_splt(i_r_syspars,
                                            i_erm_id,
                                            o_r_item_info_table,
                                            o_r_pallet_table);
        ELSE
            build_pallet_list_from_sn(i_r_syspars,
                                    i_erm_id,
                                    o_r_item_info_table,
                                    o_r_pallet_table);
      END IF;
    ELSE
        --
        -- Unhandled erm TYPE.  Do nothing other than write an aplog message.
        -- The calling object needs to check IF anything is IN the list.
        --
        l_message := 'PO/SN[' || i_erm_id || ']'
            || ' has an unhandled erm TYPE of [' || l_erm_type || '].'
            || '  No pallet list will be built.';
        pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        l_message := l_object_name
            || '(i_r_syspars,i_erm_id,o_r_item_info_table,o_r_pallet_table)'
            || '  i_erm_id[' || i_erm_id || ']';
        pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
        RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                l_object_name || ': ' || SQLERRM);
END build_pallet_list;

--------------------------------------------------------------------------------
-- Procedure:
--    pallet_split_optimize
--
-- Description:
--    This procedure optimizes the pallet splitting for VSN's.  i.e. distributes
--    the cases from over the TIHI pallets to other partial pallets of the
--    same item.
--
--    Existing Process:
--
--      Consider an item having TIXHI 5x6 and qty ordered 90 cases.
--      Vendor Sends it on 3 pallets - Pallet A, B and C
--
--      Pallet A has 15 cases  (Partial Pallet - Under SWMS TIXHI)
--      Pallet B has 30 cases  (Full Pallet)
--      Pallet C has 45 cases  (Pallet over the TIXHI).
--
--      Currently only the pallet C will be split and a new pallet with
--      the excess qty over SWMS TIXHI will be created with 15 cases on it.
--
--      So the above pallets will be split as follows
--
--      Pallet A has 15 cases  -- No cases added/removed.
--      Pallet B has 30 cases  -- No cases added/removed.
--      Pallet C has 30 cases  -- 15 cases was removed to fit SWMS TIXHI.
--      Pallet D has 15 cases  -- New pallet with 15 cases from pallet C.
--
--   New Process:
--
--     The above scenario was creating a number of partial pallets which
--     the warehouse personel had to combine to create full pallets.
--
--     This procedure distributes the excess cases from "over the TIXHI"
--     pallets to the partial pallets.
--
--     IN the above scenario the pallet distribution will be as follows
--
--     Pallet A will have 30 Cases  -- 15 cases from pallet C)
--     Pallet B will have 30 Cases  -- No changes
--     Pallet C will have 30 Cases  -- 15 cases removed to fit SWMS TIxHI
--
--     IN situations where cases are still left over the SWMS TIXHI on
--     pallets will be split and moved to new pallets following the existing
--     logic IN function build_pallet_list_from_sn_splt
--
-- Called By:
--    - build_pallet_list_from_sn_split
--
-- ModIFication History:
-------------------------------------------------------------------------------

PROCEDURE pallet_split_optimize (i_erm_id IN erm.erm_id%TYPE)
IS

   PRAGMA AUTONOMOUS_TRANSACTION;

   -- This cursor selects pallet information for all items IN VSN.
   -- For every item a check is done to see IF there are partial
   -- pallets and pallets over ti x hi.


   CURSOR c_vn_item(i_erm_id erm.erm_id%TYPE)  IS
      SELECT ERD_LPN.prod_id            prod_id,
             ERD_LPN.cust_pref_vendor   cust_pref_vendor,
             ERD_LPN.pallet_id          pallet_id,
             ERD_LPN.qty                qty,
             PM.TI                      ti,
             PM.HI                      hi,
             PM.SPC                     spc,
             erm.erm_id                 erm_id,
             ERM.erm_type               erm_type,
             ERD_LPN.catch_weight       catch_weight
        FROM ERM,
             PM,
             ERD_LPN
       WHERE erm.erm_id                 = erd_lpn.sn_no
             AND ERD_LPN.sn_no              = i_erm_id
             AND ERD_LPN.prod_id            = PM.prod_id
             AND ERD_LPN.cust_pref_vendor   = PM.cust_pref_vendor
             AND ERM.status                 IN ('NEW', 'SCH')
       ORDER BY ERD_LPN.prod_id,
                ERD_LPN.cust_pref_vendor;

   -- This is a second cursor to loop through only the pallets that
   -- are not full (either partial or over TIHI)

    CURSOR c_pallet_redistribute(i_erm_id erm.erm_id%TYPE,
                                 i_prod_id pm.prod_id%TYPE,
                                 i_cust_pref_vendor pm.cust_pref_vendor%TYPE
                                )
       IS
        SELECT ERD_LPN.prod_id            prod_id,
          ERD_LPN.cust_pref_vendor        cust_pref_vendor,
          ERD_LPN.qty                     qty,
          ERD_LPN.mfg_date                mfg_date,
          ERD_LPN.exp_date                exp_date,
          ERD_LPN.pallet_id               pallet_id,
          ERD_LPN.catch_weight            catch_weight,
          ERD_LPN.lot_id                  lot_id
        FROM ERD_LPN,
          ERM,
          ERD,
          PM
       WHERE ERD_LPN.sn_no = erm.erm_id
             AND erm.erm_id = ERD.erm_id
             AND ERD.prod_id = ERD_LPN.prod_id
             AND PM.prod_id = ERD_LPN.prod_id
             AND ERD_LPN.sn_no = i_erm_id
             AND ERD_LPN.prod_id = i_prod_id
             AND ERD_LPN.cust_pref_vendor = i_cust_pref_vendor
             AND ERD_LPN.qty <> (PM.ti * PM.hi * PM.spc)
         ORDER BY ERD_LPN.qty desc;


   l_object_name                             VARCHAR2(61) := gl_pkg_name || '.pallet_split_optimize';
   l_no_of_pallets_over_ti_hi                NUMBER := 0;
   l_no_of_pallets_under_ti_hi               NUMBER := 0;
   l_previous_prod_id                        PM.PROD_ID%TYPE := 'x';
   l_previous_cust_pref_vendor               PM.CUST_PREF_VENDOR%TYPE := 'x';
   l_qty_redistributed_for_item              BOOLEAN := FALSE;

   l_total_qty_for_item                      ERD_LPN.QTY%TYPE:=0;        -- The sum of qty on all pallets for the item
   l_pallet_cnt_before_redist                NUMBER := 0;
   l_pallet_cnt_after_redist                 NUMBER := 0;

   l_ref_prod_id                             PM.PROD_ID%TYPE := 'x';
   l_ref_cust_pref_vendor                    PM.CUST_PREF_VENDOR%TYPE := 'x';
   l_ref_total_qty_for_item                  NUMBER := 0;
   l_oldest_exp_date                         DATE := NULL;
   l_oldest_mfg_date                         DATE := NULL;
   l_split_catch_weight                      NUMBER := 0;

   -- Temporary Variables
   l_pallet_counter                          NUMBER := 0;
   l_qty_on_full_pallet                      REAL;
   l_qty_to_put_on_pallet                    NUMBER := 0;
   l_exp_date                                DATE := NULL;
   l_mfg_date                                DATE := NULL;
   l_catch_weight                            NUMBER := 0;
   l_message                                 VARCHAR2(256);


BEGIN

-- DBMS_OUTPUT.PUT_LINE (l_object_name || 'starting pallet optimization ' || i_erm_id);

-- First check IF any two partials can be combined to make a single full pallet.
-- Loop through each pallet

FOR r_vn_item IN c_vn_item(i_erm_id) LOOP

  l_qty_on_full_pallet := r_vn_item.ti * r_vn_item.hi * r_vn_item.spc;


  --  Reset all variables for the next item.

  IF (r_vn_item.prod_id != NVL(l_previous_prod_id, 'x') OR
      r_vn_item.cust_pref_vendor != NVL(l_previous_cust_pref_vendor, 'x')) THEN
        l_no_of_pallets_over_ti_hi := 0;
        l_no_of_pallets_under_ti_hi := 0;
        l_qty_redistributed_for_item := FALSE;   -- Reset processed flag to false.
        l_pallet_counter := 0;
        l_ref_total_qty_for_item := 0;
        l_qty_to_put_on_pallet := 0;
  END IF;


  IF (r_vn_item.qty > l_qty_on_full_pallet)  THEN
   l_no_of_pallets_over_ti_hi := l_no_of_pallets_over_ti_hi + 1;
  ELSIF (r_vn_item.qty < l_qty_on_full_pallet) THEN
   l_no_of_pallets_under_ti_hi := l_no_of_pallets_under_ti_hi + 1;
  END IF;

  -- Go IN to the below condition to redistribute pallets,
  -- only IF one of the below is true.
  --
  -- 1. There is atleast one pallet over the SWMS TI/HI and IF there is atlease
  --    one partial pallet available for the same item so that the pallet splitting
  --    can happen.
  --
  --              -- OR --
  --
  -- 2. There is atleast two partial pallets for the same item.
  --


  IF ((
      (l_no_of_pallets_over_ti_hi >= 1 AND l_no_of_pallets_under_ti_hi >= 1) OR
      (l_no_of_pallets_under_ti_hi > 1)
      ) AND l_qty_redistributed_for_item = FALSE ) THEN


    --  Get the total qty, oldest mfg date, oldest exp date for item to be split
    --  and distributed.

    SELECT
      ERD_LPN.prod_id                 prod_id,
      ERD_LPN.cust_pref_vendor        cust_pref_vendor,
      SUM(ERD_LPN.qty)                qty,
      MIN(ERD_LPN.mfg_date )          mfg_date,
      MIN(ERD_LPN.exp_date )          exp_date,
      COUNT(ERD_LPN.PALLET_ID)        pallet_count,
      SUM(ERD_LPN.catch_weight)/SUM(ERD_LPN.qty)    avg_catch_weight
    INTO
      l_ref_prod_id,
      l_ref_cust_pref_vendor,
      l_ref_total_qty_for_item,
      l_oldest_mfg_date,
      l_oldest_exp_date,
      l_pallet_cnt_before_redist,
      l_split_catch_weight
    FROM ERD_LPN,
      ERM,
      ERD,
      PM
    WHERE ERD_LPN.sn_no = erm.erm_id
         AND erm.erm_id = ERD.erm_id
         AND ERD_LPN.sn_no = i_erm_id
         AND ERD.prod_id = ERD_LPN.prod_id
         AND PM.prod_id = ERD.prod_id
         AND ERD_LPN.prod_id = r_vn_item.prod_id
         AND ERD_LPN.cust_pref_vendor = r_vn_item.cust_pref_vendor
         AND ERD_LPN.qty <> (PM.ti * PM.hi * PM.spc)
    GROUP BY
         ERD_LPN.PROD_ID,
         ERD_LPN.CUST_PREF_VENDOR;


       --  Loop through each pallet which is not full.
       --  The below logic accumulates the entire qty and tries to allocate
       --  full pallet quantities to each pallet IN the list. once the last
       --  pallet is reached, it allocates all qty that is left over to the
       --  last pallet. IF the qty on last pallet is over the TIHI then new
       --  pallets are created by procedure build_pallet_list_from_sn_splt.

       --  IF the left over qty becomes 0 even before we can fill all the
       --  pallets then update 0 qty to all the following pallets.


       FOR r_pallet_redistribute IN c_pallet_redistribute
            (i_erm_id, r_vn_item.prod_id, r_vn_item.cust_pref_vendor)  LOOP

          l_pallet_counter := l_pallet_counter + 1;


          -- Start by allocating full pallet quantities to each pallet
          -- on the list, also once allocated reduce the qty allocated
          -- from the total qty.

          -- Check IF the last pallet has reached or the total qty falls
          -- below full pallet. IF yes, then update the total qty to the
          -- to the last pallet or IF we the qty has fallen below a full
          -- pallet qty, then that means we have more partial pallets.
          -- update the total qty to zero and this will set the qty as zero
          -- to all other pallets that follow.


          IF ((l_ref_total_qty_for_item < l_qty_on_full_pallet)
                 OR (l_pallet_counter = l_pallet_cnt_before_redist)) THEN
             l_qty_to_put_on_pallet := l_ref_total_qty_for_item;
             l_ref_total_qty_for_item := 0;
          ELSIF ( l_ref_total_qty_for_item > l_qty_on_full_pallet ) THEN
             l_qty_to_put_on_pallet := l_qty_on_full_pallet;
             l_ref_total_qty_for_item := l_ref_total_qty_for_item - l_qty_on_full_pallet;
          END IF;

          -- Update the oldest expiry date, mfg date to only the partial pallets,
          -- because these are the only pallets that are going to have cases from
          -- dIFferent pallets. Catch weight will be an average weight.


          IF (r_pallet_redistribute.qty >= l_qty_on_full_pallet) AND (l_qty_to_put_on_pallet <> 0 ) THEN

             -- This pallet will not have cases from other pallets,
             -- so leave the mfg date and exp date as it is.

             l_mfg_date := r_pallet_redistribute.mfg_date;
             l_exp_date := r_pallet_redistribute.exp_date;
             l_catch_weight := r_pallet_redistribute.catch_weight;

             -- IF the cases are removed from this pallet then adjust the catchweight accordingly.
             -- Update the catch weight to a full pallet.

             IF (r_pallet_redistribute.qty > l_qty_on_full_pallet) THEN
               l_catch_weight := l_split_catch_weight * l_qty_on_full_pallet;
             END IF;

          ELSIF (r_pallet_redistribute.qty < l_qty_on_full_pallet) AND (l_qty_to_put_on_pallet <> 0) THEN

             -- This pallet will have cases added to it from other pallets, update the
             -- oldest mfg date and exp date for the item.

             l_mfg_date := l_oldest_mfg_date;
             l_exp_date := l_oldest_exp_date;

             -- Catch weight should be adjusted to qty
             l_catch_weight := l_split_catch_weight * l_qty_to_put_on_pallet;

             ELSE -- Qty to put on pallet is 0
               l_mfg_date := NULL;
               l_exp_date := NULL;
               l_catch_weight := 0;

          END IF;

          UPDATE ERD_LPN
            SET qty = l_qty_to_put_on_pallet,
                mfg_date = l_mfg_date,
                exp_date = l_exp_date,
            catch_weight = l_catch_weight
            WHERE prod_id = r_pallet_redistribute.prod_id
            AND pallet_id = r_pallet_redistribute.pallet_id;


--          DBMS_OUTPUT.PUT_LINE ('     total Qty left -' || l_ref_total_qty_for_item ||
--                             ' pallet_id       ' || r_pallet_redistribute.pallet_id ||
--                             ' qty to be put on pallet ' || l_qty_to_put_on_pallet );

       END LOOP;

    l_qty_redistributed_for_item := TRUE;

  END IF;

  l_previous_prod_id := r_vn_item.prod_id;
  l_previous_cust_pref_vendor := r_vn_item.cust_pref_vendor;

  ------- COMMIT;  -- 02/16/2017  Brian Bent  We do not want commits in this package.

END LOOP;

EXCEPTION
   WHEN OTHERS THEN
     l_message := l_object_name
         || '(i_erm_id)'
         || '  PO/SN[' || i_erm_id || ']';
     pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                    SQLCODE, SQLERRM,
                    pl_rcv_open_po_types.ct_application_function,
                    gl_pkg_name);
     RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                             l_object_name || ': ' || SQLERRM);

END PALLET_SPLIT_OPTIMIZE;


---------------------------------------------------------------------------
-- Function:
--    save_erd_to_erd_case
--
-- Description:
--    This procedure builds will populate the erd_case table with the erd
--    lines for a produced item PO. ERD lines that have the same prod_id,
--    cpv, order_id, and uom will have the same erm_line_id in the ERD_CASE table.
--
--    RETURNS TRUE if save is successful, false otherwise. Successful means the # of 
--      erd records is equal to # of erd_case records
---------------------------------------------------------------------------
FUNCTION save_erd_to_erd_case (
    i_erm_id IN erm.erm_id%TYPE
) RETURN BOOLEAN
IS
    CURSOR c_get_erd(cp_erm_id erm.erm_id%TYPE) IS
    select d.* 
    from erm e, pm, erd d
    where e.erm_id = d.erm_id
    and pm.prod_id = d.prod_id
    and pm.cust_pref_vendor = d.cust_pref_vendor
    and d.erm_id = cp_erm_id
    order by d.order_id, d.prod_id, d.cust_pref_vendor, d.uom;

    l_object_name varchar(30) := 'save_erd_to_erd_case';
    l_message swms_log.msg_text%TYPE;
    l_prev_prod_id erd.prod_id%TYPE;
    l_prev_order_id erd.order_id%TYPE;
    l_prev_cust_id erd.cust_id%TYPE;
    l_prev_cpv erd.cust_pref_vendor%TYPE;
    l_prev_uom erd.uom%TYPE;

    l_erm_line_id pls_integer := 0;
    l_erd_count pls_integer := 0;
    l_erd_case_count pls_integer := 0;

BEGIN
    pl_log.ins_msg(
        pl_lmc.ct_info_msg, l_object_name, 'Starting ' || l_object_name,
        SQLCODE, SQLERRM,
        pl_rcv_open_po_types.ct_application_function,
        gl_pkg_name);

    for r_erd in c_get_erd(i_erm_id) loop

        -- If there is a new item/order_id, reinitialize the variables and increment the line_id
        if (r_erd.prod_id != nvl(l_prev_prod_id, 'x') OR
            NVL(r_erd.order_id, 'NULL') != nvl(l_prev_order_id, 'x') OR
            NVL(r_erd.cust_id, 'NULL')  != nvl(l_prev_cust_id, 'x') OR
            r_erd.uom != nvl(l_prev_uom, -1) OR
            r_erd.cust_pref_vendor != nvl(l_prev_cpv, 'x'))
        then
            l_erm_line_id := l_erm_line_id + 1;
            l_prev_prod_id := r_erd.prod_id;
            l_prev_order_id := r_erd.order_id;
            l_prev_cust_id := r_erd.cust_id;
            l_prev_cpv := r_erd.cust_pref_vendor;
            l_prev_uom := r_erd.uom;
        end if;

        begin
            insert into erd_case (
                erm_id, erm_line_id, item_seq,
                prod_id, cust_id, cust_name,
                cmt, weight, temp,
                qty, uom, qty_rec, uom_rec,
                order_id, cust_pref_vendor, master_case_ind,
                status, prd_weight, exp_date,
                mfg_date, orig_erm_line_id
            ) values (
                i_erm_id, l_erm_line_id, r_erd.erm_line_id,--r_erd.item_seq
                r_erd.prod_id, r_erd.cust_id, r_erd.cust_name,
                r_erd.cmt, r_erd.weight, r_erd.temp,
                r_erd.qty, r_erd.uom, r_erd.qty_rec, r_erd.uom_rec,
                r_erd.order_id, r_erd.cust_pref_vendor, r_erd.master_case_ind,
                r_erd.status, r_erd.prd_weight, r_erd.exp_date,
                r_erd.mfg_date, r_erd.erm_line_id
            );

            l_erd_case_count := l_erd_case_count + 1;
        exception when others then
            l_message := 'Unable to insert into ERD_CASE. ' || 
                'erm_id[' || r_erd.erm_id || '] ' || 
                'erm_line_id[' || r_erd.erm_line_id || '] ' || 
                'prod_id[' || r_erd.prod_id || '] ' ||
                'order_id[' || r_erd.order_id || '] ' ||
                'l_erm_line_id[' || l_erm_line_id || '] ';

            pl_log.ins_msg(
                pl_lmc.ct_fatal_msg, l_object_name, l_message, 
                SQLCODE, SQLERRM,
                pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            
            raise;
        end;

    end loop;

    select count(*) 
    into l_erd_count
    from erd
    where erm_id = i_erm_id;
    
    l_message := 'erd_case_count:' || l_erd_case_count || ' erd_count:' || l_erd_count;
    pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
        l_message, SQLCODE, SQLERRM,
        pl_rcv_open_po_types.ct_application_function,
        gl_pkg_name);
    
    IF l_erd_count = l_erd_case_count THEN
        pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
            'Deleting from ERD since save to ERD_CASE was successful', SQLCODE, SQLERRM,
            pl_rcv_open_po_types.ct_application_function,
            gl_pkg_name);

        -- Delete from erd so we can build and insert the new erd lines with the erd_case
        DELETE from erd
        WHERE erm_id = i_erm_id;
        
        RETURN true;
    ELSE
        RETURN false;
    END IF;


END save_erd_to_erd_case;


---------------------------------------------------------------------------
-- Procedure:
--    build_erd_from_erd_case
--
-- Description:
--    This procedure takes the combines the cases from ERD_CASE table and
--    inserts them into the ERD table.
--
--    This procedure is only called in build_pallet_list_from_prod_po
--      if the save to erd_case was succesful.
---------------------------------------------------------------------------
PROCEDURE build_erd_from_erd_case (
    i_erm_id erm.erm_id%TYPE
)
IS
    l_object_name varchar2(30) := 'build_erd_from_erd_case';
    l_message swms_log.msg_text%TYPE;

    cursor c_get_line_id(cp_erm_id erm.erm_id%TYPE) is
        select distinct ec.erm_line_id
        from erm e, pm, erd_case ec
        where e.erm_id = ec.erm_id
        and pm.prod_id = ec.prod_id
        and pm.cust_pref_vendor = ec.cust_pref_vendor
        and ec.erm_id = cp_erm_id
        order by ec.erm_line_id;

    cursor c_erd_case_for_line(
        cp_erm_id erm.erm_id%TYPE, 
        cp_erm_line_id erd.erm_line_id%TYPE) is
        select ec.*
        from erm e, pm, erd_case ec
        where e.erm_id = ec.erm_id
        and pm.prod_id = ec.prod_id
        and pm.cust_pref_vendor = ec.cust_pref_vendor
        and ec.erm_id = cp_erm_id
        and ec.erm_line_id = cp_erm_line_id;

    l_prod_id erd.prod_id%TYPE;
    l_cust_id erd.cust_id%TYPE;
    l_cust_name erd.cust_name%TYPE;
    l_cmt erd.cmt%TYPE;
    l_weight erd.weight%TYPE;
    l_pm_avg_wt pm.avg_wt%TYPE;
    l_qty erd.qty%TYPE;
    l_uom erd.uom%TYPE;
    l_order_id erd.order_id%TYPE;
    l_cpv erd.cust_pref_vendor%TYPE;
    l_master_case_ind erd.master_case_ind%TYPE;
    l_prd_weight erd.prd_weight%TYPE;
    l_mfg_date erd.mfg_date%TYPE;
    l_exp_date erd.exp_date%TYPE;

BEGIN
    pl_log.ins_msg(
        pl_lmc.ct_info_msg, l_object_name, 'Starting ' || l_object_name,
        SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
        gl_pkg_name);
    
    for r_line_id in c_get_line_id(i_erm_id) loop
        begin
            select prod_id, cust_id,
                cust_name, cmt,
                uom, order_id,
                cust_pref_vendor, master_case_ind
            into l_prod_id, l_cust_id,
                l_cust_name, l_cmt,
                l_uom, l_order_id,
                l_cpv, l_master_case_ind
            from erd_case 
            where erm_id = i_erm_id
            and erm_line_id = r_line_id.erm_line_id
            and rownum = 1;
        exception when others then
            l_message := 'Unable to get data from erd_cases for erm_id[' || i_erm_id || '] ' ||
                ' erm_line_id[' || r_line_id.erm_line_id || '].';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);                
        end;

        begin
            select avg_wt
            into l_pm_avg_wt
            from pm
            where prod_id = l_prod_id;
        exception when others then
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Unable to get pm.avg_weight for item ' || l_prod_id,
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
        end;

        --Get the sum of the weight for the cases. If weight is null, use pm.avg_wt
        begin
            select sum(nvl(weight, l_pm_avg_wt * qty))
            into l_weight
            from erd_case
            where erm_id = i_erm_id
            and erm_line_id = r_line_id.erm_line_id;
        exception when others then
            l_message := 'Unable to get sum(weight) from erd_cases for erm_id[' || i_erm_id || '] ' ||
                ' erm_line_id[' || r_line_id.erm_line_id || '].';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
        end;

        --Get the sum of the prd_weight for the cases. If prd_weight is null, use pm.avg_wt
        begin
            select sum(nvl(prd_weight, l_pm_avg_wt * qty))
            into l_prd_weight
            from erd_case
            where erm_id = i_erm_id
            and erm_line_id = r_line_id.erm_line_id;
        exception when others then
            l_message := 'Unable to get sum(prd_weight) from erd_cases for erm_id[' || i_erm_id || '] ' ||
                ' erm_line_id[' || r_line_id.erm_line_id || '].';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
        end;

        -- Get the sum of the qty for the cases
        begin
            select sum(nvl(qty, 0))
            into l_qty
            from erd_case
            where erm_id = i_erm_id
            and erm_line_id = r_line_id.erm_line_id;
        exception when others then
            l_message := 'Unable to get sum(qty) from erd_cases for erm_id[' || i_erm_id || '] ' ||
                ' erm_line_id[' || r_line_id.erm_line_id || '].';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
        end;

        -- Get the oldest mfg_date
        begin
            select mfg_date
            into l_mfg_date
            from erd_case
            where erm_id = i_erm_id
            and erm_line_id = r_line_id.erm_line_id
            and rownum = 1
            order by mfg_date nulls last;
        exception when others then
            l_message := 'Unable to get mfg_date from erd_cases for erm_id[' || i_erm_id || '] ' ||
                ' erm_line_id[' || r_line_id.erm_line_id || '].';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
        end;

        -- Get the oldest mfg_date
        begin
            select exp_date
            into l_exp_date
            from erd_case
            where erm_id = i_erm_id
            and erm_line_id = r_line_id.erm_line_id
            and rownum = 1
            order by mfg_date nulls last;
        exception when others then
            l_message := 'Unable to get exp_date from erd_cases for erm_id[' || i_erm_id || '] ' ||
                ' erm_line_id[' || r_line_id.erm_line_id || '].';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
        end;
        
        insert into erd (
            erm_id, 
            erm_line_id,
            item_seq,
            prod_id,
            cust_id,
            cust_name,
            cmt,
            weight,
            qty,
            uom,
            order_id,
            cust_pref_vendor,
            master_case_ind,
            prd_weight,
            exp_date,
            mfg_date
        ) values (
            i_erm_id, 
            r_line_id.erm_line_id,
            r_line_id.erm_line_id,
            l_prod_id,
            l_cust_id,
            l_cust_name,
            l_cmt,
            l_weight,
            l_qty,
            l_uom,
            l_order_id,
            l_cpv,
            l_master_case_ind,
            l_prd_weight,
            l_exp_date,
            l_mfg_date
        );

    end loop;

END build_erd_from_erd_case;


---------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list_from_prod_po
--
-- Description:
--    This procedure builds the pallet list to putaway for a PO with produced items
--    Created for the Meat company project. 
---------------------------------------------------------------------------
PROCEDURE build_pallet_list_from_prod_po (
    i_r_syspars          IN  pl_rcv_open_po_types.t_r_putaway_syspars,
    i_erm_id             IN  erm.erm_id%TYPE,
    o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
    o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS

    l_object_name varchar(30) := 'build_pallet_list_from_prod_po';
    l_message swms_log.msg_text%TYPE;

    l_item_index pls_integer; -- Index of item IN item plsql table.
    l_num_full_pallets pls_integer; -- # of full pallets for the item

    --l_num_pallets pls_integer; -- # of pallets of the item including full + partial
    l_num_splits pls_integer; -- Extra splits when receiving cases. These will be dropped

    l_pallet_index pls_integer; -- Index
    l_pallet_qty pls_integer; -- Work area to hold the qty on the pallet (in SPLITS)
    l_seq_no pls_integer := 0; -- Used to populate putawaylst.seq_no

    l_qty_to_wh pls_integer;
    l_partial_pallet_qty pls_integer;
    l_num_total_pallets pls_integer; -- # of pallets for an item (full + partial pallets)
    l_prev_prod_id pm.prod_id%TYPE; -- Previous item processed.
    l_prev_cpv pm.cust_pref_vendor%TYPE; -- Previous CPV processed.
    l_prev_order_id erd.order_id%TYPE; -- Previous order ID processed.

    l_qty_cases erd.qty%TYPE;
    l_qty_splits erd.qty%TYPE;
    l_total_weight tmp_weight.total_weight%TYPE;
    l_pallet_weight putawaylst.weight%TYPE;
    l_staging_loc inbound_cust_setup.staging_loc%TYPE;
    l_erd_count pls_integer;
    l_erd_case_count pls_integer;
    l_erd_save_success boolean;

    CURSOR c_erd(cp_erm_id erd.erm_id%TYPE) IS
        SELECT NVL(d.uom, 0) uom,
            d.prod_id,
            d.cust_pref_vendor,
            erm.source_id,
            pm.brand,
            pm.mfg_sku,
            pm.category,
            erm.erm_type,
            pm.mx_max_case,
            d.cust_id,
            d.order_id,
            sum(nvl(d.prd_weight, 0)) prd_weight,
            d.mfg_date,
            d.exp_date,
            sum(d.qty) total_qty,
            min(d.erm_line_id) min_erm_line_id,
            erm.sort_ind
        FROM erm, pm, erd d
        WHERE erm.erm_id = d.erm_id
        AND d.erm_id = cp_erm_id
        AND pm.prod_id = d.prod_id
        AND pm.cust_pref_vendor = d.cust_pref_vendor
        AND erm.status in ('NEW', 'SCH', 'TRF')
        GROUP BY NVL(d.uom, 0), d.prod_id, d.cust_pref_vendor, d.order_id,
            d.cust_id, d.mfg_date, d.exp_date, pm.brand, pm.mfg_sku, 
            pm.category, erm.erm_type, pm.mx_max_case, erm.source_id, erm.sort_ind
        ORDER BY NVL(d.uom, 0) DESC, d.prod_id, d.cust_pref_vendor, d.order_id,
            pm.mfg_sku, pm.category, erm.erm_type;

    CURSOR c_get_item_weight(cp_erm_id erd.erm_id%TYPE, cp_prod_id erd.prod_id%TYPE) IS
        SELECT sum(prd_weight)
        FROM erm, erd, pm
        WHERE erm.erm_id = erd.erm_id
        AND pm.prod_id = erd.prod_id
        AND erd.prod_id = cp_prod_id
        AND erd.erm_id = cp_erm_id
        AND pm.cust_pref_vendor = erd.cust_pref_vendor
        GROUP BY erd.prod_id;
        -- knha8378 comment out uom check AND erd.uom != 1

    CURSOR c_get_case_qty(cp_erm_id erd.erm_id%TYPE, cp_prod_id erd.prod_id%TYPE) IS
        SELECT sum(erd.qty) total_qty
        FROM erm, erd, pm
        WHERE erm.erm_id = erd.erm_id
        AND pm.prod_id = erd.prod_id
        AND erd.prod_id = cp_prod_id
        AND erd.erm_id = cp_erm_id
        AND pm.cust_pref_vendor = erd.cust_pref_vendor
        GROUP BY erd.prod_id;
        -- knha8378 comment out uom check AND erd.uom != 1
    
    CURSOR c_get_split_qty(cp_erm_id erd.erm_id%TYPE, cp_prod_id erd.prod_id%TYPE) IS
        SELECT sum(erd.qty) total_qty
        FROM erm, erd, pm
        WHERE erm.erm_id = erd.erm_id
        AND pm.prod_id = erd.prod_id
        AND erd.prod_id = cp_prod_id
        AND erd.erm_id = cp_erm_id
        AND pm.cust_pref_vendor = erd.cust_pref_vendor
        AND erd.uom = 1
        GROUP BY erd.prod_id;

BEGIN
    pl_log.ins_msg(
        pl_lmc.ct_warn_msg, l_object_name, 'Starting ' || l_object_name,
        SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
        gl_pkg_name);

    SELECT count(*)
    INTO l_erd_case_count
    FROM erd_case
    WHERE erm_id = i_erm_id;

    --
    -- Before we try to save to ERD_CASE, check if it's already there. If the ERD_CASE count is
    -- greater than 0, then it means that it was already saved. PO was released.
    -- If the count = 0, then save to ERD_CASE and build back to ERD.
    --
    IF l_erd_case_count = 0 THEN
        l_erd_save_success := save_erd_to_erd_case(i_erm_id);

        IF l_erd_save_success THEN
            build_erd_from_erd_case(i_erm_id);
        ELSE
            pl_log.ins_msg(
                pl_lmc.ct_info_msg, l_object_name, 'Save ERD to ERD_CASE unsuccessful, raising error',
                SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                gl_pkg_name);

            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name 
                || ': Save ERD records to ERD_CASE unsuccessful. Count of records mismatched after inserting.');

        END IF;
    ELSE
        pl_log.ins_msg(
            pl_lmc.ct_info_msg, l_object_name, 
            'Records already exist in ERD_CASE. Skipping the process that saves to ERD_CASE and builds back to ERD',
            SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
    END IF;

    --
    -- Float the finish good items on the production POs if they are not already slotted to a floating zone
    --
    assign_finish_good_item_to_flt(i_erm_id);

    -- Initializtion
    l_pallet_index := 1;

    FOR r_erd IN c_erd(i_erm_id) LOOP
        IF (r_erd.prod_id != nvl(l_prev_prod_id, 'x') OR
            r_erd.cust_pref_vendor != nvl(l_prev_cpv, 'x') OR
            r_erd.order_id != nvl(l_prev_order_id, 'x')) THEN

            get_item_info(
                i_r_syspars,
                r_erd.prod_id,
                r_erd.cust_pref_vendor,
                i_erm_id,
                l_item_index,
                o_r_item_info_table);

            l_prev_prod_id := r_erd.prod_id;
            l_prev_order_id := r_erd.order_id;
            l_prev_cpv := r_erd.cust_pref_vendor;

            --DUP_VAL_ON_INDEX
            BEGIN
                OPEN c_get_case_qty(i_erm_id, r_erd.prod_id);
                FETCH c_get_case_qty into l_qty_cases;
                CLOSE c_get_case_qty;

                /* knha8378 Nov 11, 2019 do not calculate split
                OPEN c_get_split_qty(i_erm_id, r_erd.prod_id);
                FETCH c_get_split_qty into l_qty_splits;
                CLOSE c_get_split_qty;
		*/
		l_qty_splits := null;

                OPEN c_get_item_weight(i_erm_id, r_erd.prod_id);
                FETCH c_get_item_weight into l_total_weight;
                CLOSE c_get_item_weight;

                INSERT INTO tmp_weight (
                    erm_id, 
                    prod_id,
                    cust_pref_vendor, 
                    total_cases,
                    total_splits, 
                    total_weight)
                VALUES (
                    i_erm_id, 
                    r_erd.prod_id,
                    r_erd.cust_pref_vendor, 
                    l_qty_cases,
                    l_qty_splits, 
                    l_total_weight);

            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    l_message := 'Weight already inserted for this item. This is not a fatal error.';
                    pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
            END;
        END IF;

        show_item_info(l_item_index, o_r_item_info_table);

        IF (r_erd.uom != 1) THEN
            -- Receiving cases.
            -- Any splits are sropped. These would be on the partial pallet.
            -- Note that there should not be any splits
            --
            l_qty_to_wh := r_erd.total_qty;
            --pl_log.ins_msg('INFO', l_object_name, 'full_pallet_qty_in_splits:' || o_r_item_info_table(l_item_index).full_pallet_qty_in_splits, null, null);
            l_num_full_pallets := TRUNC(l_qty_to_wh / 
                o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);
            l_partial_pallet_qty := 
                MOD(l_qty_to_wh, o_r_item_info_table(l_item_index).full_pallet_qty_in_splits);

            IF (l_partial_pallet_qty > 0) THEN
                l_num_splits := MOD(l_partial_pallet_qty, o_r_item_info_table(l_item_index).spc);
                IF (l_num_splits != 0) THEN
                    --
                    -- Not an even number of cases on the partial pallet, drop extra splits
                    --
                    l_partial_pallet_qty := l_partial_pallet_qty - l_num_splits;

                    pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name,
                        ' Item[' || o_r_item_info_table(l_item_index).prod_id || ']'
                        ||'  CPV['
                        || o_r_item_info_table(l_item_index).cust_pref_vendor || ']'
                        || '  PO/SN[' || i_erm_id || ']'
                        || '  PO Qty(IN splits)[' || TO_CHAR(r_erd.total_qty)|| ']'
                        || '  SPC['
                        || TO_CHAR(o_r_item_info_table(l_item_index).spc) || ']'
                        || '  Cases['
                        || TRUNC(r_erd.total_qty / o_r_item_info_table(l_item_index).spc)
                        || ']'
                        || '  Extra Splits[' || TO_CHAR(l_num_splits) || ']'
                        || '  Receiving cases but the qty is not an even number'
                        || ' of cases.  The splits will be dropped.',
                        NULL, NULL);
                END IF;
            END IF;

            IF (l_partial_pallet_qty > 0) THEN
                l_num_total_pallets := l_num_full_pallets + 1;
            ELSE
                l_num_total_pallets := l_num_full_pallets;
            END IF;

        ELSE
            --
            -- Receiving Splits
            --
            -- The entire qty will be one pallet and treated as a partial pallet
            --
            l_qty_to_wh := r_erd.total_qty;
            l_num_total_pallets := 1;
            l_partial_pallet_qty := r_erd.total_qty;

        END IF;

        FOR i in 1..l_num_total_pallets LOOP
            l_seq_no := l_seq_no + 1;
            IF (i = 1 AND l_partial_pallet_qty > 0) THEN
                -- Partial pallet
                l_pallet_qty := l_partial_pallet_qty;
                o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'Y';
            ELSE
                -- Full pallet
                l_pallet_qty := o_r_item_info_table(l_item_index).full_pallet_qty_in_splits;
                o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'N';
            END IF;

            o_r_pallet_table(l_pallet_index).pallet_id          := f_get_new_pallet_id(i_erm_id);
            o_r_pallet_table(l_pallet_index).prod_id            := r_erd.prod_id;
            o_r_pallet_table(l_pallet_index).cust_pref_vendor   := r_erd.cust_pref_vendor;
            o_r_pallet_table(l_pallet_index).qty                := l_pallet_qty;
            o_r_pallet_table(l_pallet_index).qty_received       := l_pallet_qty;
            o_r_pallet_table(l_pallet_index).qty_expected       := l_pallet_qty;
            o_r_pallet_table(l_pallet_index).uom                := r_erd.uom;
            o_r_pallet_table(l_pallet_index).item_index         := l_item_index;
            o_r_pallet_table(l_pallet_index).erm_id             := i_erm_id;
            o_r_pallet_table(l_pallet_index).erm_type           := r_erd.erm_type;
            o_r_pallet_table(l_pallet_index).seq_no             := l_seq_no;
            o_r_pallet_table(l_pallet_index).po_no              := i_erm_id;
            o_r_pallet_table(l_pallet_index).erm_line_id        := r_erd.min_erm_line_id;
            o_r_pallet_table(l_pallet_index).cust_id            := r_erd.cust_id;
            o_r_pallet_table(l_pallet_index).order_id           := r_erd.order_id;
            o_r_pallet_table(l_pallet_index).auto_confirm_put   := 'Y';
            o_r_pallet_table(l_pallet_index).mfg_date           := NVL(r_erd.mfg_date, sysdate);
            o_r_pallet_table(l_pallet_index).exp_date           := 
                NVL(r_erd.exp_date, o_r_pallet_table(l_pallet_index).mfg_date + o_r_item_info_table(l_item_index).mfr_shelf_life); -- Calc the exp date if it's null

            -- Set data collect flags since we are Auto confirming put/inv
            o_r_pallet_table(l_pallet_index).collect_exp_date := 'N';
            o_r_pallet_table(l_pallet_index).collect_mfg_date := 'N';
            o_r_pallet_table(l_pallet_index).collect_lot_id := 'N';
            o_r_pallet_table(l_pallet_index).collect_catch_wt := 'N';
            o_r_pallet_table(l_pallet_index).collect_temp := 'N';
            o_r_pallet_table(l_pallet_index).collect_clam_bed := 'N';
            o_r_pallet_table(l_pallet_index).collect_tti := 'N';
            o_r_pallet_table(l_pallet_index).collect_cool := 'N';

            --
            -- Set catch_weight and inv_weight. catch_weight is the calculated weight of what's
            -- on the pallet, and it's used for trans.weight and putawaylst.weight, 
            -- inv_weight is the calculated weight of a case, and it's used for inv.weight
            -- inv_weight needs to be the weight of a case since SOS short calculation assumes
            -- the inv.weight of a finish good item is 1 case.
            --
            IF (r_erd.prd_weight is NULL) THEN
                o_r_pallet_table(l_pallet_index).inv_weight := 
                    o_r_item_info_table(l_item_index).avg_wt * o_r_item_info_table(l_item_index).spc;

                o_r_pallet_table(l_pallet_index).catch_weight := 
                    o_r_item_info_table(l_item_index).avg_wt * l_pallet_qty;
            ELSE
                o_r_pallet_table(l_pallet_index).inv_weight := 
                    r_erd.prd_weight / r_erd.total_qty * o_r_item_info_table(l_item_index).spc;

                o_r_pallet_table(l_pallet_index).catch_weight := r_erd.prd_weight / r_erd.total_qty * l_pallet_qty;
            END IF;

            --
            -- Get the destination location. It will try to get the location
            -- based on customer setup.
            --
            IF r_erd.sort_ind = 'S' THEN -- Build to stock (send the items to the PIT location)
                l_staging_loc := f_get_pit_location(r_erd.source_id);
                -- Set the order_id and cust_id to NULL since these are build to stock
                -- and there won't be an order for the items from this specific PO.
                o_r_pallet_table(l_pallet_index).order_id := NULL;
                o_r_pallet_table(l_pallet_index).cust_id := NULL;
            ELSE 
                l_staging_loc := f_get_cust_staging_loc(r_erd.cust_id, r_erd.sort_ind);

                IF l_staging_loc is NULL THEN
                    l_staging_loc := f_get_pit_location(r_erd.source_id);
                END IF;
            END IF;

            o_r_pallet_table(l_pallet_index).dest_loc := l_staging_loc;
            o_r_pallet_table(l_pallet_index).direct_to_prod_staging_loc := TRUE;

            o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln := FALSE;

            --
            -- Calculate the cube and height of the pallet and other stuff.
            --
            determine_pallet_attributes(
                o_r_item_info_table(l_item_index),
                l_pallet_index,
                o_r_pallet_table);
            
            l_pallet_index := l_pallet_index + 1;
        END LOOP; -- End pallet loop
    END LOOP; -- End c_erd loop

EXCEPTION 
    WHEN OTHERS THEN
        l_message := l_object_name ||
            '(i_r_syspars, i_erm_id, o_r_item_info_table, o_r_pallet_table)' ||
            ' PO/SN[' || i_erm_id || ']';
        pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message, SQLCODE, SQLERRM);
        RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);

END build_pallet_list_from_prod_po;


---------------------------------------------------------------------------
--  Procedure:
--      assign_finish_good_item_to_flt
--  
--  Description:
--      If the item on the production PO is not slotted to a floating
--      zone, then we will auto assign it to a floating zone based off
--      of the pm.area to look for corresponding zone in that area.
--      
---------------------------------------------------------------------------
PROCEDURE assign_finish_good_item_to_flt(i_erm_id IN erm.erm_id%TYPE)
IS

    l_object_name varchar(30) := 'assign_finish_good_item_to_flt';
    l_message swms_log.msg_text%TYPE;

    l_zone_id zone.zone_id%TYPE;
    l_last_ship_slot pm.last_ship_slot%TYPE;
    l_pallet_type pm.pallet_type%TYPE;

    CURSOR c_floating_zone(cp_area_code zone.z_area_code%TYPE) IS
        SELECT zone_id
        FROM zone
        WHERE rule_id = 1
            AND z_area_code = cp_area_code;

    CURSOR c_find_a_slot_in_zone_no_inv(cp_zone_id lzone.zone_id%TYPE) IS
        SELECT lz.logi_loc, l.pallet_type
        FROM lzone lz, zone z, loc l
        WHERE lz.zone_id = z.zone_id
        AND lz.zone_id = cp_zone_id
        AND lz.logi_loc = l.logi_loc
        AND z.zone_type = 'PUT'
        AND z.rule_id = 1
        AND NOT EXISTS (
            SELECT 1 FROM inv
            WHERE inv.plogi_loc = lz.logi_loc
        );

    CURSOR c_find_any_slot_in_zone(cp_zone_id lzone.zone_id%TYPE) IS
        SELECT lz.logi_loc, l.pallet_type
        FROM lzone lz, zone z, loc l
        WHERE lz.zone_id = z.zone_id
        AND lz.zone_id = cp_zone_id
        AND lz.logi_loc = l.logi_loc
        AND z.zone_type = 'PUT'
        AND z.rule_id = 1;

    CURSOR c_finish_good_items(cp_erm_id erd.erm_id%TYPE) IS
        SELECT *
        FROM pm
        WHERE finish_good_ind = 'Y' 
            AND zone_id is NULL
            AND NOT EXISTS (
                select 1 from inv
                where inv.prod_id = pm.prod_id
                and inv.plogi_loc = inv.logi_loc
            )
            AND prod_id in (
                select distinct prod_id
                from erd
                where erm_id = cp_erm_id
                and erd.prod_id = pm.prod_id
            )
        FOR UPDATE OF zone_id, last_ship_slot, pallet_type;

BEGIN
    
    pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, 'Starting ' || l_object_name || '. i_erm_id:' || i_erm_id,
        SQLCODE, SQLERRM, pl_rcv_open_po_types.ct_application_function,
        gl_pkg_name);
    
    FOR item in c_finish_good_items(i_erm_id) LOOP

        l_message := 'Item ' || item.prod_id|| ' found without a zone_id.';
        pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, SQLCODE, SQLERRM, 
            pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

        OPEN c_floating_zone(item.area);
        FETCH c_floating_zone into l_zone_id;

        IF c_floating_zone%NOTFOUND THEN
            l_message := 'No floating zone found for area ' || item.area || '. This item''s pallets will *';
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, SQLCODE, SQLERRM, 
                pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
            
            CLOSE c_floating_zone;  
            CONTINUE;   
        ELSE
            l_message := 'Floating zone ' || l_zone_id || ' found for area ' || item.area;
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, SQLCODE, SQLERRM, 
                pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

            OPEN c_find_a_slot_in_zone_no_inv(l_zone_id);
            FETCH c_find_a_slot_in_zone_no_inv into l_last_ship_slot, l_pallet_type;
            
            IF c_find_a_slot_in_zone_no_inv%NOTFOUND THEN
                l_message := 'No open locations found in lzone for zone ' || NVL(l_zone_id, '<NULL value>');
                pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, SQLCODE, SQLERRM, 
                    pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

                OPEN c_find_any_slot_in_zone(l_zone_id);
                FETCH c_find_any_slot_in_zone into l_last_ship_slot, l_pallet_type;
                
                IF c_find_any_slot_in_zone%NOTFOUND THEN
                    l_message := 'No locations found in lzone for zone ' || NVL(l_zone_id, '<NULL value>');
                    pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, SQLCODE, SQLERRM, 
                        pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
                END IF;

                CLOSE c_find_any_slot_in_zone;

            ELSE
                l_message := 'Location ' || l_last_ship_slot || ' found in zone ' || l_zone_id;
                pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, SQLCODE, SQLERRM, 
                    pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
            END IF;

            CLOSE c_find_a_slot_in_zone_no_inv;

            UPDATE pm
            SET zone_id = l_zone_id,
                last_ship_slot = l_last_ship_slot,
                pallet_type = l_pallet_type
            WHERE CURRENT OF c_finish_good_items;

            l_message := 'Item ' || item.prod_id || ' zone, last_ship_slot, pallet_type updated to ' ||
                 l_zone_id || ', ' || l_last_ship_slot || ', ' || l_pallet_type;
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message, SQLCODE, SQLERRM, 
                pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
        
        END IF;

        CLOSE c_floating_zone;  

    END LOOP;

END assign_finish_good_item_to_flt;



END pl_rcv_open_po_pallet_list;  -- end package body
/


