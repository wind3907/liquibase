PROMPT Creating package PL_PUTAWAY_UTILITIES...

CREATE OR REPLACE PACKAGE SWMS.pl_putaway_utilities
AS
   --  sccs_id=@(#) src/schema/plsql/pl_putaway_utilities.sql, swms, swms.9, 11.2 1/28/10 1.26

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_putaway_utilities.
   --
   -- Description:
   --    Common procedures and functions within SWMS.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/04/02          Initial Version
   --    10/23/02 acppxp   Added function of Hiep for determining prompts
   --    10/24/02 acppxp   Added new procedures for setting up pallet and
   --                      available and occupied heights.
   --    11/20/02 acppxp   Changes made in check home item to check rank
   --    11/21/02 acppxp   Changes made in clam bed method to select distinct
   --                      Category
   --    03/03/03 acpaks   Changes made to the p_find_xfr_slots procedure,
   --                      Added Cubes logic, Ext_Case_Cube.flag check to it.
   --    04/30/03 prphqb   Made change to use max_qty for directed HST
   --    05/21/03 acppxp   Changes made for loop in Update_heights procedure.
   --    07/02/03 acppzp   Made changes for Do not Print LPN
   --    07/04/03 acpaks   Changes made to p_find_xfr_slots, such that it does
   --                      not identify slots that have MSKU pallets in it.
   --    07/23/03 acppzp   DN# 11349 Changes for OSD and  SN Receipt
   --    11/13/03 acpppp   DN# 11422 For MSKU, changes made so that
   --                      p_insert_table will not raise error even if the
   --                      zone_id for the product is null.
   --    01/29/04 prpakp   Added tti checking for HACCP items.
   --    07/15/04 prplhj   D#11664/11665 Rewrote p_find_xfr_slots() to use logic
   --                      similiar to putaway logic.
   --    10/15/04 prplhj   D#11776 Round the l_pallet_size variable on
   --                      p_find_xfr_slots() to 2 digits after decimal.
   --
   --    02/22/05 prpbcb   Oracle 8 rs239b swms9 DN 11870
   --                      COOL changes.
   --                      Added cool_trk field to t_item_related_info RECORD.
   --                      Added function f_is_cool_tracked_item.
   --                      Modified procedure p_insert_table to populate
   --                      putawaylst.cool_trk from
   --                      io_item_related_info.v_cool_trk.
   --                      Modified procedure p_get_item_info to populate
   --                      io_item_related_info_rec.v_cool_trk using function
   --                      f_is_cool_tracked_item.
   --
   --    03/09/05 prpbcb   Oracle 8 rs239b swms9 DN 11884
   --                      Changed function f_is_clam_bed_tracked_item() to
   --                      use table HACCP_CODES and not HS_CODE.
   --                      Table HACCP_CODES replaces table HS_CODE.
   --
   --    03/09/05 prpbcb   Oracle 8 rs239b swms9 DN 11982
   --                      Ticket: 35738
   --                      Changed f_is_clam_bed_tracked_item to use a
   --                      cursor instead of select distinct.  The cursor
   --                      is a little faster.
   --
   --                      In record type declaration t_work_var
   --                      initialized v_dmg_ind to 'AVL'.  Before it was
   --                      initialized to null which would cause undesired
   --                      results because the are conditions in
   --                      pl_general_rule written like
   --                         IF ...  io_workvar_rec.v_dmg_ind <> 'DMG' THEN
   --                      This would only affect putaway by inches since
   --                      pl_general_rule is used for inches.
   --  07/29/05   acppsp   DN # 11974:Changes in function f_get_HST_prompt
   --                      for DMD  replenishment.
   --  08/09/05   prpakp   Corrected the last ship slot issue. If the last ship
   --                      doesn't exist in loc or las_ship_slot is not in the
   --                      pm zone, the last ship_slot will be cleared so that
   --                      this will not cause issue at the time of open SN.
   --                      procedure changed is p_get_item_info.
   --
   --    09/16/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
   --                      Function f_is_clam_bed_tracked_item() was not
   --                      returning the correct value.  In the cursor changed
   --                         AND clambed_trk = 'C';
   --                      to
   --                         AND haccp_type = 'C';
   --
   --    09/27/05 prpbcb   Oracle 8 rs239b swms9 DN 12000
   --                      Had logic error in f_is_clam_bed_tracked_item().
   --
   --    02/05/06 prpbcb   Oracle 8 rs239b swms9 DN 12048
   --                      WAI changes for MSKU pallets.
   --                      Add the following fields to record type
   --                      t_item_related_info.
   --                         - n_rule_id              zone.rule_id%TYPE
   --                         - v_split_zone_id        pm.split_zone_id%TYPE
   --                         - n_split_zone_rule_id   zone.rule_id%TYPE
   --                         - v_auto_ship_flag       pm.auto_ship_flag%TYPE
   --                    - v_miniload_storage_ind pm.miniload_storage_ind%TYPE
   --                         - v_case_induction_loc   loc.logi_loc%TYPE
   --                         - v_split_induction_loc  loc.logi_loc%TYPE
   --
   --                      Modified functions/procedures:
   --                         - f_check_home_item()
   --
   --                      Populate inv.inv_uom.  0 always used since the
   --                      inventory creating procedures in this package are
   --                      used only with a MSKU (for non-MSKU the pl_rcv_open*
   --                      packages are used).
   --
   --    07/10/06 prpbcb   Oracle 8 rs239b swms9 DN 12208
   --                      Ticket: 144403
   --                      Project: 144403-RF LOV Transfer Blank
   --                      Procedure p_find_xfr_slots() was not selecting
   --                      available open deep slots when putaway was by
   --                      inches.  There was a bug that resulted in an error
   --                      which resutlted in blank list
   --                      Put in 9.7.2.
   --
   --   02/27/07 prppxx    Fix TD6201 Populate sysdate instead of
   --                      erd_lpn.exp_date in PUTAWAYLST for non_exp_date
   --                      track item. D12216.
   --                      Added n_mfr_shelf_life field to t_item_related_info
   --                      RECORD and populated it when getting the item info.
   --
   --    04/19/07 prpbcb   DN 12235
   --                      Ticket: 265200
   --                      Project: 265200-Putaway By Inches Modifications
   --
   --                      Changed pm.mfr_shelf_life to NVL(pm.mfr_shelf_life,0)
   --                      in the select from the PM table in procedure
   --                      p_get_item_info().
   --
   --                      Added CPV parameter to procedure
   --                      p_update_heights_for_item().  Created another
   --                      p_update_heights_for_item() procedure with a
   --                      different parameter list to call from the
   --                      insert/update database trigger on the PM table
   --                      when the case height changes and putaway is by
   --                      inches.  Created another p_update_height_data()
   --                      to call from p_update_heights_for_item().
   --                      To prevent the mutating table error when calling
   --                      p_update_heights_for_item() from the trigger the
   --                      relevant item info is passed in the parameter list.
   --
   --    10/04/07 prppxx   DN 12292 Force data collection if erd_lpn.exp_date
   --                      is greater than 10 yrs old.
   --
   --    04/21/08 prpbcb   DN 12372
   --                      Project: 491264-Case Height Change
   --
   --                      The changes I made on 04/19/07 for recalculating
   --                      the heights when the case height changes did not
   --                      work correctly when a slot had different items.
   --
   --                      I looked at few ways to fix the issue and settled on
   --                      option 3 as it will handle all situations.  There
   --                      are situations options 1 and 2 will not handle
   --                      which would result in the old case height being used.
   --                      1.  Create another procedure similar to
   --                          p_update_heights_for_item() using an autonomous
   --                          transaction.  The draw back to this is if the
   --                          change to the case height is rolled back the
   --                          re-calculation has already taken place.
   --
   --                      2.  Create a procedure using an
   --                          autonomous transaction to select and save in an
   --                          array of records the item, cpv, ti, hi and spc
   --                          of the the others items in the same slot as the
   --                          item with the changed case height.  Then most
   --                          likely create another p_update_height_data
   --                          passing this array of records and doing the
   --                          appropriate processing then calling
   --                             - p_update_heights_for_item()
   --                             - p_update_height_data()
   --
   --                      3.  Change the update row database trigger on the PM
   --                          table to save the item and cpv in a PLSQL table
   --                          when the case height changes and there is
   --                          inventory for the item and putaway is by inches.
   --                          Create an after update statement trigger on the
   --                          PM table that check the PLSQL table populated
   --                          by the update row trigger and if any items found
   --                          to call p_update_heights_for_item().
   --
   --                      Created PL/SQL record t_r_item_info_for_inches
   --                      and PL/SQL table type t_r_item_info_for_inches_tbl.
   --                      The PL/SQL table will be populated by the update
   --                      before row trigger on the PM table and used in the
   --                      after update statement trigger on the PM table.
   --
   --
   --                      Moved cursor c_loc_item_info_by_loc from
   --                      procedure p_update_heights_for_item() to the
   --                      package body so it is private to the package body.
   --
   --
   --      10/20/09 ctvgg000    Project : ASN to all OPCO's
   --               Made changes to include VSN in parts of the code
   --               where SN Pallets are handled.
   --
   --      01/22/10 prplhj  D# 12538 Change f_is_cool_tracked_item() to add
   --               cool_category table to match with what order
   --               processing does. Add a default i_category argument
   --               to the function. Add a default i_haradous argument
   --               to the f_is_tti_tracked_item().
   --               Add f_is_tti_tracked_item2() which only accepts
   --               input hazardous code as its argument and not care
   --               about the item #.
   --               Add f_is_clam_bed_tracked_item2() which only accepts
   --               input category as its argument. The syspar
   --               CLAM_BED_TRACKED value is handled inside.
   --
   --   9/18/14 Vred5319 - added  mx_item_assign_flag to t_item_related_info
   --
   --    09/25/14 prpbcb   Symbotic changes.
   --
   --                     Add fields to t_item_related_info record type.
   --                        - prod_id
   --                        - cust_pref_vendor
   --                        - aging_days
   --                        - mx_eligible
   --                        - mx_case_msku_induction_loc
   --
   --                     Modified functions/procedures:
   --                        - p_get_item_info
   --                             Assign the prod id and cpv in the record
   --                        - f_check_home_item
   --                             The parameter is now the item info record
   --                             and not the individual fields.
   --                        - f_check_home_item
   --                             It is now passed the item info record and not
   --                             individual fields.
   -- vkal9662 Add Procedure p_is_loc_zone_restrict for Jira 327
   --------------------------------------------------------------------------

   --------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
   --------------------------------------------------------------------------
   gv_crt_message    VARCHAR2(4000);--for CRT messages

   gb_reprocess      BOOLEAN; --set by reprocess method
   gv_program_name   VARCHAR2(50);--for display of routine name
                                   --in exception message
   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

  ADD_HOME      CONSTANT INTEGER      := 1;
  ADD_RESERVE   CONSTANT INTEGER      := 0;
  ADD_NO_INV    CONSTANT NUMBER       := 2;
  FIRST         CONSTANT NUMBER       := 1;
  SECOND        CONSTANT NUMBER       := 2;
  DIFFERENT     CONSTANT INTEGER      := 0;
  SAME          CONSTANT INTEGER      := 1;
  PROGRAM_CODE  CONSTANT VARCHAR2(50) := 'REXX';
  SUCCESS       CONSTANT VARCHAR2(1)  := '0';
  FAILURE       CONSTANT VARCHAR2(1)  := '1';
  -- This constant will be used for dimension setup.Since dimensions for all
  -- items in inventory has to be setup there will be an Commit at a constant
  -- interval.  This interval has been defined by this variable.
  COMMIT_INTERVAL CONSTANT NUMBER     :=50;

    ---------------------------------------------------------------------------
   -- Global Type Declarations
    ---------------------------------------------------------------------------

  TYPE t_syspar_var IS RECORD
  (
   v_allow_flag                        sys_config.config_flag_val%TYPE,
   v_mixprod_flag                      sys_config.config_flag_val%TYPE,
   v_aisle_flag                        sys_config.config_flag_val%TYPE,
   v_pallet_type_flag                  sys_config.config_flag_val%TYPE,
   v_mix_prod_2d3d_flag                sys_config.config_flag_val%TYPE,
   v_mix_prod_bulk_area                sys_config.config_flag_val%TYPE,
   v_res_loc_co_flag                   sys_config.config_flag_val%TYPE,
   v_g_mix_same_prod_deep_slot         sys_config.config_flag_val%TYPE,
   v_clam_bed_tracked_flag             sys_config.config_flag_val%TYPE
  );

  TYPE t_po_info IS RECORD
  (
   v_erm_id                            erm.erm_id%TYPE,
   v_erm_type                          erm.erm_type%TYPE,
   v_wh_id                             erm.warehouse_id%TYPE,
   v_to_wh_id                          erm.to_warehouse_id%TYPE
  );

  TYPE t_item_related_info IS RECORD
  (
    prod_id                            pm.prod_id%TYPE,
    cust_pref_vendor                   pm.cust_pref_vendor%TYPE,
    n_ti                               pm.ti%TYPE,
    n_hi                               pm.hi%TYPE,
    v_pallet_type                      pm.pallet_type%TYPE,
    v_lot_trk                          pm.lot_trk%TYPE,
    v_fifo_trk                         pm.fifo_trk%TYPE,
    n_spc                              pm.spc%TYPE,
    n_case_cube                        pm.case_cube%TYPE,
    n_case_length                      pm.case_length%TYPE,
    n_case_width                       pm.case_width%TYPE,
    n_case_height                      pm.case_height%TYPE,
    n_stackable                        pm.stackable%TYPE,
    n_pallet_stack                     pm.pallet_type%TYPE,
    n_max_slot                         pm.max_slot%TYPE,
    v_max_slot_flag                    pm.max_slot_per%TYPE,
    v_abc                              pm.abc%TYPE,
    v_zone_id                          pm.zone_id%TYPE,
    v_temp_trk                         pm.temp_trk%TYPE,
    v_exp_date_trk                     pm.exp_date_trk%TYPE,
    v_catch_wt_trk                     pm.catch_wt_trk%TYPE,
    v_cool_trk                         VARCHAR2(1),   -- COOL trk item, Y or N.
    v_date_code                        pm.mfg_date_trk%TYPE,
    v_last_ship_slot                   pm.last_ship_slot%TYPE,
    v_area                             pm.area%TYPE,
    v_category                         pm.category%TYPE,
    n_pallet_cube                      pallet_type.cube%TYPE,
    n_skid_cube                        pallet_type.skid_cube%TYPE,
    n_skid_height                      pallet_type.skid_height%TYPE,
    n_last_pik_height                  loc.slot_height%TYPE,
    n_last_pik_width_positions         loc.width_positions%TYPE,
    n_last_pik_deep_positions          slot_type.deep_positions%TYPE,
    v_last_pik_slot_type               loc.slot_type%TYPE,
    n_last_put_aisle1                  loc.put_aisle%TYPE,
    n_last_put_slot1                   loc.put_slot%TYPE,
    n_last_put_level1                  loc.put_level%TYPE,
    n_num_next_zones                   swms_areas.num_next_zones%TYPE,
    n_min_qty                          pm.min_qty%TYPE,
    n_max_qty                          pm.max_qty%TYPE,
    v_fp_flag                     pallet_type.putaway_fp_prompt_for_hst_qty%TYPE,
    v_pp_flag                     pallet_type.putaway_pp_prompt_for_hst_qty%TYPE,
    v_threshold_flag                   pallet_type.putaway_use_repl_threshold%TYPE,
    v_ext_case_cube_flag               pallet_type.ext_case_cube_flag%TYPE,
    --
    -- 02/05/06 Fields for WAI.
    n_rule_id                          zone.rule_id%TYPE,  -- Rule id of pm.zone_id
    v_split_zone_id                    pm.split_zone_id%TYPE,
    n_split_zone_rule_id               zone.rule_id%TYPE,  -- Rule id of
                                                           -- split_zone_id.
    v_auto_ship_flag                   pm.auto_ship_flag%TYPE,
    v_miniload_storage_ind             pm.miniload_storage_ind%TYPE,
    v_case_induction_loc               loc.logi_loc%TYPE,
    v_split_induction_loc              loc.logi_loc%TYPE,
    n_mfr_shelf_life                   pm.mfr_shelf_life%TYPE,
    v_mx_item_assign_flag              pm.mx_item_assign_flag%TYPE,  -- VR added
    aging_days                         aging_items.aging_days%TYPE,
    mx_eligible                        pm.mx_eligible%TYPE,
    mx_case_msku_induction_loc         loc.logi_loc%TYPE
  );

  TYPE t_loc_info IS RECORD
  (
   v_logi_loc                loc.logi_loc%TYPE,
   v_status                loc.status%TYPE,
   v_pallet_type            loc.pallet_type%TYPE,
   n_rank                loc.rank%TYPE,
   n_uom                loc.uom%TYPE,
   v_loc_ref                VARCHAR2(1),
   v_loc_type                VARCHAR2(1),
   n_pik_aisle                loc.pik_aisle%TYPE,
   n_pik_slot                loc.pik_slot%TYPE,
   n_pik_level                loc.pik_level%TYPE,
   n_put_aisle                loc.put_aisle%TYPE,
   n_put_slot                loc.put_slot%TYPE,
   n_put_level                loc.put_level%TYPE,
   n_cube                loc.cube%TYPE,
   v_prod_id                loc.prod_id%TYPE,
   v_cust_pref_vendor            loc.cust_pref_vendor%TYPE,
   v_slot_type                loc.slot_type%TYPE,
   n_available_height            loc.available_height%TYPE,
   v_deep_ind                slot_type.deep_ind%TYPE,
   n_deep_positions            slot_type.deep_positions%TYPE,
   v_zone_id                lzone.zone_id%TYPE
  );



   ---------------------------------------------------------------------
   -- Item record used to store the item when the case height of an
   -- item changes, the item has inventory and putaway is by inches.
   ---------------------------------------------------------------------
   TYPE t_r_item_info_for_inches IS RECORD
   (
      prod_id           pm.prod_id%TYPE,
      cust_pref_vendor  pm.cust_pref_vendor%TYPE
   );




  ---------------------------------
  -- Array declarations
  ---------------------------------
  TYPE t_phys_loc   IS TABLE OF loc.logi_loc%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_loc_height IS TABLE OF loc.slot_height%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_put_aisle2 IS TABLE OF loc.put_aisle%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_put_slot2  IS TABLE OF loc.put_slot%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_put_level2 IS TABLE OF loc.put_level%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_put_path2  IS TABLE OF loc.put_path%TYPE INDEX BY BINARY_INTEGER;
  TYPE t_pallet_id  IS TABLE OF putawaylst.pallet_id%TYPE INDEX BY BINARY_INTEGER;

   TYPE t_r_item_info_for_inches_tbl IS TABLE OF t_r_item_info_for_inches
      INDEX BY BINARY_INTEGER;


  --global array
  gtbl_pallet_id   t_pallet_id;

  TYPE t_work_var IS RECORD
  (
   n_total_qty                       erd.qty%TYPE,
   n_erm_line_id                     erd_lpn.erm_line_id%TYPE,
   n_each_pallet_qty                 NUMBER(10,4),
   n_last_pallet_qty                 NUMBER(10,4),
   n_slot_cnt                        NUMBER,
   n_home_loc_height                 loc.slot_height%TYPE,--this will be
                                                --slot_height*width_positions
                                                -- *deep_positions
   n_home_slot_height                loc.slot_height%TYPE,--this will be
                                                --slot_height*width_positions
                                                --*deep_positions
   n_height                          loc.slot_height%TYPE,--this will have
                                                --only the home slot height
   b_home_slot_flag                   BOOLEAN,
   b_first_home_assign                BOOLEAN,
   b_revisit_open_slot                BOOLEAN,
   n_std_pallet_height                NUMBER(10,4),
   n_height_used                      NUMBER(10,4),
   n_lst_pallet_height                NUMBER(10,4),
   n_put_slot1                        loc.put_slot%TYPE,
   n_put_aisle1                       loc.put_aisle%TYPE,
   n_put_level1                       loc.put_level%TYPE,
   n_put_path1                        loc.put_path%TYPE,
   gtbl_phys_loc                      t_phys_loc,  --array for storing locations
   gtbl_loc_height                    t_loc_height,
   n_pheight                          NUMBER,
   gtbl_put_path2                     t_put_path2,
   gtbl_put_slot2                     t_put_slot2,
   gtbl_put_aisle2                    t_put_aisle2,
   gtbl_put_level2                    t_put_level2,
   n_put_slot_type2                   NUMBER,
   n_put_deep_ind2                    NUMBER,
   n_put_deep_factor2                 NUMBER,
   n_last_put_slot1                   NUMBER,
   n_last_put_aisle1                  NUMBER,
   n_last_put_level1                  NUMBER,
   v_split_dest_loc                   loc.logi_loc%TYPE,
   v_dest_loc                         loc.logi_loc%TYPE,--this will be used in fn
                                                        --2d3d for case items
   v_split_pallet_id                  putawaylst.pallet_id%TYPE,
   v_pallet_id                        putawaylst.pallet_id%TYPE,
   v_deep_ind                         slot_type.deep_ind%TYPE,
   n_pallet_count                     NUMBER,
   n_seq_no                           NUMBER,
   n_num_pallets                      NUMBER,
   n_current_pallet                   NUMBER,
   b_partial_pallet                   BOOLEAN,
   v_no_splits                        pm.spc%TYPE,
   v_slot_type                        slot_type.slot_type%TYPE,
   n_total_cnt                        NUMBER,
   n_home_width_positions             loc.width_positions%TYPE,
   n_home_deep_positions              slot_type.deep_positions%TYPE,
   /*DN:11309 changes*/
   v_exp_date                         erd_lpn.exp_date%TYPE,
   v_lot_id                           erd_lpn.lot_id%TYPE,
   /*END DN:11309 changes*/
   v_dmg_ind                          VARCHAR2(3) := 'AVL' --acppzp this is for
                                                 --indicating damaged pallet
  );


   ---------------------------------------------------------------------------
   -- More Global Variables
   -- Declared here because they use types defined above.
   --------------------------------------------------------------------------
   g_r_item_info_for_inches_tbl   t_r_item_info_for_inches_tbl;


    ---------------------------------------------------------------------------
   -- Procedure Declarations
    ---------------------------------------------------------------------------

   PROCEDURE p_get_syspar(io_p_syspar   IN OUT   t_syspar_var,
                          i_erm_id      IN     erm.erm_id%TYPE);

   PROCEDURE p_insert_table
             ( i_prod_id              IN      pm.prod_id%TYPE,
               i_cust_pref_vendor     IN      pm.cust_pref_vendor%TYPE,
               i_dest_loc             IN      loc.logi_loc%TYPE,
               i_home                 IN      INTEGER,
               i_erm_id               IN      erm.erm_id%TYPE,
               i_aging_days           IN      aging_items.aging_days%TYPE,
               i_clam_bed_flag        IN      sys_config.config_flag_val%TYPE,
               io_item_related_info   IN      t_item_related_info,
               io_workvar_rec         IN OUT  t_work_var);

   PROCEDURE p_get_item_info
                (i_product_id             IN     pm.prod_id%TYPE,
                 i_cust_pref_vendor       IN     pm.cust_pref_vendor%TYPE,
                 io_item_related_info_rec IN OUT t_item_related_info);

  PROCEDURE p_get_erm_info
                 ( i_erm_id                        IN     erm.erm_id%TYPE,
                   i_product_id                    IN     pm.prod_id%TYPE,
                   i_cust_pref_vendor              IN     pm.cust_pref_vendor%TYPE,
                   io_item_related_info_rec        IN OUT t_item_related_info);


   PROCEDURE p_update_heights
                ( i_locations        IN     pl_putaway_utilities.t_phys_loc,
                  o_status           OUT    NUMBER);

   PROCEDURE p_update_heights_for_item
                (i_prod_id           IN  PM.prod_id%TYPE,
                 i_cust_pref_vendor  IN  pm.cust_pref_vendor%TYPE,
                 o_status            OUT NUMBER);

   PROCEDURE p_update_height_data
             (i_loc    IN  inv.plogi_loc%TYPE,
              o_status OUT NUMBER) ;

   PROCEDURE p_find_xfr_slots
        ( i_whousemove       IN     VARCHAR2 DEFAULT NULL,
                  i_from_loc         IN     inv.logi_loc%TYPE,
                  i_qty              IN     inv.qoh%TYPE,
                  i_num_of_locations IN OUT NUMBER,
                  o_suitable_locations  OUT pl_putaway_utilities.t_phys_loc,
                  o_status              OUT NUMBER );

   PROCEDURE P_DIMENSION_SETUP (o_status OUT NUMBER);

   PROCEDURE P_UPDATE_HEIGHTS(o_status  OUT NUMBER,
                              cp_aisle  IN  VARCHAR);

   PROCEDURE p_compute_height_data
                (i_inv_loc_id     IN inv.plogi_loc%TYPE,
                i_loc             IN loc.logi_loc%TYPE,
                i_perm            IN loc.perm%TYPE,
                i_qoh             IN inv.qoh%TYPE,
                i_qty_planned     IN inv.qty_planned%TYPE,
                i_spc             IN pm.spc%TYPE,
                i_ti              IN pm.ti%TYPE,
                i_hi              IN pm.hi%TYPE,
                i_width_positions IN loc.width_positions%TYPE,
                i_deep_positions  IN slot_type.deep_positions%TYPE,
                i_skid_height     IN pallet_type.skid_height%TYPE,
                i_case_height     IN pm.case_height%TYPE,
                o_status          OUT NUMBER);

  Procedure p_is_loc_zone_restrict(p_loc_id IN LOC.LOGI_LOC%TYPE,
                                  p_zone_id OUT  Zone.Zone_id%TYPE,
                                  p_restrict_name OUT  swms_maint_lookup.code_name%TYPE);
    ---------------------------------------------------------------------------
    -- Function Declarations
    ---------------------------------------------------------------------------



   FUNCTION f_get_num_next_zones(i_area in pm.area%TYPE)
   RETURN NUMBER;

   FUNCTION f_is_clam_bed_tracked_item
            (i_pm_category             IN  pm.category%TYPE,
             i_clam_bed_tracked_flag   IN  VARCHAR2)
   RETURN BOOLEAN;

   FUNCTION f_is_clam_bed2_tracked_item
            (i_pm_category             IN  pm.category%TYPE)
   RETURN BOOLEAN;

   FUNCTION f_is_tti_tracked_item
            (i_prod_id           IN  pm.prod_id%TYPE,
             i_cpv               IN  pm.cust_pref_vendor%TYPE,
             i_hazardous     IN  pm.hazardous%TYPE DEFAULT NULL)
   RETURN BOOLEAN;

   FUNCTION f_is_tti_tracked_item2
            (i_hazardous     IN  pm.hazardous%TYPE)
   RETURN BOOLEAN;

   FUNCTION f_is_cool_tracked_item
            (i_prod_id           IN  pm.prod_id%TYPE,
             i_cpv               IN  pm.cust_pref_vendor%TYPE,
             i_category         IN  pm.category%TYPE DEFAULT NULL)
   RETURN BOOLEAN;

   FUNCTION f_retrieve_aging_items
            ( i_product_id                IN  pm.prod_id%TYPE,
              i_cust_pref_vendor IN  pm.cust_pref_vendor%TYPE)
   RETURN NUMBER;

   FUNCTION f_check_home_item(i_item_related_info_rec      IN OUT  t_item_related_info)
   RETURN BOOLEAN;
/***
   FUNCTION F_Check_home_item
           (i_product_id                IN  pm.prod_id%TYPE,
            i_cust_pref_vendor IN  pm.cust_pref_vendor%TYPE,
            i_aging_days                IN  NUMBER,
            i_zone_id                   IN  zone.zone_id%TYPE,
            i_last_ship_slot            IN  pm.last_ship_slot%TYPE)
   RETURN BOOLEAN;
***/
     /*
   ** acppsp:DN#11974: Added the extra parameter task_id for DMD replenishment processing
   */
   FUNCTION f_get_HST_prompt(
            i_option IN CHAR,
            i_repltype   IN CHAR,
            i2_location IN loc.logi_loc%TYPE,
            i_qty IN NUMBER,
            i_task_id IN NUMBER DEFAULT NULL)
   RETURN VARCHAR2;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_is_pallet_in_pit_location
   -- 
   -- Description:
   --    This function checks to see if this pallet is in a PIT location
   --    (a location in a zone with rule 11) and returns Y or N.
   ---------------------------------------------------------------------------
   FUNCTION f_is_pallet_in_pit_location (i_pallet_id IN putawaylst.pallet_id%TYPE)
   RETURN CHAR;

   ---------------------------------------------------------------------------
   -- Function:
   --    f_check_pit_location
   -- 
   -- Description:
   --    This function checks to see if the location is in a pit zone
   ---------------------------------------------------------------------------
   FUNCTION f_check_pit_location (i_location IN loc.logi_loc%TYPE)
   RETURN CHAR;

END pl_putaway_utilities;
/


PROMPT Creating package body PL_PUTAWAY_UTILITIES...
CREATE OR REPLACE PACKAGE BODY SWMS.pl_putaway_utilities
AS
   --  sccs_id=@(#) src/schema/plsql/pl_putaway_utilities.sql, swms, swms.9, 11.2 1/28/10 1.26

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_putaway_utilities';  -- Package name.
                                            --  Used in error messages.

---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------

--
-- This cursor selects the slot(s) an item exists in.
--
CURSOR c_loc_for_item(cp_prod_id           pm.prod_id%TYPE,
                      cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE) IS
   SELECT DISTINCT(plogi_loc) loc
     FROM inv
    WHERE prod_id          = cp_prod_id
      AND cust_pref_vendor = cp_cust_pref_vendor
    ORDER BY plogi_loc;


--
-- This cursors is used when calculating the pallet and slot heights.
-- It selects info about the slot and the items in the slot.
--
CURSOR c_loc_item_info_by_loc(cp_locs VARCHAR2) IS
         SELECT i.logi_loc                 inv_loc_id,
                l.logi_loc                 loc,
                i.qoh                      qoh,
                i.qty_planned              qty_planned,
                NVL(pt.skid_height, 0)     skid_height,
                l.perm                     perm,
                NVL(l.slot_height,0)       slot_height,
                NVL(l.true_slot_height,0)  true_slot_height,
                NVL(st.deep_positions,1)   deep_positions,
                NVL(l.width_positions,1)   width_positions,
                p.prod_id                  prod_id,
                p.cust_pref_vendor         cust_pref_vendor,
                NVL(p.case_height,0)       case_height,
                NVL(p.ti,0)                ti,
                NVL(p.hi,0)                hi,
                NVL(p.spc, 1)              spc
           FROM pallet_type pt,
                loc l,
                slot_type st,
                inv i,
                pm p
          WHERE l.logi_loc              = cp_locs
            AND i.plogi_loc (+)         = l.logi_loc
            AND p.prod_id (+)           = i.prod_id
            AND p.cust_pref_vendor (+)  = i.cust_pref_vendor
            AND pt.pallet_type          = l.pallet_type
            AND st.slot_type            = l.slot_type
          ORDER BY plogi_loc;


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------
--
-- This type is used when re-calculating the heights when putaway is by
-- inches and the case height is changed.
--
TYPE t_r_loc_item_info_by_loc_table IS TABLE OF c_loc_item_info_by_loc%ROWTYPE
       INDEX BY BINARY_INTEGER;


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- End Private Modules
---------------------------------------------------------------------------




---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------


/*-----------------------------------------------------------------------
-- Procedure
--    p_get_syspar
--
-- Description:
-- This procedure selects the value of a syspar.
--
-- Parameters:
--    Out Parameter
--    io_p_syspar  -        Record type instance which will have all the
--                          required values
--    from SYS_CONFIG table.
--
-- Exceptions raised:
--
---------------------------------------------------------------------*/
PROCEDURE p_get_syspar(io_p_syspar IN OUT T_SYSPAR_VAR,
                       i_erm_id      IN     erm.erm_id%TYPE)
IS

lv_msg_text       VARCHAR2(500);
lv_fname          VARCHAR2(50)  := 'p_get_syspar';
lv_error_text     VARCHAR2(500);
e_flag_null       EXCEPTION;
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This variable will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   io_p_syspar.v_allow_flag := pl_common.f_get_syspar('HOME_PUTAWAY');
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   IF io_p_syspar.v_allow_flag IS NOT NULL THEN
   --log the success message

      lv_msg_text := 'Value of HOME_PUTAWAY flag is :'
                    || io_p_syspar.v_allow_flag;
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,null,sqlerrm);
   ELSIF io_p_syspar.v_allow_flag IS NULL THEN

      lv_msg_text := 'TABLE=SYS_CONFIG KEY= HOME_PUTAWAY ACTION= SELECT ' ||
                 'MESSAGE= ORACLE failed to select HOME PUTAWAY';
      pl_log.ins_msg('WARN',lv_fname,lv_msg_text,null,sqlerrm);


      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                                     || i_erm_id;
      pl_putaway_utilities.
      gv_crt_message := RPAD(pl_putaway_utilities.gv_crt_message,80)
                        || 'REASON: Unable to select'
                        || ' HOME_PUTAWAY from syspar';

      RAISE e_flag_null;

    END IF;


   io_p_syspar.v_pallet_type_flag := pl_common.f_get_syspar('PALLET_TYPE_FLAG');

   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';

   IF io_p_syspar.v_pallet_type_flag IS NOT NULL THEN
   --log the success message

      lv_msg_text := 'Value of PALLET_TYPE flag is :'
                    || io_p_syspar.v_pallet_type_flag;
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,null,sqlerrm);
   ELSIF io_p_syspar.v_pallet_type_flag IS NULL THEN

      lv_msg_text := 'TABLE=SYS_CONFIG KEY= PALLET_TYPE_FLAG ACTION= SELECT '
                   ||'MESSAGE= ORACLE failed to select PALLET_TYPE_FLAG';
      pl_log.ins_msg('WARN',lv_fname,lv_msg_text,null,sqlerrm);


      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                               || i_erm_id;
      pl_putaway_utilities.
      gv_crt_message := RPAD(pl_putaway_utilities.gv_crt_message,80)
                  || 'REASON: Unable to select'
                  || ' PALLET_TYPE_FLAG from syspar';

      RAISE e_flag_null;

   END IF;

   --if syspar is not found then default value is Y
   io_p_syspar.v_g_mix_same_prod_deep_slot := pl_common.f_get_syspar
                                              ('MIX_SAME_PROD_DEEP_SLOT','Y');
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';

   --log the success message
   lv_msg_text := 'Value of MIX_SAME_PROD_DEEP_SLOT flag is :'
                 || io_p_syspar.v_g_mix_same_prod_deep_slot;
   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   io_p_syspar.v_clam_bed_tracked_flag := pl_common.f_get_syspar
                                                  ('CLAM_BED_TRACKED');
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';

   IF io_p_syspar.v_clam_bed_tracked_flag IS NOT NULL THEN
      --log the success message

      lv_msg_text:= 'Value of CLAM_BED_TRACKED flag is :'
                    || io_p_syspar.v_clam_bed_tracked_flag;
      --log the success message
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
   ELSIF io_p_syspar.v_clam_bed_tracked_flag IS NULL THEN


      lv_msg_text := 'TABLE=SYS_CONFIG KEY= CLAM_BED_TRACKED FLAG '
                     ||' ACTION= SELECT '
                     ||'MESSAGE= ORACLE failed to select CLAM_BED_TRACKED flag';
      pl_log.ins_msg('WARN',lv_fname,lv_msg_text,null,sqlerrm);


      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                               || i_erm_id;
      pl_putaway_utilities.
      gv_crt_message := RPAD(pl_putaway_utilities.gv_crt_message,80)
                  || 'REASON: Unable to select'
                  || ' CLAM_BED_TRACKED from syspar';

      RAISE e_flag_null;

   END IF;

   io_p_syspar.v_mix_prod_2d3d_flag := pl_common.f_get_syspar
                                           ('MIXPROD_2D3D_FLAG');
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';

   IF io_p_syspar.v_mix_prod_2d3d_flag IS NOT NULL THEN
      --log the success message

      lv_msg_text:= 'Value of MIXPROD_2D3D_FLAG flag is :'
                             || io_p_syspar.v_mix_prod_2d3d_flag;

      --log the success message
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   ELSIF io_p_syspar.v_mix_prod_2d3d_flag IS NULL THEN


      lv_msg_text := 'TABLE=SYS_CONFIG KEY= MIXPROD_2D3D_FLAG ACTION= SELECT '
                        ||'MESSAGE= ORACLE failed to select MIXPROD_2D3D_FLAG';
      pl_log.ins_msg('WARN',lv_fname,lv_msg_text,null,sqlerrm);


      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
                                             || i_erm_id;
      pl_putaway_utilities.
      gv_crt_message := RPAD(pl_putaway_utilities.gv_crt_message,80)
                        || 'REASON: Unable to select'
                        || ' MIXPROD_2D3D_FLAG from syspar';
      RAISE e_flag_null;

   END IF;



   io_p_syspar.v_mix_prod_bulk_area := pl_common.f_get_syspar
                                                ('MIX_PROD_BULK_AREA','N');
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';

   lv_msg_text := 'Value of MIX_PROD_BULK_AREA flag is :'
                                       || io_p_syspar.v_mix_prod_bulk_area;
   --log the success message
   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);


EXCEPTION
 WHEN e_flag_null THEN
   --ROLLBACK IN THE MAIN PACKAGE
   RAISE;
 WHEN OTHERS THEN
   lv_msg_text := 'ERROR in main exception block ' || sqlcode || sqlerrm;
   --log the failure mesasge here
   pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);

   --rollback everything in the main function.
   RAISE; /* this raises the same exception and goes to calling block*/
END p_get_syspar;
----------------------------------------------------------------------------
/*   -----------------------------------------------------------------------
    -- Function:
    --    f_get_num_next_zones
    --
    -- Description:
    -- This method gets number of next zones attempts allowed for area.
    --
    -- Parameters:
    --    i_area -              Area Code
    --
    --
    -- Return Values:
    --    Value of the num_next_zones allowed for that area.
    --    In case the num_next_zones are
          not found 0 is returned
    -- Exceptions raised:
    --
   ---------------------------------------------------------------------*/

 FUNCTION f_get_num_next_zones(i_area IN pm.area%TYPE)
 RETURN NUMBER
 IS

   lt_num_next_zones swms_areas.num_next_zones%TYPE;
   lv_msg_text       VARCHAR2(500);
   lv_fname          VARCHAR2(50)  := 'f_get_num_next_zones';

BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

  --pick num of zones for particular area
   SELECT NVL(num_next_zones, 0) INTO lt_num_next_zones
     FROM swms_areas
    WHERE area_code = i_area;


   lv_msg_text := 'Number of next zones for area ' || i_area || ': '
                 || lt_num_next_zones;
   --log the message

   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
   RETURN lt_num_next_zones;

   EXCEPTION
     WHEN NO_DATA_FOUND THEN
      lt_num_next_zones := 0;

      lv_msg_text := 'ORACLE: Unable to get num_next_zones for items area';
       --log the message

      pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
      RETURN lt_num_next_zones;

END f_get_num_next_zones;
------------------------------------------------------------------------------
/*-----------------------------------------------------------------------
   -- Function:
   --     f_is_tti_tracked_item
   --
   -- Description:
   --
   -- Parameters:
   --    i_prod_id
   --    i_cpv
   --    i_hazardous - Input hazardous code if available. If no input or
   --        NULL, the PM.hazardous value is used.
   --
   -- Return Values:
   --    TRUE    The item is a tti tracked item
   --    FALSE   The item is not a tti tracked item
   --
   -- Exceptions raised:
   --
---------------------------------------------------------------------*/
FUNCTION f_is_tti_tracked_item(i_prod_id   IN pm.prod_id%TYPE,
                               i_cpv       IN pm.cust_pref_vendor%TYPE,
                   i_hazardous IN pm.hazardous%TYPE DEFAULT NULL)
RETURN BOOLEAN IS
   lv_fname            VARCHAR2(30) := 'f_is_tti_tracked_item';
   lv_message          VARCHAR2(256);  -- Message buffer

   lv_work_area        VARCHAR2(1);  -- Work area
   lb_return_value     BOOLEAN;      -- Return value

   CURSOR c_tti_trk(cp_prod_id           pm.prod_id%TYPE,
                    cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE) IS
      SELECT 'x'
        FROM haccp_codes h, pm
       WHERE h.haccp_code        = NVL(i_hazardous, pm.hazardous)
         AND h.haccp_type        = 'H'
         AND h.tti_trk           = 'Y'
         AND pm.prod_id          = cp_prod_id
         AND pm.cust_pref_vendor = cp_cust_pref_vendor;
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   OPEN c_tti_trk(i_prod_id, i_cpv);
   FETCH c_tti_trk INTO lv_work_area;

   IF (c_tti_trk%FOUND) THEN
      lb_return_value := TRUE;
   ELSE
      lb_return_value := FALSE;
   END IF;

   CLOSE c_tti_trk;

   RETURN(lb_return_value);
EXCEPTION
   WHEN OTHERS THEN
      lv_message := 'TABLE=pm,haccp_codes  KEY=[' || i_prod_id || ',' ||
            i_cpv || '](i_prod_id,i_cpv)  ACTION=SELECT  MESSAGE=Checking' ||
            ' if TTI item failed.  Will process item as not TTI tracked.';

      pl_log.ins_msg(pl_lmc.ct_warn_msg, lv_fname, lv_message,
                        SQLCODE, SQLERRM);
      RETURN(FALSE);

END f_is_tti_tracked_item;

/*-----------------------------------------------------------------------
   -- Function:
   --     f_is_tti_tracked_item2
   --
   -- Description:
   --
   -- Parameters:
   --    i_hazardous - Input hazardous code.
   --
   -- Return Values:
   --    TRUE    The item is a tti tracked item
   --    FALSE   The item is not a tti tracked item
   --
   -- Exceptions raised:
   --
---------------------------------------------------------------------*/
FUNCTION f_is_tti_tracked_item2(i_hazardous IN pm.hazardous%TYPE)
RETURN BOOLEAN IS
   lv_fname            VARCHAR2(30) := 'f_is_tti_tracked_item2';
   lv_message          VARCHAR2(256);  -- Message buffer

   lv_work_area        VARCHAR2(1);  -- Work area
   lb_return_value     BOOLEAN;      -- Return value

   CURSOR c_tti_trk2 IS
      SELECT 'x'
        FROM haccp_codes h
       WHERE h.haccp_code        = i_hazardous
         AND h.haccp_type        = 'H'
         AND h.tti_trk           = 'Y'
         AND ROWNUM = 1;
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   OPEN c_tti_trk2;
   FETCH c_tti_trk2 INTO lv_work_area;

   IF (c_tti_trk2%FOUND) THEN
      lb_return_value := TRUE;
   ELSE
      lb_return_value := FALSE;
   END IF;

   CLOSE c_tti_trk2;

   RETURN(lb_return_value);
EXCEPTION
   WHEN OTHERS THEN
      lv_message := 'TABLE=haccp_codes  KEY=[' || i_hazardous ||
            '](i_hazardous)  ACTION=SELECT  MESSAGE=Checking' ||
            ' if TTI item failed.  Will process item as not TTI tracked.';

      pl_log.ins_msg(pl_lmc.ct_warn_msg, lv_fname, lv_message,
                        SQLCODE, SQLERRM);
      RETURN(FALSE);

END f_is_tti_tracked_item2;


------------------------------------------------------------------------------
/*-----------------------------------------------------------------------
-- Function:
--     f_is_clam_bed_tracked_item
--
-- Description:
-- This function checks if the current processing item is a clam bed
-- tracked item through the inspection of the syspar CLAM_BED_TRACKED
-- flag and the item category value.
--
-- Parameters:
--    i_pm_category                - Item category
--    i_clam_bed_tracked_flag      - Value to use for
--                                    the syspar CLAM_BED_TRTACKED
--
-- Return Values:
--    TRUE    The item is a clam bed tracked item
--    FALSE   The item is not a clam bed tracked item
--
-- Exceptions raised:
--    pl_exc.e_database_error  - A database error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/17/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
--                      Changed to use a cursor instead of select distinct.
--                      The cursor is a little faster.
--    09/20/05 prpbcb   Fixed logic error than basically ignored the value
--                      is i_clam_bed_tracked_flag.
---------------------------------------------------------------------*/
FUNCTION f_is_clam_bed_tracked_item
                        (i_pm_category           IN pm.category%TYPE,
                         i_clam_bed_tracked_flag IN VARCHAR2)
RETURN BOOLEAN IS

   lt_category_value   haccp_codes.haccp_code%TYPE;
   lv_fname            VARCHAR2(50):='f_is_clam_bed_tracked_item';
   lv_message          VARCHAR2(256);  -- Message buffer

   l_return_value      BOOLEAN;

   CURSOR c_clam_bed(cp_category pm.category%TYPE) IS
      SELECT haccp_code
        FROM haccp_codes
       WHERE haccp_code = cp_category
         AND haccp_type = 'C';

BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   IF i_clam_bed_tracked_flag = 'N' OR i_clam_bed_tracked_flag IS NULL THEN
      l_return_value := FALSE;
   ELSE
      OPEN c_clam_bed(i_pm_category);
      FETCH c_clam_bed INTO lt_category_value;

      IF (c_clam_bed%FOUND) THEN
         l_return_value := TRUE;
      ELSE
         l_return_value := FALSE;
      END IF;

      CLOSE c_clam_bed;
   END IF;

   RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         lv_message := 'TABLE=haccp_codes  KEY=[' || i_pm_category || ',' ||
            i_clam_bed_tracked_flag || ']' ||
           '(i_pm_category,i_clam_bed_tracked_flag)' ||
           '  ACTION=SELECT  MESSAGE=Checking' ||
           ' if clam bed tracked item failed.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, lv_fname, lv_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 lv_message || ': ' || SQLERRM);

END f_is_clam_bed_tracked_item;

------------------------------------------------------------------------------
/*-----------------------------------------------------------------------
-- Function:
--     f_is_clam_bed2_tracked_item
--
-- Description:
-- This function checks if the current processing item is a clam bed
-- tracked item through the inspection of the syspar CLAM_BED_TRACKED
-- flag and the item category value.
--
-- Parameters:
--    i_pm_category                - Item category
--
-- Return Values:
--    TRUE    The item is a clam bed tracked item
--    FALSE   The item is not a clam bed tracked item
--
-- Exceptions raised:
--    pl_exc.e_database_error  - A database error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--
---------------------------------------------------------------------*/
FUNCTION f_is_clam_bed2_tracked_item
                        (i_pm_category           IN pm.category%TYPE)
RETURN BOOLEAN IS

   lt_category_value   haccp_codes.haccp_code%TYPE;
   lv_fname            VARCHAR2(50):='f_is_clam_bed2_tracked_item';
   lv_message          VARCHAR2(256);  -- Message buffer

   l_return_value      BOOLEAN;
   l_syspar           sys_config.config_flag_val%TYPE := NULL;

   CURSOR c_clam_bed(cp_category pm.category%TYPE) IS
      SELECT haccp_code
        FROM haccp_codes
       WHERE haccp_code = cp_category
         AND haccp_type = 'C';

BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   l_syspar := pl_common.f_get_syspar('CLAM_BED_TRACKED', 'N');

   IF l_syspar = 'N' OR l_syspar IS NULL THEN
      l_return_value := FALSE;
   ELSE
      OPEN c_clam_bed(i_pm_category);
      FETCH c_clam_bed INTO lt_category_value;

      IF (c_clam_bed%FOUND) THEN
         l_return_value := TRUE;
      ELSE
         l_return_value := FALSE;
      END IF;

      CLOSE c_clam_bed;
   END IF;

   RETURN(l_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         lv_message := 'TABLE=haccp_codes  KEY=[' || i_pm_category || ',' ||
            l_syspar || ']' ||
           '(i_pm_category,l_syspar)' ||
           '  ACTION=SELECT  MESSAGE=Checking' ||
           ' if clam bed tracked item failed.';

         pl_log.ins_msg(pl_lmc.ct_fatal_msg, lv_fname, lv_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 lv_message || ': ' || SQLERRM);

END f_is_clam_bed2_tracked_item;


-------------------------------------------------------------------------
-- Function:
--    f_is_cool_tracked_item
--
-- Description:
--     This function determines if an item is cool tracked and returns TRUE
--     if it is otherwise FALSE.  If an oracle error occurs then an aplog
--     message is written to the log table and FALSE is returned.
--
-- Parameters:
--    i_prod_id  - The item to check if COOL tracked.
--    i_cpv      - Customer preferred vendor for the item.
--    i_category - Input category if available. If no input or NULL, the
--           PM.category value is used.
--
-- Return Values:
--    TRUE   - The item is a COOL tracked item.
--    FALSE  - The item is not COOL tracked item.
--
-- Called by:
--
-- Exceptions raised:
--    None.  If an error occurs then a message is written to the log
--    table and processing continues.  FALSE will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/22/05 prpbcb   Created as part of the COOL changes.
-------------------------------------------------------------------------
FUNCTION f_is_cool_tracked_item(i_prod_id   IN pm.prod_id%TYPE,
                                i_cpv       IN pm.cust_pref_vendor%TYPE,
                i_category  IN pm.category%TYPE DEFAULT NULL)
RETURN BOOLEAN IS
   lv_fname            VARCHAR2(30) := 'f_is_cool_tracked_item';
   lv_message          VARCHAR2(256);  -- Message buffer

   lv_work_area        VARCHAR2(1);  -- Work area
   lb_return_value     BOOLEAN;      -- Return value

   CURSOR c_cool_trk(cp_prod_id           pm.prod_id%TYPE,
                     cp_cust_pref_vendor  pm.cust_pref_vendor%TYPE) IS
      SELECT 'x'
        FROM haccp_codes h, pm p, cool_category cc
       WHERE h.haccp_code        = NVL(i_category, p.category)
         AND h.haccp_type        = 'O'
     AND h.cool_trk        = 'Y'
     AND ((cc.item_trk = 'N') OR
         ((cc.item_trk = 'Y') AND
          (p.prod_id, p.cust_pref_vendor) IN
        (SELECT prod_id, cust_pref_vendor FROM cool_item_master)))
     AND substr(p.category,1,2) = cc.category
         AND p.prod_id          = cp_prod_id
         AND p.cust_pref_vendor = cp_cust_pref_vendor;
BEGIN
   -- Reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   -- This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   OPEN c_cool_trk(i_prod_id, i_cpv);
   FETCH c_cool_trk INTO lv_work_area;

   IF (c_cool_trk%FOUND) THEN
      lb_return_value := TRUE;
   ELSE
      lb_return_value := FALSE;
   END IF;

   CLOSE c_cool_trk;

   RETURN(lb_return_value);

   EXCEPTION
      WHEN OTHERS THEN
         lv_message := 'TABLE=pm,haccp_codes  KEY=[' || i_prod_id || ',' ||
            i_cpv || '](i_prod_id,i_cpv)  ACTION=SELECT  MESSAGE=Checking' ||
            ' if COOL item failed.  Will process item as not COOL tracked.';

         pl_log.ins_msg(pl_lmc.ct_warn_msg, lv_fname, lv_message,
                        SQLCODE, SQLERRM);
         RETURN(FALSE);

END f_is_cool_tracked_item;

------------------------------------------------------------------------------

/* -----------------------------------------------------------------------
   -- Function:
   --    p_insert_table
   --
   -- Description:
   -- This function inserts into INV and PUTAWAYLST table.
   --
   -- Parameters:
               i_prod_id                 Item code
               i_cust_pref_vendor        Customer preferred vendor
               i_dest_loc                Destination location for the pallet
               i_home                    Flag to indicate location
                                         i.e. HOME SLOT
                                         or RESERVE SLOT
               i_erm_id                  Purchase Order no
               i_aging_days              No of aging days for the item.
               i_clam_bed_flag           Syspar Flag
               io_item_related_info      Record type which has all
                                         the item related info
               io_workvar_rec            Record type which has
                                         parameters calculated in the program
   --
   -- Return Values:
   --
   --
   -- Exceptions raised:
   --
-------------------------------------------------------------------------------------------------*/
PROCEDURE p_insert_table
                ( i_prod_id            IN      pm.prod_id%TYPE,
                  i_cust_pref_vendor   IN      pm.cust_pref_vendor%TYPE,
                  i_dest_loc           IN      loc.logi_loc%TYPE,
                  i_home               IN      INTEGER,
                  i_erm_id             IN      erm.erm_id%TYPE,
                  i_aging_days         IN      aging_items.aging_days%TYPE,
                  i_clam_bed_flag      IN      sys_config.config_flag_val%TYPE,
                  io_item_related_info IN      t_item_related_info,
                  io_workvar_rec       IN OUT  t_work_var)
IS

   lt_pallet_id        putawaylst.pallet_id%TYPE :='';
   lt_catch_weight        erd_lpn.catch_weight%TYPE :='';
   lt_lot_id              erd_lpn.lot_id%TYPE :='';
   lt_exp_date            erd_lpn.exp_date%TYPE := SYSDATE;
   lt_mfg_date            erd_lpn.mfg_date%TYPE := SYSDATE;
   lt_parent_pallet_id putawaylst.parent_pallet_id%TYPE := ''; /*D#11309 MSKU Changes*/
   lt_erm_type             erm.erm_type%TYPE :='';
   lt_erm_line_id          erd_lpn.erm_line_id%TYPE :='';
   lt_seq_no               putawaylst.seq_no%TYPE :='';
   lt_po_line_id            erd_lpn.po_line_id%TYPE :='';
   lt_rdc_po                erd_lpn.po_no%TYPE :='';
   lt_qty                   erd_lpn.qty%TYPE :=0;
   lt_item_related_info     t_item_related_info;
   ln_status           NUMBER := 0;
   lv_clam_bed_trk     VARCHAR2(1);
   lv_msg_text         VARCHAR2(500);
   lv_pname            VARCHAR2(50)  := 'p_insert_table';
   lv_tmp_check        VARCHAR2(1);
   lv_error_text       VARCHAR2(500);
   lv_flag             VARCHAR2(1);
   lv_rule_id          zone.rule_id%TYPE:=0; /*D#11309 MSKU Changes*/
   test_qty_planned    inv.qty_planned%TYPE :=0;
   test_cube           inv.cube%TYPE :=0;
   l_dummy             NUMBER :=0;
   lv_total_weight      NUMBER :=0;
   lv_total_cases      NUMBER :=0;
   lv_tti_trk          VARCHAR2(1);
   lv_need_exp_date varchar2(1) := 'N'; -- D#12292
                    -- 'N': do not need collect
                    -- 'Y': need to collect exp_date
                    -- 'C': exp_date collection is complete

/*D#11309 MSKU changes*/
   CURSOR c_pallet_id_msku(sn_no VARCHAR2,prod_id VARCHAR2,cust_pref_vendor VARCHAR2,qty NUMBER,pallet_id VARCHAR2) IS
   SELECT parent_pallet_id,catch_weight,erm_line_id,po_no,po_line_id
   FROM erd_lpn
   WHERE sn_no                  = sn_no
   AND   pallet_id              = pallet_id;
/*END D#11309 MSKU changes*/
   e_pallet_id      EXCEPTION;
   e_inv_update     EXCEPTION;


BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_pname;

   --call the procedure to get the unique pallet id

   --acppzp :change for do not print LPN
   --retrieving erm_type to check if it is
   --a PO or a SN
   BEGIN
      SELECT erm_type
      INTO lt_erm_type
      FROM erm
      WHERE erm_id = i_erm_id;
   EXCEPTION
      WHEN  NO_DATA_FOUND THEN

         lv_msg_text:= PROGRAM_CODE ||'Required entry not found for SN '
                       || i_erm_id
                       ||' in erm ';
         pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

         lv_error_text := sqlcode || sqlerrm;

         pl_putaway_utilities.gv_crt_message :=
                            'ERROR:ERM table - for SN/PO= '
                            || i_erm_id ||' select erm_type failed ';
         pl_putaway_utilities.gv_crt_message :=
                     RPAD(pl_putaway_utilities.gv_crt_message,80)
                          ||lv_error_text;
         RAISE;
   END;


   --acppzp OSD changes begin
   --if the damaged indicator is DMG
   --retrieve damaged pallet from putawaylst
   --for that erm_id,prod_id,cpvn,qty and dest_loc is *
  IF io_workvar_rec.v_dmg_ind = 'DMG' THEN


        BEGIN
          SELECT pallet_id
          INTO   lt_pallet_id
          FROM putawaylst
          WHERE rec_id = i_erm_id
          AND   prod_id = i_prod_id
          AND   cust_pref_vendor = i_cust_pref_vendor
          AND   qty = io_workvar_rec.n_each_pallet_qty
          AND   dest_loc = '*'
          AND   status = 'DMG'
          AND   rownum = 1;

        EXCEPTION
          WHEN OTHERS THEN
            lv_msg_text:= PROGRAM_CODE ||'damaged pallet_id not found for SN/PO'||i_erm_id
                      ||' in  putawaylst';
            pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

            lv_error_text := sqlcode || sqlerrm;

            pl_putaway_utilities.gv_crt_message :=
                               'ERROR:PUTAWAYLST table SN/PO= '
                               || i_erm_id
                               || ' Prod Id= ' || i_prod_id
                               || ' CPV = ' || i_cust_pref_vendor
                               || ' Qty= ' || io_workvar_rec.n_each_pallet_qty;

            pl_putaway_utilities.gv_crt_message :=
                        RPAD(pl_putaway_utilities.gv_crt_message,80)
                         ||lv_error_text;
            RAISE;
        END;
  ELSE
   --acppzp OSD changes end

     -- 10/20/09 - ctvgg000 - ASN to all OPCOs project
     -- Include VN to the below condition.

     IF lt_erm_type NOT IN ('SN','VN') OR gb_reprocess = TRUE THEN
         pl_common.p_get_unique_lp(lt_pallet_id, ln_status);
     ELSE
     --acppzp the following SN Receipt

         BEGIN
            BEGIN
              /*D#11309 MSKU changes*/
               SELECT parent_pallet_id
               INTO lt_parent_pallet_id
               FROM erd_lpn
               WHERE pallet_id = io_workvar_rec.v_pallet_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
               lt_parent_pallet_id := NULL;
            WHEN OTHERS THEN
               lv_msg_text:= PROGRAM_CODE
                         || ' Required data not found for MSKU pallet of SN'
                         || i_erm_id
                         || ' in  erd_lpn';
               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :=
                               'ERROR:ERD_LPN table SN= '
                               || i_erm_id
                               || ' Prod Id= ' || i_prod_id
                               || ' CPV = ' || i_cust_pref_vendor
                               || ' Qty= ' || io_workvar_rec.n_each_pallet_qty
                               || ' Pallet Id= ' || lt_pallet_id;
               pl_putaway_utilities.gv_crt_message :=
                 RPAD(pl_putaway_utilities.gv_crt_message,80)
                      ||lv_error_text;
               RAISE;
            END;
           /*END D#11309 MSKU changes*/
            lt_exp_date := io_workvar_rec.v_exp_date;
            lt_lot_id := io_workvar_rec.v_lot_id;

            /*D#11309 MSKU Changes*/
            IF lt_parent_pallet_id IS NOT NULL THEN
               BEGIN
                  SELECT pallet_id,
                         parent_pallet_id,
                         catch_weight,
                         TRUNC(exp_date),
                         TRUNC(mfg_date),
                         lot_id,
                         erm_line_id,
                         po_no,
                         po_line_id
                    INTO
                         lt_pallet_id,
                         lt_parent_pallet_id,
                         lt_catch_weight,
                         lt_exp_date,
                         lt_mfg_date,
                         lt_lot_id,
                         lt_erm_line_id,
                         lt_rdc_po,
                         lt_po_line_id
                    FROM erd_lpn
                   WHERE sn_no        = i_erm_id
                     AND pallet_id    = io_workvar_rec.v_pallet_id;

          /* D#12216 */
          IF (io_item_related_info.v_exp_date_trk = 'N' AND
                      io_item_related_info.v_date_code = 'N') THEN
                     --
                     -- Not a date tracked item.  The expiration date
                     -- will be the current date.  Clear the mfg date in case
                     -- the SN had one.
                     --
                     lt_exp_date := TRUNC(SYSDATE);
                     lt_mfg_date := NULL;
                  ELSIF (io_item_related_info.v_exp_date_trk = 'Y') THEN
                     --
                     -- The item is expiration date tracked.
                     -- Clear the mfg date in case the SN had one.
                     --
                     lt_mfg_date := NULL;

                 -- D#12292 Add the same logic for exp_date as for regular SN pallet.
                     -- The item is exp date tracked on SWMS.
                       -- If the exp date is one of the following force the exp date
                     -- to be collected.
                       --    - The exp date is more than 10 years in the future,
                       --    - The exp date is less than or equal to the current date.
                       --    - The exp date is null.
                       --
                   IF (lt_exp_date IS NULL) OR
                (lt_exp_date > (SYSDATE + 3650)) OR
                (lt_exp_date <= TRUNC(SYSDATE)) THEN
                    --
                    -- Set the exp_date to SYSDATE and force data collection.
                    --
                   lv_need_exp_date := 'Y';
                        lt_exp_date := TRUNC(SYSDATE);
                   ELSE
                    --
                        -- The item is exp date tracked and the exp date on the SN is
                    -- valid.  Flag the exp date as collected.
                    --
               lv_need_exp_date := 'C';
              END IF;
              -- end D#12292

                  ELSIF (io_item_related_info.v_date_code = 'Y') THEN
                     --
                     -- The item is mfg date tracked.
                     -- If the SN has mfg date then calculate the expiration
                     -- date.
                     --
                     IF (lt_mfg_date IS NOT NULL) THEN
                        lt_exp_date := lt_mfg_date +
                                io_item_related_info.n_mfr_shelf_life;
                     ELSE
                        --
                        -- The item is mfg date track but no date was on
                        -- the SN.  Set the expiration date to the current
                        -- date.  The putawaylst insert stmt will set the
                        -- flag to force data collection on the mfg date.
                        --
                        lt_exp_date := TRUNC(SYSDATE);
                     END IF;
          END IF;

               EXCEPTION
                 WHEN  OTHERS THEN
                     lv_msg_text:= PROGRAM_CODE
                             || ' Required data not found for SN'||i_erm_id
                             || ' in  erd_lpn';
                     pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

                     lv_error_text := sqlcode || sqlerrm;

                     pl_putaway_utilities.gv_crt_message :=
                                 'ERROR:ERD_LPN table SN= '
                                 || i_erm_id
                                 || ' Prod Id='|| i_prod_id
                                 || ' CPV =' || i_cust_pref_vendor
                                 || ' Qty=' || io_workvar_rec.n_each_pallet_qty
                                 || ' Pallet Id=' || lt_pallet_id;
                     pl_putaway_utilities.gv_crt_message :=
                       RPAD(pl_putaway_utilities.gv_crt_message,80)
                            ||lv_error_text;
                     RAISE;
               END;
               BEGIN
                /*D#11309 MSKU Changes*/
                  SELECT rule_id
                  INTO lv_rule_id
                  FROM pm, zone z
                  WHERE pm.prod_id = i_prod_id
                  AND pm.zone_id = z.zone_id;
                 /*END D#11309 bMSKU Changes*/
               EXCEPTION
               WHEN OTHERS THEN
                  lv_msg_text:= PROGRAM_CODE
                         || 'zone id not found for product'||i_prod_id;
                  pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

                  lv_error_text := sqlcode || sqlerrm;

                  pl_putaway_utilities.gv_crt_message :=
                                'ERROR:table pm,zone SN= '
                                || i_erm_id
                                || ' Prod Id=' || i_prod_id
                                || ' CPV =' || i_cust_pref_vendor;

                  pl_putaway_utilities.gv_crt_message :=
                                RPAD(pl_putaway_utilities.gv_crt_message,80)
                               ||lv_error_text;
                  /*acpppp-Error should not be raised
          RAISE;*/
               END;

               io_workvar_rec.n_seq_no := io_workvar_rec.n_erm_line_id;
               /*END D#11309 MSKU Changes*/
            ELSE

               BEGIN
                  lt_qty := io_workvar_rec.n_each_pallet_qty * io_item_related_info.n_spc;
                  SELECT pallet_id,parent_pallet_id,lot_id,catch_weight,
                         exp_date,mfg_date,erm_line_id,po_no,po_line_id
                  INTO  lt_pallet_id,lt_parent_pallet_id,lt_lot_id,
                        lt_catch_weight,lt_exp_date,lt_mfg_date,
                        lt_erm_line_id,lt_rdc_po,lt_po_line_id
                  FROM erd_lpn
                  WHERE sn_no                  = i_erm_id
                  AND   prod_id                = i_prod_id
                  AND   cust_pref_vendor       = i_cust_pref_vendor
                  AND   qty                    = lt_qty
                  AND   pallet_assigned_flag   = 'N'
                  AND  rownum = 1;

               EXCEPTION
                  WHEN  OTHERS THEN
                      lv_msg_text:= PROGRAM_CODE
                             ||'Required data not found for SN'||i_erm_id
                             ||' in  erd_lpn';
                      pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

                      lv_error_text := sqlcode || sqlerrm;

                      pl_putaway_utilities.gv_crt_message :=
                                'ERROR:ERD_LPN table SN= '
                                || i_erm_id
                                ||' Prod Id= '|| i_prod_id
                                ||' CPV=' || i_cust_pref_vendor
                                ||' Qty=' || io_workvar_rec.n_each_pallet_qty;

                      pl_putaway_utilities.gv_crt_message :=
                           RPAD(pl_putaway_utilities.gv_crt_message,80)
                            ||lv_error_text;

                      RAISE;
              END;
          -- D#12292 Set exp_date_trk flag for non-MSKU SN pallet.
          lv_need_exp_date := io_item_related_info.v_exp_date_trk;
              io_workvar_rec.n_seq_no := lt_erm_line_id;
            END IF;
         EXCEPTION
           WHEN OTHERS THEN
              lv_msg_text:= PROGRAM_CODE
                    || ' record for pallet_id ' || lt_pallet_id
                    || ' not found for SN ' || i_erm_id
                    || ' in erd_lpn';
              pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

              lv_error_text := sqlcode || sqlerrm;

              pl_putaway_utilities.gv_crt_message :=
                             'ERROR:ERD_LPN table SN='
                             || i_erm_id
                             || ' pallet id=[' || lt_pallet_id
                             || '] select failed';

              pl_putaway_utilities.gv_crt_message :=
                           RPAD(pl_putaway_utilities.gv_crt_message,80)
                           || lv_error_text;
              RAISE;

         END;

    BEGIN
    SELECT SUM(catch_weight), SUM(qty)
    INTO lv_total_weight,lv_total_cases
    FROM erd_lpn
    WHERE prod_id=i_prod_id
    and cust_pref_vendor=i_cust_pref_vendor
    AND sn_no=i_erm_id;

         EXCEPTION
           WHEN OTHERS THEN
              lv_msg_text:= PROGRAM_CODE || 'record for pallet_id'
                   || lt_pallet_id||' not found for SN'
                   || i_erm_id ||' prod_id =' ||i_prod_id ||' cpv='
                   || i_cust_pref_vendor
                   ||' in  erd_lpn';
              pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

              lv_error_text := sqlcode || sqlerrm;

              pl_putaway_utilities.gv_crt_message :=
                             'ERROR:ERD_LPN table SN= '
                             || i_erm_id
                             ||' pallet id= '||lt_pallet_id
                             ||' prod_id =' ||i_prod_id
                             ||' cpv='||i_cust_pref_vendor
                             ||' select failed';

              pl_putaway_utilities.gv_crt_message :=
                           RPAD(pl_putaway_utilities.gv_crt_message,80)
                           || lv_error_text;

              RAISE;

         END;

     --lv_total_cases :=lv_total_cases/io_item_related_info.n_spc;


         BEGIN
            UPDATE erd_lpn
            SET pallet_assigned_flag     = 'Y'
            WHERE pallet_id              = lt_pallet_id;
         EXCEPTION
            WHEN OTHERS THEN

               lv_msg_text := PROGRAM_CODE
                   || 'Updation of pallet_assign_flag in erd_lpn failed'
                   || 'for SN '||i_erm_id||' and pallet_id '||lt_pallet_id;

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :=
                            'ERROR:updation of erd_lpn failed for SN= '
                            || i_erm_id || ' and pallet_id ' || lt_pallet_id;
               pl_putaway_utilities.gv_crt_message :=
                       RPAD(pl_putaway_utilities.gv_crt_message,80)
                            ||lv_error_text;
               RAISE;
         END;
     END IF;

   ----acppzp---change for do not print LPN

  END IF;

  IF ln_status = 0 AND lt_pallet_id IS NOT NULL THEN
      --increment the sequence
      io_workvar_rec.n_seq_no := io_workvar_rec.n_seq_no + 1;

      IF    i_home = ADD_HOME THEN

      --update inv record
         BEGIN
            IF    io_workvar_rec.b_first_home_assign = TRUE THEN
               --first pallet in home loc
               --in this case we have to consider case cube and skid cube

               UPDATE inv
                  SET  qty_planned      = qty_planned +
                                       CEIL((io_workvar_rec.n_each_pallet_qty)
                                         * (io_workvar_rec.v_no_splits)),
                       cube  = DECODE(SIGN(99999.99
                                  - (NVL(cube, 0)
                                     + CEIL(io_workvar_rec.n_each_pallet_qty
                                            * io_item_related_info.n_case_cube)
                                     + io_item_related_info.n_skid_cube)),
                                      -1, 99999.99,
                                     (NVL(cube, 0)
                                      + CEIL(io_workvar_rec.n_each_pallet_qty
                                             * io_item_related_info.n_case_cube)
                                         + io_item_related_info.n_skid_cube))
               WHERE   plogi_loc        = i_dest_loc
                 AND   cust_pref_vendor = i_cust_pref_vendor
                 AND   prod_id          = i_prod_id ;

            ELSE
               --if this is not the first pallet in the home slot
               --then no need to add skid cube because it will be placed on
               -- top of earlier pallet

               UPDATE inv
                  SET qty_planned = qty_planned +
                                      CEIL((io_workvar_rec.n_each_pallet_qty)
                                      * (io_workvar_rec.v_no_splits)),
                       cube        = DECODE(SIGN(99999.99 - (NVL(cube, 0)
                                         + CEIL(io_workvar_rec.n_each_pallet_qty
                                            * io_item_related_info.n_case_cube))),
                                    -1, 99999.99,
                                    (NVL(cube, 0)
                                     +  CEIL(io_workvar_rec.n_each_pallet_qty
                                      * io_item_related_info.n_case_cube)))
               WHERE   plogi_loc        = i_dest_loc
                 AND   cust_pref_vendor = i_cust_pref_vendor
                 AND   prod_id          = i_prod_id ;

            END IF;
            IF SQL%FOUND THEN
               --LOG THE SUCCESS MESSAGE
               lv_msg_text := PROGRAM_CODE || ' ORACLE inventory updated';

               pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

            ELSE
               --LOG THE ERROR MESSAGE
               lv_msg_text := PROGRAM_CODE ||
                            ' ORACLE unable to update inventory record';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               --raise exception
               RAISE e_inv_update;
            END IF;
         EXCEPTION
            WHEN e_inv_update THEN
               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO = '
                                                     || i_erm_id;
               pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to update inventory for pallet_id  '
               || lt_pallet_id || ' and prod id '
               || i_prod_id ||' cpv '
               || i_cust_pref_vendor ||
               ' - sqlcode= ' ||
               lv_error_text;
               RAISE;
            WHEN OTHERS THEN

               lv_msg_text := PROGRAM_CODE || ' SN/PO Number: '||i_erm_id||
                                           ' Update OF Inventory of Dest Loc '
                              || i_dest_loc || ', PROD ID ' ||
                              i_prod_id || ', CPV ' || i_cust_pref_vendor
                              || ' failed. ';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                                     || i_erm_id;
               pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to update inventory for pallet_id  '
               || lt_pallet_id || ' and prod id '
               || i_prod_id ||' cpv '
               || i_cust_pref_vendor ||
               ' - sqlcode= ' ||
               lv_error_text;
               RAISE;
         END;
      ELSIF i_home = ADD_RESERVE THEN

         --insert record into reserve inventory
         BEGIN
            INSERT INTO inv ( plogi_loc,
                              logi_loc,
                              parent_pallet_id,/*D#11309 MSKU Changes*/
                              prod_id,
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
                              cust_pref_vendor,
                              exp_date,
                              lot_id,
                              dmg_ind,
                              inv_uom
                            )
               VALUES    ( i_dest_loc,
                           lt_pallet_id,
                           DECODE(lv_rule_id, 1, NULL, 0, lt_parent_pallet_id), /*D#11309 MSKU Changes*/
                           i_prod_id,
                           i_erm_id,
                           CEIL(io_workvar_rec.n_each_pallet_qty
                           * io_workvar_rec.v_no_splits),
                           0,0,0, SYSDATE,SYSDATE,
                           io_item_related_info.v_abc,
                           DECODE(io_workvar_rec.v_dmg_ind ,'DMG','HLD',DECODE(i_aging_days, -1, 'AVL', 'HLD')),
                           SYSDATE,
                           DECODE(SIGN(99999.99
                                       -(CEIL(io_workvar_rec.n_each_pallet_qty
                                          * io_item_related_info.n_case_cube)
                           + io_item_related_info.n_skid_cube)),
                           -1, 99999.99,
                           (CEIL(io_workvar_rec.n_each_pallet_qty
                              * io_item_related_info.n_case_cube)
                           + io_item_related_info.n_skid_cube)),
                           SYSDATE,
                           i_cust_pref_vendor,
                           lt_exp_date,
                           lt_lot_id,
                           DECODE(io_workvar_rec.v_dmg_ind,'DMG','Y','N'),
                           0);   -- inv_uom


            lv_msg_text:=PROGRAM_CODE ||
                        ' ORACLE inventory created for SN/PO :' || i_erm_id
                       || 'product id : ' || i_prod_id;

            pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

         EXCEPTION
            WHEN OTHERS THEN

               lv_msg_text :=  ' SN/PO Number: '||i_erm_id
               || ' Insert of inventory dest loc ' || i_dest_loc
               || ', PROD ID '||i_prod_id|| ', CPV '|| i_cust_pref_vendor
               || ' failed. ';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                                     || i_erm_id;

               pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to insert into  inventory for pallet_id  '
               || lt_pallet_id || ' and prod id '
               || i_prod_id ||' cpv '
               || i_cust_pref_vendor ||
               ' - sqlcode= ' ||
               lv_error_text;
               RAISE;
         END;
      END IF;

      IF f_is_clam_bed_tracked_item(io_item_related_info.v_category,
                                    i_clam_bed_flag) THEN
         lv_clam_bed_trk := 'Y';
      ELSE
         lv_clam_bed_trk := 'N';
      END IF;

      IF f_is_tti_tracked_item(i_prod_id,i_cust_pref_vendor) THEN
         lv_tti_trk := 'Y';
      ELSE
         lv_tti_trk := 'N';
      END IF;

----acppzp---change for do not print LPN SN Receipt OSD
      IF io_workvar_rec.v_dmg_ind = 'DMG' THEN

    ---acppzp  update putawaylst :dest_loc inv_status for damaged pallet
         BEGIN
            UPDATE putawaylst
            SET dest_loc     = i_dest_loc,
                inv_status   = 'HLD'
            WHERE pallet_id = lt_pallet_id;
         EXCEPTION
           WHEN OTHERS THEN

               lv_msg_text :=  'SN/PO Number: '||i_erm_id
               || ' update of inventory dest loc ' || i_dest_loc
               || 'for damaged pallet '||lt_pallet_id|| 'in putawaylst failed. ';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :=
                                      'ERROR : Cannot set dest_loc for'
                                      || 'damaged pallet'||lt_pallet_id
                                      || ' of SN/PO = '
                                      || i_erm_id;
               pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to update putawaylst for pallet_id  '
               || lt_pallet_id || ' and prod id '
               || i_prod_id ||' cpv '
               || i_cust_pref_vendor ||
               ' - sqlcode= ' ||
               lv_error_text;
               RAISE;
         END;

      ----acppzp update inv


      ELSE
         BEGIN
            UPDATE trans
               SET  mfg_date = SYSDATE
             WHERE trans_type       = 'RHB'
               AND prod_id          = i_prod_id
               AND cust_pref_vendor = i_cust_pref_vendor
               AND rec_id           = i_erm_id
               AND ROWNUM           = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN

               lv_msg_text := PROGRAM_CODE ||' SN/PO Number: '||i_erm_id||
                      ' TABLE=TRANS,KEY= ' ||i_erm_id || ',' || i_prod_id ||
                      ',' || i_cust_pref_vendor || ' ACTION = UPDATE, ' ||
                      ' ORACLE unable to update RHB trans record ';
               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :=
                            'ERROR : Cannot open SN/PO= ' || i_erm_id;
               pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to update RHB record from trans for SN/PO  '||
               ' - sqlcode= ' ||
               lv_error_text;
               RAISE;
        END;

         BEGIN
            SELECT 'C'
              INTO lv_clam_bed_trk
              FROM trans
             WHERE trans_type = 'RHB'
               AND prod_id = i_prod_id
               AND cust_pref_vendor = i_cust_pref_vendor
               AND rec_id = i_erm_id
               AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            WHEN OTHERS THEN

               lv_msg_text := PROGRAM_CODE ||' SN/PO Number: '||i_erm_id||
                             ' TABLE=TRANS,KEY= ' ||i_erm_id || ',' || i_prod_id ||
                             ',' || i_cust_pref_vendor || ' ACTION = SELECT, ' ||
                             ' ORACLE unable to select trans record ';
               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                                     || i_erm_id;
               pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to select record from trans for SN/PO  '||
               ' - sqlcode= ' ||
               lv_error_text;
               RAISE;
        END;

          BEGIN

            -- 10/20/09 ctvgg000 Project ASN to all OPCOs
            -- Made Changes to below insert statement to populate the following
            -- variables v_catch_wt_trk, v_lot_trk, v_exp_date_trk, v_date_code
            -- like its done for SN.

            INSERT INTO putawaylst(rec_id,
                                prod_id,
                                dest_loc,
                                qty,
                                uom,
                                status,
                                inv_status,
                                pallet_id,
                                parent_pallet_id,/*D#11309 MSKU Changes*/
                                qty_expected,
                                qty_received,
                                temp_trk,
                                weight,
                                catch_wt,
                                lot_trk,
                                exp_date_trk,
                                date_code,
                                equip_id,
                                rec_lane_id,
                                seq_no,
                                putaway_put,
                                cust_pref_vendor,
                                exp_date,
                                mfg_date,
                                lot_id,
                                clam_bed_trk,
                                sn_no,
                                po_no,
                                po_line_id,
                                cool_trk)
                        VALUES (i_erm_id,
                                i_prod_id,
                               i_dest_loc,
                               CEIL(io_workvar_rec.n_each_pallet_qty
                                    * io_workvar_rec.v_no_splits),
                               0,'NEW',
                               DECODE(i_aging_days, -1, 'AVL', 'HLD'),
                               lt_pallet_id,
                               lt_parent_pallet_id,/*D#11309 MSKU Changes*/
                               CEIL(io_workvar_rec.n_each_pallet_qty
                                    * io_workvar_rec.v_no_splits),
                               CEIL(io_workvar_rec.n_each_pallet_qty
                                    * io_workvar_rec.v_no_splits),
                               io_item_related_info.v_temp_trk,
                               lt_catch_weight,
                        DECODE(lt_erm_type,'SN',decode(io_item_related_info.v_catch_wt_trk,'N','N',
                                  decode(lt_catch_weight,NULL,io_item_related_info.v_catch_wt_trk,'C')),
                                  'VN',decode(io_item_related_info.v_catch_wt_trk,'N','N',
                                  decode(lt_catch_weight,NULL,io_item_related_info.v_catch_wt_trk,'C')),
                   io_item_related_info.v_catch_wt_trk),
                     DECODE(lt_erm_type,'SN',decode(io_item_related_info.v_lot_trk,'N','N',
                                     decode(lt_lot_id,NULL,io_item_related_info.v_lot_trk,'C')),
                                     'VN',decode(io_item_related_info.v_lot_trk,'N','N',
                                     decode(lt_lot_id,NULL,io_item_related_info.v_lot_trk,'C')),
                      io_item_related_info.v_lot_trk),
                     --DECODE(lt_erm_type,'SN',decode(io_item_related_info.v_exp_date_trk,'N','N',
                     --                decode(lt_exp_date,NULL,io_item_related_info.v_exp_date_trk,'C')),
                     -- io_item_related_info.v_exp_date_trk),
                     DECODE(lt_erm_type,'SN', lv_need_exp_date,
                'VN', lv_need_exp_date,
                io_item_related_info.v_exp_date_trk),
            DECODE(lt_erm_type,'SN',decode(io_item_related_info.v_date_code,'N','N',
                                     decode(lt_mfg_date,NULL,io_item_related_info.v_date_code,'C')),
                               'VN',decode(io_item_related_info.v_date_code,'N','N',
                                     decode(lt_mfg_date,NULL,io_item_related_info.v_date_code,'C')),
                      io_item_related_info.v_date_code),
                                ' ',' ',
                               io_workvar_rec.n_seq_no,
                               'N',
                               i_cust_pref_vendor,
                               lt_exp_date,
                               lt_mfg_date,
                               lt_lot_id,
                               lv_clam_bed_trk,
                               DECODE(lt_erm_type,'SN',i_erm_id, 'VN',i_erm_id, NULL),
                               DECODE(lt_erm_type,'SN',lt_rdc_po, 'VN',lt_rdc_po,i_erm_id),
                               DECODE(lt_erm_type,'SN',lt_po_line_id, 'VN',lt_po_line_id,NULL),
                               io_item_related_info.v_cool_trk);

            lv_msg_text:=PROGRAM_CODE ||
                   ' Insert into Putawaylst SN/PO Number :' || i_erm_id
                   || ' Product Id : ' || i_prod_id
                   || ' CPV : ' || i_cust_pref_vendor
                   || ' Location : ' || i_dest_loc
                   || ' Quantity in Cases : '
                   || io_workvar_rec.n_each_pallet_qty
                   || ' Pallet Id : ' || lt_pallet_id;

           pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);


         EXCEPTION
            WHEN OTHERS THEN

               lv_msg_text := PROGRAM_CODE ||' SN/PO Number: '||i_erm_id||
                             ' TABLE=PUTAWAYLST,KEY= ' || lt_pallet_id ||
                             ',' || i_erm_id || ',' || i_prod_id ||
                             ',' || i_cust_pref_vendor || ' ACTION = INSERT, ' ||
                             ' ORACLE unable to create putaway record for pallet';
               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

               lv_error_text := sqlcode || sqlerrm;

               pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                                     || i_erm_id;
               pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to insert into putawaylst for pallet_id  '
               || lt_pallet_id ||
               ' - sqlcode= ' ||
               lv_error_text;
               RAISE;
      END;
      END IF;
----acppzp---change for do not print LPN

      --for catch weight
      IF io_item_related_info.v_catch_wt_trk = 'Y' THEN
         BEGIN
            SELECT 'X' into lv_tmp_check
              FROM  tmp_weight
             WHERE erm_id             = i_erm_id
               AND   prod_id              = i_prod_id
               AND   cust_pref_vendor   = i_cust_pref_vendor;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
            --LOG THE ERROR
            lv_msg_text:=PROGRAM_CODE || ' SN/PO Number: '||i_erm_id||
                        ' No Entry in TMP_WEIGHT table for for Product: '
                        ||i_prod_id||' CPV: '|| i_cust_pref_vendor;


            /* CREATE THE RECORD */
            BEGIN

               INSERT INTO tmp_weight(erm_id,
                                      prod_id,
                                      cust_pref_vendor,
                                      total_cases,
                                      total_splits,
                                      total_weight)
                              VALUES( i_erm_id,
                                      i_prod_id,
                                      i_cust_pref_vendor,
                                      lv_total_cases,0,lv_total_weight);


            EXCEPTION
               WHEN OTHERS THEN
               --LOG THE MESSAGE
               lv_msg_text:= PROGRAM_CODE || 'SN/PO Number: '||i_erm_id ||
                            ' Insertion into tmp_weight failed';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
            END;
         END;
      END IF;

   ELSE
      RAISE e_pallet_id;
   END IF;

   --REPROCESS
      IF gb_reprocess = TRUE THEN

        --LOG THE MESSAGE
        lv_msg_text:= 'Before system call for demand print of license plate';

        pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);
        /*
        ** create transaction record for demand printing of license plate
        */
        BEGIN
          INSERT INTO trans (trans_id,
                             trans_type,
                             rec_id,
                             trans_date,
                             user_id,
                             pallet_id,
                             qty,
                             prod_id,
                             cust_pref_vendor,
                             uom,
                             exp_date)
                     VALUES (trans_id_seq.NEXTVAL,
                             DECODE(io_workvar_rec.v_dmg_ind,'DMG','DMG','DLP'),
                             i_erm_id,
                             SYSDATE,
                             USER,
                             lt_pallet_id,
                             CEIL(io_workvar_rec.n_each_pallet_qty * io_workvar_rec.v_no_splits),
                             i_prod_id,
                             i_cust_pref_vendor,
                             0,
                             TRUNC(SYSDATE));

       --store new pallet ids in array
       --array will start from 1
       gtbl_pallet_id(io_workvar_rec.n_seq_no):=lt_pallet_id;
       EXCEPTION
        WHEN OTHERS THEN
            lv_msg_text:= PROGRAM_CODE || ' SN/PO Number: '||i_erm_id||
                         ' TABLE= trans KEY= ' || lt_pallet_id || ', '
                         || i_prod_id ||', ' || i_cust_pref_vendor
                         || ' ACTION= INSERT ' ||
                         ' MESSAGE = ORACLE unable to create DLP transaction.';

            pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

            lv_error_text := sqlcode || sqlerrm;
            pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                                     || i_erm_id;
            pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to update trans for pallet  '
               || lt_pallet_id || ' and prod id '
               || i_prod_id ||' cpv '
               || i_cust_pref_vendor ||
               ' - sqlcode= ' ||
               lv_error_text;
            RAISE;
       END;


       --check po status
       BEGIN
          SELECT 'x' INTO lv_flag
            FROM erm
           WHERE erm.status = 'OPN'
             AND erm.erm_id = i_erm_id;
          --commit will be performed in
          --pl_pallet_label2.p_reprocess method
       EXCEPTION
        WHEN OTHERS THEN
           lv_error_text := sqlcode || sqlerrm;
           pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                                   || i_erm_id;
           pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to select the record '
               ||' with status OPEN from erm table '
               ||' - sqlcode= ' ||
               lv_error_text;
           RAISE;
           --rollback in reprocess method
       END; /*END CHECK PO STATUS */

      END IF;/*reprocess*/


EXCEPTION
   WHEN e_pallet_id THEN
      --LOG THE ERROR MESSAGE
      lv_msg_text := PROGRAM_CODE || ' SN/PO Number: '|| i_erm_id ||
                    ' ORACLE unable to get next pallet_id sequence number';

      pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);


      --ROLLBACK IN THE MAIN PACKAGE
      lv_error_text := sqlcode || sqlerrm;
      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open SN/PO= '
                                             || i_erm_id;
      pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to generate pallet_id seq no - sqlcode= '
               || lv_error_text;
      RAISE;

   WHEN OTHERS THEN
      --ROLLBACK IN THE MAIN PACKAGE
      RAISE;
END p_insert_table;

--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Procedure:
--    p_get_item_info
--
-- Description:
--    This method retrieves all the data related to the process order,
--    which is relevant for further processing
-- Parameters:
--    i_product_id              - Product id of the item for which details
--                                are fetched
--    i_cust_pref_vendor        - Customer preferred vendor for the selected
--                                product
--    io_item_related_info_rec  - Record in which selected fields will be set.
--
-- Exceptions raised:
--
-- Called by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/22/05 prpbcb    COOL changes.
--                       Added call to function f_is_cool_tracked item to
--                       use in populating cool_trk.
--    08/09/05 prpakp    Added the condition to clear last ship slot of an
--                       item if it is not correct.
--    04/04/07 prpbcb    Get the pm.mfr_shelf_life.
--    04/19/07 prpbcb    Changed
--                          pm.mfr_shelf_life
--                       to
--                          NVL(pm.mfr_shelf_life, 0)
--                       in case it is null.
--   09/18/14  vred5319  Modified to get induction location for matrix item
--   09/25/14  prbcb000  Assign the prod_id and cpv where are now in the
--                       item info record.
--------------------------------------------------------------------------
  PROCEDURE p_get_item_info
                 (i_product_id                    IN     pm.prod_id%TYPE,
                   i_cust_pref_vendor             IN     pm.cust_pref_vendor%TYPE,
                   io_item_related_info_rec       IN OUT t_item_related_info)
  IS
  lb_error_flag BOOLEAN; -- used to check whether an error occured or not
  lv_pname      VARCHAR2(30);
  lt_erm_type   erm.erm_type%TYPE :='';

  l_zone                pm.zone_id%type;
  l_last_ship_slot      pm.last_ship_slot%type;
  l_last_check          number(1);
  l_logi_loc            loc.logi_loc%type;

  BEGIN
     --reset the global variable
     pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
     lv_pname  := 'p_get_item_info';
     --This will be used in the Exception message in assign putaway
     pl_putaway_utilities.gv_program_name := lv_pname;

     BEGIN
        select zone_id,last_ship_slot
        into l_zone,l_last_ship_slot
        from pm
        where prod_id =i_product_id
        and   i_cust_pref_vendor = i_cust_pref_vendor
        and   last_ship_slot is not null;
              l_last_check := 0;
        exception
           when others then
              l_last_check := 1;
     END;
     if (l_last_check = 0) then
        begin
          select logi_loc
          into l_logi_loc
          from loc l
          where logi_loc =l_last_ship_slot
          and   exists (select 1
                           from lzone lz, zone z
                           where l.logi_loc = lz.logi_loc
                           and   lz.zone_id = z.zone_id
                           and   z.zone_type ='PUT'
                           and   z.zone_id = l_zone);
          exception
             when others then
                 update pm
                 set last_ship_slot = null
                 where prod_id = i_product_id
                 and   i_cust_pref_vendor = i_cust_pref_vendor;
         end;
     end if;
     BEGIN
        lb_error_flag := FALSE;
        --select all the relevant fields from pm table into item info record
        SELECT pm.prod_id,
               pm.cust_pref_vendor,
               pm.ti,
               pm.hi,
               pm.pallet_type,
               pm.lot_trk,
               pm.fifo_trk,
               pm.spc,
               pm.case_cube,
               pm.case_length,
               pm.case_width,
               pm.case_height,
               pm.stackable,
               pm.pallet_stack,
               pm.max_slot,
               pm.max_slot_per,
               pm.abc,
               pm.zone_id,
               pm.temp_trk,
               pm.exp_date_trk,
               pm.catch_wt_trk,
               pm.mfg_date_trk,
               pm.last_ship_slot,
               pm.area,
               pm.category,
               pm.min_qty,
               NVL(pm.max_qty,0),
               z.rule_id                      rule_id,
               pm.split_zone_id               split_zone_id,
               z_split.rule_id                split_zone_rule_id,
               pm.auto_ship_flag              auto_ship_flag,
               pm.miniload_storage_ind        miniload_storage_ind,
               DECODE(z.rule_id, 3, z.induction_loc,
                  decode(pm.mx_item_assign_flag, 'Y', pl_matrix_common.f_get_mx_dest_loc(pm.prod_id),     --Vani Reddy added
                                      NULL)) case_induction_loc,
               DECODE(z_split.rule_id, 3, z_split.induction_loc,
                                       NULL)  split_induction_loc,  
               NVL(pm.mfr_shelf_life, 0),
               pm.mx_item_assign_flag,
               pm.mx_eligible,
               DECODE(z.rule_id, 3, z.induction_loc,
                  decode(pm.mx_item_assign_flag, 'Y', pl_matrix_common.f_get_mx_msku_dest_loc(pm.prod_id, pm.cust_pref_vendor),  -- BCB
                                      NULL)) mx_case_msku_induction_loc
          INTO
               io_item_related_info_rec.prod_id,
               io_item_related_info_rec.cust_pref_vendor,
               io_item_related_info_rec.n_ti,
               io_item_related_info_rec.n_hi,
               io_item_related_info_rec.v_pallet_type,
               io_item_related_info_rec.v_lot_trk,
               io_item_related_info_rec.v_fifo_trk,
               io_item_related_info_rec.n_spc,
               io_item_related_info_rec.n_case_cube,
               io_item_related_info_rec.n_case_length,
               io_item_related_info_rec.n_case_width,
               io_item_related_info_rec.n_case_height,
               io_item_related_info_rec.n_stackable,
               io_item_related_info_rec.n_pallet_stack,
               io_item_related_info_rec.n_max_slot,
               io_item_related_info_rec.v_max_slot_flag,
               io_item_related_info_rec.v_abc,
               io_item_related_info_rec.v_zone_id,
               io_item_related_info_rec.v_temp_trk,
               io_item_related_info_rec.v_exp_date_trk,
               io_item_related_info_rec.v_catch_wt_trk,
               io_item_related_info_rec.v_date_code,
               io_item_related_info_rec.v_last_ship_slot,
               io_item_related_info_rec.v_area,
               io_item_related_info_rec.v_category,
               io_item_related_info_rec.n_min_qty,
               io_item_related_info_rec.n_max_qty,
               io_item_related_info_rec.n_rule_id,
               io_item_related_info_rec.v_split_zone_id,
               io_item_related_info_rec.n_split_zone_rule_id,
               io_item_related_info_rec.v_auto_ship_flag,
               io_item_related_info_rec.v_miniload_storage_ind,
               io_item_related_info_rec.v_case_induction_loc,
               io_item_related_info_rec.v_split_induction_loc,
               io_item_related_info_rec.n_mfr_shelf_life,
               io_item_related_info_rec.v_mx_item_assign_flag,
               io_item_related_info_rec.mx_eligible,
               io_item_related_info_rec.mx_case_msku_induction_loc
          FROM zone        z,        -- To get the rule id of pm.zone_id and the
                                     -- miniload induction location for cases.
               zone        z_split,  -- Joined to pm.split_zone_id to determine
                                     -- the miniload induction location for
                                     -- splits.
               pm
         WHERE pm.prod_id             = i_product_id
           AND pm.cust_pref_vendor    = i_cust_pref_vendor
           AND z.zone_id (+)          = pm.zone_id
           AND z_split.zone_id (+)    = pm.split_zone_id;


         -- If this point reached then the item info was successfully selected.
         -- Set the COOL tracked field.
         IF (f_is_cool_tracked_item(i_product_id, i_cust_pref_vendor)) THEN
            io_item_related_info_rec.v_cool_trk := 'Y';
         ELSE
            io_item_related_info_rec.v_cool_trk := 'N';
         END IF;

     EXCEPTION
        WHEN OTHERS THEN
        BEGIN

           pl_log.ins_msg ('WARN', lv_pname,
                           'ORACLE failed to select item information from PM'
                            ||' table',
                           NULL, SQLERRM);
           lb_error_flag := TRUE;
        END;
     END;

     IF lb_error_flag = FALSE THEN --call P_Get_Num_Next_Zones only
                                   --when selection of rows succeeds
        BEGIN
        io_item_related_info_rec.n_num_next_zones
                       := f_get_num_next_zones(io_item_related_info_rec.v_area);
        EXCEPTION
          WHEN OTHERS THEN
            BEGIN

               pl_log.ins_msg ('WARN', lv_pname,
                               'ORACLE failed to find next zones number for '
                               || 'the product '
                               || i_product_id ,NULL, SQLERRM);

              io_item_related_info_rec.n_num_next_zones := 0;
           END;
        END;
        BEGIN
           --select all relevant fields from pallet type table into item info
           --record
           SELECT NVL(p.cube, 0), NVL(p.skid_cube, 0),NVL(p.skid_height, 0),
                  NVL(putaway_fp_prompt_for_hst_qty,'N'),
                  NVL(putaway_pp_prompt_for_hst_qty,'N'),
                  NVL(putaway_use_repl_threshold,'N'),
                  NVL(ext_case_cube_flag,'Y')
             INTO io_item_related_info_rec.n_pallet_cube,
                  io_item_related_info_rec.n_skid_cube,
                  io_item_related_info_rec.n_skid_height,
                  io_item_related_info_rec.v_fp_flag,
                  io_item_related_info_rec.v_pp_flag,
                  io_item_related_info_rec.v_threshold_flag,
                  io_item_related_info_rec.v_ext_case_cube_flag
             FROM pallet_type p
            WHERE p.pallet_type = io_item_related_info_rec.v_pallet_type;
        EXCEPTION
           WHEN OTHERS THEN
           BEGIN
               -- if selection fails then initialize each variable in the item info
               --record to it's default value
              pl_log.ins_msg ('WARN', lv_pname,
                              'ORACLE failed to find skid height for pallet_type '
                              || 'for the product '
                              || i_product_id ,NULL, SQLERRM);

              io_item_related_info_rec.n_pallet_cube    := 0.0;
              io_item_related_info_rec.n_skid_cube       := 0.0;
              io_item_related_info_rec.n_skid_height    := 0.0;
              io_item_related_info_rec.v_fp_flag        := 'N';
              io_item_related_info_rec.v_pp_flag        := 'N';
              io_item_related_info_rec.v_threshold_flag := 'N';
           END;
        END;

        BEGIN
          --select all the relevant details about the last shipment slot into
           --corresponding variables in the item info record
           --(used if item is a floating item)
          SELECT  l.slot_type,
                  l.put_aisle,
                  l.put_slot,
                  l.put_level
           INTO io_item_related_info_rec.v_last_pik_slot_type,
                io_item_related_info_rec.n_last_put_aisle1,
                io_item_related_info_rec.n_last_put_slot1,
                io_item_related_info_rec.n_last_put_level1
           FROM loc l
          WHERE l.logi_loc = io_item_related_info_rec.v_last_ship_slot;

           pl_log.ins_msg ('DEBUG', 'P_Get_Item_Info', 'last_ship_slot='
                           || io_item_related_info_rec.v_last_ship_slot
                           || ' , n_last_pik_height='
                           || io_item_related_info_rec.n_last_pik_height
                           || ' n_last_pik_width_positions  = '
                           || io_item_related_info_rec.n_last_pik_width_positions
                           || ',last_pik_slot_type = '
                           ||io_item_related_info_rec.v_last_pik_slot_type
                           || ', last_put_aisle1 = '
                           ||io_item_related_info_rec.n_last_put_aisle1
                           ||  ', last_put_slot1 = '
                           || io_item_related_info_rec.n_last_put_slot1
                           || ',last_put_level1 = '
                           || io_item_related_info_rec.n_last_put_level1,
                           NULL, SQLERRM);

        EXCEPTION
         WHEN OTHERS THEN
         BEGIN
            io_item_related_info_rec.n_last_put_aisle1 := 0;
            io_item_related_info_rec.n_last_put_slot1 := 0;
            io_item_related_info_rec.n_last_put_level1 := 0;
            pl_log.ins_msg ('WARN', 'P_Get_Item_Info', 'ORACLE failed to '
                             ||'find last pik information for the product id '
                             || i_product_id ,NULL, SQLERRM);

         END;
       END;


     END IF;
 END p_get_item_info;


  /* -----------------------------------------------------------------------
     -- Procedure:
     --    p_get_erm_info
     --
     -- Description:
     -- This method retrieves all the data related to the Shipment from erd_lpn
     -- which is relevant for further processing
     -- Parameters:
     --    i_product_id                - product id of the item for which
                                         details are fetched
     --    i_cust_pref_vendor - customer preferred vendor for the
                                         selected product
     --    io_item_related_info_rec    - record in which selected fields will
                                         be set
  ---------------------------------------------------------------------*/
  PROCEDURE p_get_erm_info
                 ( i_erm_id                        IN     erm.erm_id%TYPE,
                   i_product_id                    IN     pm.prod_id%TYPE,
                   i_cust_pref_vendor              IN     pm.cust_pref_vendor%TYPE,
                   io_item_related_info_rec        IN OUT t_item_related_info)
  IS
  lb_error_flag BOOLEAN; -- used to check whether an error occured or not
  lv_pname      VARCHAR2(30);
  lt_erm_type   erm.erm_type%TYPE :='';
  BEGIN
     --reset the global variable
     pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
     lv_pname  := 'p_get_erm_info';
     --This will be used in the Exception message in assign putaway
     pl_putaway_utilities.gv_program_name := lv_pname;
     BEGIN
        SELECT erm_type
        INTO lt_erm_type
        FROM erm
        WHERE erm_id = i_erm_id;
     EXCEPTION
        WHEN OTHERS THEN
               pl_log.ins_msg ('WARN', lv_pname,
                               'ORACLE failed to select erm_type for '
                               || 'the SN/PO '
                               || i_erm_id ,NULL, SQLERRM);
               RAISE;

     END;

          -- 10/20/09 - ctvgg000 - ASN to all OPCOs project
      -- Include VN to select pallet_type, Shipped Ti Hi.

     IF lt_erm_type IN ('SN','VN') THEN
       BEGIN
          SELECT shipped_ti,shipped_hi,pallet_type
          INTO io_item_related_info_rec.n_ti,
               io_item_related_info_rec.n_hi,
               io_item_related_info_rec.v_pallet_type
          FROM erd_lpn
          WHERE sn_no            = i_erm_id
          AND   prod_id          = i_product_id
          AND   cust_pref_vendor = i_cust_pref_vendor
          AND  rownum           = 1;
       EXCEPTION
          WHEN OTHERS THEN
               pl_log.ins_msg ('WARN', lv_pname,
                                'ORACLE failed to select info for '
                               || 'the SN'
                               || i_erm_id ,NULL, SQLERRM);
               RAISE;

       END;
     END IF;
 END p_get_erm_info;

/*----------------------------------------------------------------------------
   --  Procedure:p_update_heights
   --
   --   Description:
   --    This method will be called to update  the available and
   --    occupied height of locations when a list of locations is specified in
   --    an array
   --
   --
   -- Exceptions raised:
   --    -20001  - Oracle error occurred.
  ---------------------------------------------------------------------------*/
 PROCEDURE p_update_heights(i_locations IN  pl_putaway_utilities.t_phys_loc,
                               o_status OUT NUMBER)
 IS
     l_object_name  VARCHAR2(30) := 'P_UPDATE_HEIGHTS';
     l_index NUMBER;
   BEGIN
     FOR l_index IN i_locations.FIRST..i_locations.LAST LOOP
       p_update_height_data(i_locations(l_index), o_status);
     END LOOP;  --End loop through input locations
     o_status:=0;
  EXCEPTION
     WHEN OTHERS THEN
        --o_status:=999;
        RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
  END p_update_heights;

----------------------------------------------------------------------------
--  Procedure:p_compute_height_data
--
--   Description:
--    Compute Heights
--    -20001  - Oracle error occurred.
-----------------------------------------------------------------------------
PROCEDURE p_compute_height_data
                (i_inv_loc_id     IN inv.plogi_loc%TYPE,
                i_loc             IN loc.logi_loc%TYPE,
                i_perm            IN loc.perm%TYPE,
                i_qoh             IN inv.qoh%TYPE,
                i_qty_planned     IN inv.qty_planned%TYPE,
                i_spc             IN pm.spc%TYPE,
                i_ti              IN pm.ti%TYPE,
                i_hi              IN pm.hi%TYPE,
                i_width_positions IN loc.width_positions%TYPE,
                i_deep_positions  IN slot_type.deep_positions%TYPE,
                i_skid_height     IN pallet_type.skid_height%TYPE,
                i_case_height     IN pm.case_height%TYPE,
                o_status          OUT NUMBER
                )IS

 --The total number of pallets that will be there in the slot.
 l_no_pallets_hs  NUMBER;
 --The total height of all the pallet skids.
 l_total_skid_height NUMBER;
  --Total Occupied height in the location
 l_pallet_height inv.pallet_height%TYPE;
 l_object_name  VARCHAR2(30) := 'p_compute_height_data';


 BEGIN
 IF (i_perm = 'Y') THEN
       l_no_pallets_hs:=ceil(((i_qoh +
                i_qty_planned) /
                i_spc) /
                (i_ti*i_hi));

       --This is to determine how many times the skid height of
       --the pallet should be considered while computing the pallet height
       --in the homeslot.Though there is no tracking on the basis of
       --pallets in the  home slot there will in reality be
       --one pallet per location in the home slots and therfore
       --the skid height has to be considered.
       IF  (l_no_pallets_hs- (i_deep_positions
                 *i_width_positions) >=0) THEN
          l_total_skid_height:=(i_deep_positions
                   *i_width_positions)
                   *i_skid_height;
       ELSE
          l_total_skid_height:=l_no_pallets_hs
                   *i_skid_height;
       END IF;
       l_pallet_height := ceil(((i_qoh +
                  i_qty_planned) /
                  i_spc) /
                  i_ti) *
                  i_case_height
                  + l_total_skid_height;

    ELSE
       l_pallet_height := ceil(((i_qoh
                 + i_qty_planned)
                 / i_spc) /
                 i_ti) *
                 i_case_height
                 + i_skid_height;
    END IF;

    --
    -- Update the inventory and location heights.
    --
    UPDATE inv
       SET pallet_height = NVL(l_pallet_height,0)
     WHERE logi_loc = i_inv_loc_id;

    UPDATE loc
       SET available_height =
             NVL(available_height, 0) - NVL(l_pallet_height, 00),
             occupied_height = NVL(occupied_height, 0) + NVL(l_pallet_height,0)
     WHERE logi_loc = i_loc;

    o_status:=0;
EXCEPTION
  WHEN OTHERS THEN
     o_status:=999;
     RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END p_compute_height_data;

-----------------------------------------------------------------------------
--  Procedure:p_update_heights_for_item
--
--   Description:This method will update the heights of all the items
--   in the inventory where this product is present.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
-----------------------------------------------------------------------------
PROCEDURE p_update_heights_for_item
             (i_prod_id           IN  pm.prod_id%TYPE,
              i_cust_pref_vendor  IN  pm.cust_pref_vendor%TYPE,
              o_status            OUT NUMBER)
IS
   l_object_name  VARCHAR2(30) := 'P_UPDATE_HEIGHTS_FOR_ITEM';
BEGIN
   FOR r_loc_info IN c_loc_for_item(i_prod_id, i_cust_pref_vendor) LOOP
      p_update_height_data(r_loc_info.loc, o_status);
   END LOOP;

   o_status:=0;
EXCEPTION
   WHEN OTHERS THEN
      --o_status:=999;
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END p_update_heights_for_item;


/*----------------------------------------------------------------------------
--  Procedure:p_update_height_data
--
--   Description:
--    This PL/SQL procedure populates the INV.PALLET_HEIGHT column the
--    LOC.AVAILABLE height column and the LOCATION.OCCUPIED HEIGHT column.
--    For each of the locations details of all the products that exist in
--    the locatons are selected
--    and for each of the products the inventory's pallet height
--    calculated.The available height for the location in LOC table
--    is initially set to the product of slot height width positions and
--    depth positions.Then as the pallet heights are being computed
--    the available height  decremented by the pallet height and
--    the occupied height is incremented by  the pallet height.
--    The pallet height of the home slot will also be calculated.based on the
--    quantity on hand and the quantity allocated.
--    If the home slot is a deep slot(say 2 deep)
--    and there is enough quantity in the home slot to fit more than
--    one pallet then the skid is added twice.
--    This procedure is currently being used by the Home Slot transfer
--    and the transfer forms to update the heights of the slots
--    after performing a transfer
--
--   Important: Before running this script the case dimensions of the
--   items in the PM table and the width and depth positions of the slot
--   in the LOC and SLOT_TYPE tables must be setup.
--   The skid height in the PALLET_TYPE table should also have been
--   updated with accurate values.
--
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
---------------------------------------------------------------------------*/
PROCEDURE p_update_height_data(i_loc    IN inv.plogi_loc%TYPE,
                               o_status OUT NUMBER)
IS


   l_object_name  VARCHAR2(30) := 'P_UPDATE_HEIGHT_DATA';

   l_tmp_plogi_loc inv.plogi_loc%TYPE;

   --l_r_location_info c_distinct_items%ROWTYPE;
   -- xxxx l_r_location_info   c_loc_item_info_by_loc%ROWTYPE;

BEGIN
   FOR l_r_location_info IN  c_loc_item_info_by_loc(i_loc) LOOP
      IF (NVL(l_tmp_plogi_loc,' ') <> l_r_location_info.loc) THEN
         UPDATE LOC
            SET available_height = (l_r_location_info.slot_height
                                      * l_r_location_info.deep_positions
                                      * l_r_location_info.width_positions),
                         occupied_height = 0
          WHERE logi_loc=l_r_location_info.loc;

         l_tmp_plogi_loc := l_r_location_info.loc;
      END IF;

      --
      -- Check if all the item and location related parameters
      -- are valid.
      --
      IF ((l_r_location_info.prod_id is NOT NULL)
               AND (NVL(l_r_location_info.spc,0) <=0
                    OR NVL(l_r_location_info.ti,0)<=0
                    OR NVL(l_r_location_info.hi,0)<=0
                    OR NVL(l_r_location_info.case_height,0)<=0 )) THEN

         --o_status:=pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         --RAISE pl_exc.e_data_not_found;
         RAISE_APPLICATION_ERROR(-20001,
                        l_object_name || ': '
                        || 'Product Info for '|| l_r_location_info.prod_id
                        || ' is not valid. Location: ' || l_r_location_info.loc
                        || ' Case height:'||l_r_location_info.case_height);
         --RETURN;
      END IF;

      IF (NVL(l_r_location_info.slot_height,0) <=0) THEN
         RAISE_APPLICATION_ERROR(-20001,l_object_name || ':'||
                        'Slot Height Info not valid for location '
                        || l_r_location_info.loc);

      END IF;

      p_compute_height_data(l_r_location_info.inv_loc_id,
                            l_r_location_info.loc,
                            l_r_location_info.perm,
                            l_r_location_info.qoh,
                            l_r_location_info.qty_planned,
                            l_r_location_info.spc,
                            l_r_location_info.ti,
                            l_r_location_info.hi,
                            l_r_location_info.width_positions,
                            l_r_location_info.deep_positions,
                            l_r_location_info.skid_height,
                            l_r_location_info.case_height,
                            o_status);
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      --o_status:=999;
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END p_update_height_data;


----------------------------------------------------------------------------
-- Description:
--    This PL/SQL procedure will be used for updating the pallet heights
--    of all the locations in the inventory aisle by aisle.
--    Initially it will validate if all the case dimensions of items in
--    inventory
--    have been setup and then it will validate if all the slot dimensions of
--    all 'AVL' slots in warehouse have been setup.If this has been done
--    then it will go ahead and update the pallet heights of inv.
--Parameters
-- o_status:
--         Status will be 1 if case dimensions have not been setup accurately
--         Status will be 2 if slot dimensions have not been setup accurately.
--         Status will be 0 if updates are successful.
------------------------------------------------------------------------------
 PROCEDURE p_dimension_setup (o_status OUT NUMBER
                             )
 IS

   l_object_name  VARCHAR2(30) := 'P_DIMENSION_SETUP';
   l_msg_text       varchar2(500);
   lv_check VARCHAR2(2);

   CURSOR c_all_aisles IS
   SELECT distinct(substr(plogi_loc,1,1)) area from inv;
   l_r_aisle_info c_all_aisles%ROWTYPE;

BEGIN
   pl_log.g_application_func := 'P_DIMENSION_SETUP';
   pl_log.g_program_name := 'P_DIMENSION_SETUP';
   o_status:=0;
   BEGIN
      SELECT 'X' into lv_check FROM dual WHERE  EXISTS
      (SELECT '1' from inv,pm where inv.prod_id=pm.prod_id
       AND (pm.case_height =0 or pm.case_height is null)
      );
      o_status:=1;
      l_msg_text := 'Oracle:Unable to Change SYPAR to I since Case
                     dimension info was not setup';
      pl_log.ins_msg('ERROR',l_object_name,l_msg_text,NULL,NULL);
      RETURN;
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
        BEGIN
        SELECT 'X' into lv_check FROM dual WHERE EXISTS
        (
        SELECT '1' from loc where status='AVL'
        AND (loc.slot_height =0 or loc.slot_height is null)
        );
        o_status:=2;
        l_msg_text := 'Oracle:Unable to Change SYPAR to I
                       since Slot dimension info was not setup';
    pl_log.ins_msg('ERROR',l_object_name,l_msg_text,NULL,NULL);
        RETURN;
        EXCEPTION
         WHEN NO_DATA_FOUND THEN
                --Computing Heights for all the areas present in the Inventory.
                FOR l_r_aisle_info IN c_all_aisles LOOP
                   p_update_heights(o_status,l_r_aisle_info.area||'%');
                END LOOP;
        END;
   END;
EXCEPTION
WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END p_dimension_setup;


---------------------------------------------------------------------------
-- Description:
--    This PL/SQL procedure populates the INV.PALLET_HEIGHT column the
--    LOC.AVAILABLE height column and the LOCATION.OCCUPIED HEIGHT column.
--    For each of the locations details of all the products that exist in
--    the locatons are first selected
--    and for each of the products the inventory's pallet height is first
--    calculated.The available height for the location in LOC table
--    is initially set to the product of slot height width positions and
--    depth positions.Then as the pallet heights are being computed
--    the available height  decremented by the pallet height and
--    the occupied height is incremented by  the pallet height.
--    The pallet height of the home slot will also be calculated.based on the
--    quantity on hand and the quantity allocated.
--    If the home slot is a deep slot(say 2 deep)
--    and there is enough quantity in the home slot to fit more than
--    one pallet then the skid is added twice.
--
--   Important: Before running this script the case dimensions of the
--   items in the PM table and the width and depth positions of the slot
--   in the LOC and SLOT_TYPE tables must be setup.
--   The skid height in the PALLET_TYPE table should also have been
--   updated with accurate values.
--
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
------------------------------------------------------------------------------
PROCEDURE p_update_heights(o_status OUT NUMBER ,
                            cp_aisle IN VARCHAR)
IS


   l_commit_count NUMBER;
   l_object_name  VARCHAR2(30) := 'P_UPDATE_HEIGHTS';
   l_msg_text       varchar2(500);

   l_skid_height  pallet_type.skid_height%TYPE;
   l_index NUMBER;

   --The total number of pallets that will be there in the slot.
   l_no_pallets_hs  NUMBER;
   --The total height of all the pallet skids.
   l_total_skid_height NUMBER;
   --Total Occupied height in the location
   l_total_occ_height loc.occupied_height%TYPE;
   l_total_available_height loc.available_height%TYPE;
   l_pallet_height inv.pallet_height%TYPE;
   l_tmp_plogi_loc inv.plogi_loc%TYPE;



   CURSOR c_loc_item_info IS
   SELECT i.logi_loc inv_loc_id,l.logi_loc loc,i.qoh qoh
                ,i.qty_planned qty_planned
                ,NVL(pt.skid_height, 0) skid_height, l.perm perm
                ,NVL(l.slot_height,0) slot_height
                ,NVL(st.deep_positions,1) deep_positions
                ,NVL(l.width_positions,1) width_positions
                ,NVL(p.case_height,0) case_height
                ,NVL(p.ti,0) ti
                ,NVL(p.hi,0) hi
                ,NVL(p.spc,0) spc
                ,p.prod_id prod_id
         FROM pallet_type pt, loc l,slot_type st,inv i,pm p
         WHERE l.logi_loc=i.plogi_loc(+) and
               i.prod_id=p.prod_id(+) and
               l.pallet_type=pt.pallet_type and
               l.slot_type=st.slot_type
               and l.logi_loc like cp_aisle
               order by plogi_loc;

   l_r_location_info c_loc_item_info%ROWTYPE;

BEGIN

   l_commit_count:=0;
   FOR l_r_location_info IN c_loc_item_info
      LOOP
      l_commit_count:=l_commit_count+1;
      SAVEPOINT loc;
         BEGIN

         --dbms_output.put_line(l_r_location_info.loc);

         IF (NVL(l_tmp_plogi_loc,' ')<> l_r_location_info.loc) THEN
            UPDATE LOC
            SET available_height=(l_r_location_info.slot_height
                        *l_r_location_info.deep_positions
                        *l_r_location_info.width_positions),
            occupied_height=0
            where logi_loc=l_r_location_info.loc;
            l_tmp_plogi_loc:= l_r_location_info.loc;

         END If;
         --To Check if all the item and location related parameters
         --are valid
         IF ((l_r_location_info.prod_id is NOT NULL)
                   AND (NVL(l_r_location_info.spc,0) <=0
                   OR NVL(l_r_location_info.ti,0)<=0
                   OR NVL(l_r_location_info.hi,0)<=0
                   OR NVL(l_r_location_info.case_height,0)<=0 )) THEN


           --o_status:=pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
           l_msg_text := 'Oracle:Data Invalid for';
           l_msg_text :=l_msg_text||' Product ID: '||l_r_location_info.prod_id
                                  ||' SPC: '||l_r_location_info.spc
                                  ||' Ti: '||l_r_location_info.ti
                                  ||' Hi: '||l_r_location_info.hi
                                  ||' Case height: '||l_r_location_info.case_height;


           pl_log.ins_msg('WARN',l_object_name,l_msg_text,NULL,NULL);
        ELSIF  NVL(l_r_location_info.slot_height,0)<=0 THEN

            l_msg_text := 'Oracle:Data Invalid for';
            l_msg_text :=l_msg_text||' Location :'||l_r_location_info.loc
                                   ||' Slot Height: '||l_r_location_info.slot_height;
            pl_log.ins_msg('WARN',l_object_name,l_msg_text,NULL,NULL);
          --dbms_output.put_line(l_msg_text);

         ELSE

         p_compute_height_data(l_r_location_info.inv_loc_id,
                               l_r_location_info.loc,
                               l_r_location_info.perm,
                               l_r_location_info.qoh,
                               l_r_location_info.qty_planned,
                               l_r_location_info.spc,
                               l_r_location_info.ti,
                               l_r_location_info.hi,
                               l_r_location_info.width_positions,
                               l_r_location_info.deep_positions,
                               l_r_location_info.skid_height,
                               l_r_location_info.case_height,
                               o_status);
       END IF;

       IF (MOD(l_commit_count,COMMIT_INTERVAL) = 0) THEN
         --dbms_output.put_line('Going to commit Commit Count: '|| l_commit_count||'Loc:'||l_r_location_info.loc);
         COMMIT;
       END IF;
       EXCEPTION
                 WHEN OTHERS THEN
                   --dbms_output.put_line('Rollback'||l_r_location_info.loc);
                   --dbms_output.put_line(SQLERRM);
                 ROLLBACK TO SAVEPOINT loc;

        END;

      END LOOP; -- End looping through the pallets in each location.
      COMMIT;
   o_status:=0;
EXCEPTION
   WHEN OTHERS THEN
       o_status:=999;
       RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END p_update_heights;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    p_find_xfr_slots
   --
   -- Description:
   -- This method finds suitable slots to be suggested for slot-slot
   -- transfer.
   -- This method identifies slots that can fit the pallet to be transfered.
   -- It looks only for slots that are not deep and that has the same pallet
   -- type or slot type of the slot from which the transfer happens.
   -- It also checks whether the item transferred can be stacked in the
   -- location identified.
   --    i_whousemove                - Doing warehouse move home slot transfer
   --                                  (W) or not (null)
   --    i_from_loc                  - Location from where there is a transfer.
   --    i_qty                       - Quantity in splits of the product
   --                                  to be transferred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    07/10/06 prpbcb   Removed DISTINCT from the select stmt in cursor
   --                      c_get_deep_i_empty_slots as shown below.  It was
   --                      causing an error when putaway was by inches.  The
   --                      DISTINCT is not needed.
   --                      Old select stmt:
   --                         SELECT DISTINCT l.logi_loc, l.cube, l.put_aisle,
   --                                         l.put_slot, l.put_level
   --                      New select stmt:
   --                         SELECT l.logi_loc, l.cube, l.put_aisle,
   --                                l.put_slot, l.put_level
   --                      The error was not being handled in this procedure
   --                      so it propogated to the calling object.  Because of
   --                      how the calling procedure was handling errors the
   --                      RF was never sent an error code and the suggested
   --                      list of locations was blank.  A WHEN OTHERS EXCEPTION
   --                      handler was added to this procedure.
   --
   --                      Once the bug was fixed found the suggested list
   --                      was not always correct.
   ---------------------------------------------------------------------------
   PROCEDURE p_find_xfr_slots(  i_whousemove IN VARCHAR2 DEFAULT NULL,
                i_from_loc IN inv.logi_loc%TYPE,
                                i_qty IN inv.qoh%TYPE,
                                i_num_of_locations IN OUT NUMBER,
                                o_suitable_locations
                                OUT pl_putaway_utilities.t_phys_loc,
                                o_status OUT NUMBER
                                               )    IS

      l_object_name   VARCHAR2(61) := gl_pkg_name || '.p_find_xfr_slots';
      lt_item_related_info_rec pl_putaway_utilities.t_item_related_info := NULL;
      l_loc_rec            t_loc_info := NULL;
      l_syspar_rec        pl_putaway_utilities.t_syspar_var := NULL;

      l_msg_text        VARCHAR2(500);
      l_sys_put_dim_flag    sys_config.config_flag_val%TYPE := NULL;
      l_home            loc.logi_loc%TYPE := NULL;
      l_pallet_size        NUMBER := 0;
      l_num_recs        NUMBER := 0;
      l_putback_wh_area        whmveloc_area_xref.putback_wh_area%TYPE := NULL;
      l_index            NUMBER;
      l_num_item_next_zone    NUMBER := 0;
      l_zone_index        NUMBER := 0;

      CURSOR c_loc_type (cp_loc  loc.logi_loc%TYPE,
                         cp_what VARCHAR2 DEFAULT 'F') IS
         SELECT DECODE(cp_loc, plogi_loc, 'F', bck_logi_loc, 'B', 'N') loc_type,
                DECODE(cp_what,
                       'F', DECODE(cp_loc, plogi_loc, cp_loc,
                                           bck_logi_loc, plogi_loc, NULL),
                       DECODE(cp_loc, plogi_loc, bck_logi_loc,
                                      bck_logi_loc, cp_loc, NULL)) logi_loc
         FROM loc_reference
         WHERE plogi_loc = cp_loc
         OR    bck_logi_loc = cp_loc;

      CURSOR c_inv_info (cp_pallet_id inv.logi_loc%TYPE) IS
         SELECT prod_id, cust_pref_vendor, plogi_loc
         FROM inv
         WHERE logi_loc = cp_pallet_id;

      CURSOR c_loc_info (cp_loc     loc.logi_loc%TYPE,
                         cp_loc_ref VARCHAR2 DEFAULT 'N',
                         cp_prod_id loc.prod_id%TYPE,
                         cp_cpv     loc.cust_pref_vendor%TYPE) IS
         SELECT DECODE(NVL(l.perm, 'N'),
                       'Y', 'H',
                       DECODE(z.rule_id, 0, 'R', 1, 'F', 'B')) loc_type,
                l.status, l.pallet_type, l.rank, l.uom,
                l.pik_aisle, l.pik_slot, l.pik_level,
                l.put_aisle, l.put_slot, l.put_level,
                l.cube,
                DECODE(cp_loc_ref, 'N', cp_prod_id, l.prod_id) prod_id,
                DECODE(cp_loc_ref,
                       'N', cp_cpv, l.cust_pref_vendor) cust_pref_vendor,
                l.slot_type,
                l.available_height, s.deep_ind, s.deep_positions, z.zone_id
         FROM loc l, zone z, lzone lz, slot_type s
         WHERE l.logi_loc = lz.logi_loc
         AND   z.zone_id = lz.zone_id
         AND   z.zone_type = 'PUT'
         AND   l.slot_type = s.slot_type
         AND   l.logi_loc = cp_loc;

      CURSOR c_get_home(cp_prod_id loc.prod_id%TYPE,
                        cp_cpv     loc.cust_pref_vendor%TYPE) IS
         SELECT l.logi_loc
         FROM loc l
         WHERE l.prod_id = cp_prod_id
         AND   l.cust_pref_vendor = cp_cpv
         AND   l.perm = 'Y'
         AND   l.status = 'AVL'
         AND   l.uom IN (0, 2);

      CURSOR c_get_nondeep_i_slots (cp_zone_id zone.zone_id%TYPE,
                                    cp_rule    VARCHAR2 DEFAULT 'B') IS
         SELECT DISTINCT l.logi_loc, l.available_height, l.put_aisle,
                l.put_slot, l.put_level
         FROM loc l, zone z, lzone lz
         WHERE l.status = 'AVL'
         AND   l.perm = 'N'
         AND   (((cp_rule = 'B') AND
                 ((DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                   DECODE(lt_item_related_info_rec.v_pallet_type,
                         'FW', 'LW', lt_item_related_info_rec.v_pallet_type)) OR
                  (l.pallet_type IN (SELECT mixed_pallet
                                     FROM pallet_type_mixed
                                     WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type))))
                OR
                ((cp_rule <> 'B') AND
                 (((l_syspar_rec.v_pallet_type_flag = 'Y') AND
                   ((l.pallet_type = lt_item_related_info_rec.v_pallet_type) OR
                    (l.pallet_type IN (SELECT mixed_pallet
                                       FROM pallet_type_mixed
                                       WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type))))
                  OR
                  ((l_syspar_rec.v_pallet_type_flag = 'N') AND
                   (l.slot_type = l_loc_rec.v_slot_type)))))
         AND   l.available_height >= l_pallet_size
         AND   NOT EXISTS (SELECT 1
                           FROM inv
                           WHERE plogi_loc = l.logi_loc)
         AND   z.zone_id = lz.zone_id
         AND   z.zone_type = 'PUT'
         AND   l.logi_loc = lz.logi_loc
         AND   z.zone_id = cp_zone_id
         ORDER BY ABS(l_loc_rec.n_put_aisle - l.put_aisle), l.put_aisle,
                  ABS(l_loc_rec.n_put_slot - l.put_slot), l.put_slot,
                  ABS(l_loc_rec.n_put_level - l.put_level), l.put_level,
                  l.available_height;

      CURSOR c_get_nondeep_c_slots (cp_zone_id zone.zone_id%TYPE,
                                    cp_rule    VARCHAR2 DEFAULT 'B') IS
         SELECT DISTINCT l.logi_loc, l.cube, l.put_aisle,
                l.put_slot, l.put_level
         FROM loc l, zone z, lzone lz
         WHERE l.status = 'AVL'
         AND   l.perm = 'N'
         AND   (((cp_rule = 'B') AND
                 ((DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                   DECODE(lt_item_related_info_rec.v_pallet_type,
                         'FW', 'LW', lt_item_related_info_rec.v_pallet_type)) OR
                  (l.pallet_type IN (SELECT mixed_pallet
                                     FROM pallet_type_mixed
                                     WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type))))
                OR
                ((cp_rule <> 'B') AND
                 (((l_syspar_rec.v_pallet_type_flag = 'Y') AND
                   ((l.pallet_type = lt_item_related_info_rec.v_pallet_type) OR
                    (l.pallet_type IN (SELECT mixed_pallet
                                       FROM pallet_type_mixed
                                       WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type))))
                  OR
                  ((l_syspar_rec.v_pallet_type_flag = 'N') AND
                   (l.slot_type = l_loc_rec.v_slot_type)))))
         AND   l.cube >= l_pallet_size
         AND   NOT EXISTS (SELECT 1
                           FROM inv
                           WHERE plogi_loc = l.logi_loc)
         AND   z.zone_id = lz.zone_id
         AND   z.zone_type = 'PUT'
         AND   l.logi_loc = lz.logi_loc
         AND   z.zone_id = cp_zone_id
         ORDER BY ABS(l_loc_rec.n_put_aisle - l.put_aisle), l.put_aisle,
                  ABS(l_loc_rec.n_put_slot - l.put_slot), l.put_slot,
                  ABS(l_loc_rec.n_put_level - l.put_level), l.put_level,
                  l.cube;

      CURSOR c_get_deep_i_slots (cp_zone_id zone.zone_id%TYPE,
                                 cp_rule    VARCHAR2 DEFAULT 'B') IS
         SELECT DISTINCT l.logi_loc, l.available_height, l.put_aisle,
                l.put_slot, l.put_level
         FROM loc l, zone z, lzone lz, inv i
         WHERE l.status = 'AVL'
         AND   l.perm = 'N'
         AND   l.slot_type = l_loc_rec.v_slot_type
         AND   l.logi_loc = i.plogi_loc
         AND   i.prod_id = l_loc_rec.v_prod_id
         AND   i.cust_pref_vendor = l_loc_rec.v_cust_pref_vendor
         AND   i.qty_planned <> 0
         AND   (((cp_rule = 'B') AND
                 ((DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                   DECODE(lt_item_related_info_rec.v_pallet_type,
                         'FW', 'LW', lt_item_related_info_rec.v_pallet_type)) OR
                  (l.pallet_type IN (SELECT mixed_pallet
                                     FROM pallet_type_mixed
                                     WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type)))
                 AND
                 ((l_syspar_rec.v_mix_prod_bulk_area = 'Y') OR
                  ((l_syspar_rec.v_mix_prod_bulk_area = 'N') AND
                   (EXISTS (SELECT 1
                            FROM inv
                            WHERE prod_id <> l_loc_rec.v_prod_id
                            AND   cust_pref_vendor <>
                                     l_loc_rec.v_cust_pref_vendor
                            AND   plogi_loc = l.logi_loc)))))
                OR
                (cp_rule <> 'B'))
         AND   z.zone_id = lz.zone_id
         AND   z.zone_type = 'PUT'
         AND   l.logi_loc = lz.logi_loc
         AND   z.zone_id = cp_zone_id
         AND   ((l_syspar_rec.v_mix_prod_2d3d_flag = 'Y') OR
                ((l_syspar_rec.v_mix_prod_2d3d_flag = 'N') AND
                 (EXISTS (SELECT 1
                          FROM inv
                          WHERE prod_id <> l_loc_rec.v_prod_id
                          AND   cust_pref_vendor <> l_loc_rec.v_cust_pref_vendor
                          AND   plogi_loc = l.logi_loc))))
         AND   TRUNC(i.rec_date) =
                  TRUNC(DECODE(l_syspar_rec.v_g_mix_same_prod_deep_slot,
                               'Y', i.rec_date, SYSDATE))
         AND   l.available_height - l_pallet_size >=
                  (SELECT NVL(SUM((CEIL(((i2.qoh + i2.qty_planned) /
                                         lt_item_related_info_rec.n_spc) /
                                        lt_item_related_info_rec.n_ti)) *
                                  NVL(lt_item_related_info_rec.n_case_height,
                                      0) +
                                  NVL(lt_item_related_info_rec.n_skid_height,
                                      0)), 0)
                   FROM inv i2
                   WHERE i2.prod_id = l_loc_rec.v_prod_id
                   AND   i2.cust_pref_vendor = l_loc_rec.v_cust_pref_vendor
                   AND   i2.plogi_loc = l.logi_loc)
         GROUP BY l.logi_loc, l.available_height, l.put_aisle, l.put_slot,
                  l.put_level
         HAVING SUM(i.qty_planned) = 0
         ORDER BY l.available_height,
                  ABS(l_loc_rec.n_put_aisle - l.put_aisle), l.put_aisle,
                  ABS(l_loc_rec.n_put_slot - l.put_slot), l.put_slot,
                  ABS(l_loc_rec.n_put_level - l.put_level), l.put_level;

      CURSOR c_get_deep_i_empty_slots (cp_zone_id zone.zone_id%TYPE,
                                       cp_rule    VARCHAR2 DEFAULT 'B') IS
         SELECT l.logi_loc, l.cube, l.put_aisle,
                l.put_slot, l.put_level
         FROM loc l, zone z, lzone lz
         WHERE l.status = 'AVL'
         AND   l.perm = 'N'
         AND   l.slot_type = l_loc_rec.v_slot_type
         AND   (((cp_rule = 'B') AND
                 ((DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                   DECODE(lt_item_related_info_rec.v_pallet_type,
                         'FW', 'LW', lt_item_related_info_rec.v_pallet_type)) OR
                  (l.pallet_type IN (SELECT mixed_pallet
                                     FROM pallet_type_mixed
                                     WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type))))
                OR
                (cp_rule <> 'B'))
         AND   z.zone_id = lz.zone_id
         AND   z.zone_type = 'PUT'
         AND   l.logi_loc = lz.logi_loc
         AND   z.zone_id = cp_zone_id
         AND   NOT EXISTS (SELECT 1
                           FROM inv
                           WHERE plogi_loc = l.logi_loc)
         AND   l.available_height >= l_pallet_size
         ORDER BY ABS(l_loc_rec.n_put_aisle - l.put_aisle), l.put_aisle,
                  ABS(l_loc_rec.n_put_slot - l.put_slot), l.put_slot,
                  ABS(l_loc_rec.n_put_level - l.put_level), l.put_level,
                  l.available_height;

      CURSOR c_get_deep_c_slots (cp_zone_id zone.zone_id%TYPE,
                                 cp_rule    VARCHAR2 DEFAULT 'B') IS
         SELECT DISTINCT l.logi_loc, l.cube, l.put_aisle,
                l.put_slot, l.put_level
         FROM loc l, zone z, lzone lz, inv i
         WHERE l.status = 'AVL'
         AND   l.perm = 'N'
         AND   l.slot_type = l_loc_rec.v_slot_type
         AND   l.logi_loc = i.plogi_loc
         AND   i.prod_id = l_loc_rec.v_prod_id
         AND   i.cust_pref_vendor = l_loc_rec.v_cust_pref_vendor
         AND   i.qty_planned <> 0
         AND   (((cp_rule = 'B') AND
                 ((DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                   DECODE(lt_item_related_info_rec.v_pallet_type,
                         'FW', 'LW', lt_item_related_info_rec.v_pallet_type)) OR
                  (l.pallet_type IN (SELECT mixed_pallet
                                     FROM pallet_type_mixed
                                     WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type)))
                 AND
                 ((l_syspar_rec.v_mix_prod_bulk_area = 'Y') OR
                  ((l_syspar_rec.v_mix_prod_bulk_area = 'N') AND
                   (EXISTS (SELECT 1
                            FROM inv
                            WHERE prod_id <> l_loc_rec.v_prod_id
                            AND   cust_pref_vendor <>
                                     l_loc_rec.v_cust_pref_vendor
                            AND   plogi_loc = l.logi_loc)))))
                OR
                (cp_rule <> 'B'))
         AND   z.zone_id = lz.zone_id
         AND   z.zone_type = 'PUT'
         AND   l.logi_loc = lz.logi_loc
         AND   z.zone_id = cp_zone_id
         AND   ((l_syspar_rec.v_mix_prod_2d3d_flag = 'Y') OR
                ((l_syspar_rec.v_mix_prod_2d3d_flag = 'N') AND
                 (EXISTS (SELECT 1
                          FROM inv
                          WHERE prod_id <> l_loc_rec.v_prod_id
                          AND   cust_pref_vendor <> l_loc_rec.v_cust_pref_vendor
                          AND   plogi_loc = l.logi_loc))))
         AND   TRUNC(i.rec_date) =
                  TRUNC(DECODE(l_syspar_rec.v_g_mix_same_prod_deep_slot,
                               'Y', i.rec_date, SYSDATE))
         AND   l.cube - l_pallet_size >=
                  (SELECT NVL(SUM((CEIL(((i2.qoh + i2.qty_planned) /
                                        lt_item_related_info_rec.n_spc) /
                                        lt_item_related_info_rec.n_ti)) *
                                  NVL(lt_item_related_info_rec.n_case_cube, 0) +
                                  NVL(lt_item_related_info_rec.n_skid_cube, 0)),
                              0)
                   FROM inv i2
                   WHERE i2.prod_id = l_loc_rec.v_prod_id
                   AND   i2.cust_pref_vendor = l_loc_rec.v_cust_pref_vendor
                   AND   i2.plogi_loc = l.logi_loc)
         GROUP BY l.logi_loc, l.cube, l.put_aisle, l.put_slot, l.put_level
         HAVING SUM(i.qty_planned) = 0
         ORDER BY l.cube,
                  ABS(l_loc_rec.n_put_aisle - l.put_aisle), l.put_aisle,
                  ABS(l_loc_rec.n_put_slot - l.put_slot), l.put_slot,
                  ABS(l_loc_rec.n_put_level - l.put_level), l.put_level;

      CURSOR c_get_deep_c_empty_slots (cp_zone_id zone.zone_id%TYPE,
                                       cp_rule    VARCHAR2 DEFAULT 'B') IS
         SELECT DISTINCT l.logi_loc, l.cube, l.put_aisle,
                l.put_slot, l.put_level
         FROM loc l, zone z, lzone lz
         WHERE l.status = 'AVL'
         AND   l.perm = 'N'
         AND   l.slot_type = l_loc_rec.v_slot_type
         AND   (((cp_rule = 'B') AND
                 ((DECODE(l.pallet_type, 'FW', 'LW', l.pallet_type) =
                   DECODE(lt_item_related_info_rec.v_pallet_type,
                         'FW', 'LW', lt_item_related_info_rec.v_pallet_type)) OR
                  (l.pallet_type IN (SELECT mixed_pallet
                                     FROM pallet_type_mixed
                                     WHERE pallet_type =
                                      lt_item_related_info_rec.v_pallet_type))))
                OR
                (cp_rule <> 'B'))
         AND   z.zone_id = lz.zone_id
         AND   z.zone_type = 'PUT'
         AND   l.logi_loc = lz.logi_loc
         AND   z.zone_id = cp_zone_id
         AND   NOT EXISTS (SELECT 1
                           FROM inv
                           WHERE plogi_loc = l.logi_loc)
         AND   l.cube >= l_pallet_size
         ORDER BY ABS(l_loc_rec.n_put_aisle - l.put_aisle), l.put_aisle,
                  ABS(l_loc_rec.n_put_slot - l.put_slot), l.put_slot,
                  ABS(l_loc_rec.n_put_level - l.put_level), l.put_level,
                  l.cube;

         CURSOR c_get_next_zones(cp_zone_id zone.zone_id%TYPE) IS
            SELECT next_zone_id
            FROM next_zones
            WHERE zone_id = cp_zone_id
            ORDER BY sort ASC;

         CURSOR c_get_whousemove_area(cp_area
                                    whmveloc_area_xref.tmp_new_wh_area%TYPE) IS
            SELECT putback_wh_area
            FROM whmveloc_area_xref
            WHERE tmp_new_wh_area = cp_area;

   BEGIN
      o_status := 0;

      IF i_qty <=0 THEN
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_insufficient_qty);
         RETURN;
      END IF;

      -- Assume that the from slot is always a license plate (pallet_id)

      -- Get the front location of the from slot if available
      OPEN c_loc_type(i_from_loc);
      FETCH c_loc_type INTO l_loc_rec.v_loc_ref, l_loc_rec.v_logi_loc;
      IF c_loc_type%NOTFOUND THEN
         CLOSE c_loc_type;
         -- From slot might be a reserved or floating slot. Retrieve the item
         OPEN c_inv_info(i_from_loc);
         FETCH c_inv_info
            INTO l_loc_rec.v_prod_id, l_loc_rec.v_cust_pref_vendor,
                 l_loc_rec.v_logi_loc;
         IF c_inv_info%NOTFOUND THEN
            CLOSE c_inv_info;
            l_msg_text := 'Oracle Unable to Retrieve inv info for slot:
               '||i_from_loc || sqlcode || sqlerrm;
            pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
            i_num_of_locations := 0;
            o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_invalid_loc);
            RETURN;
         END IF;
         CLOSE c_inv_info;
         l_loc_rec.v_loc_ref := 'N';
      END IF;
      IF c_loc_type%ISOPEN THEN
         CLOSE c_loc_type;
      END IF;

      dbms_output.put_line('From: ' || i_from_loc || ', F/B: ' ||
         l_loc_rec.v_loc_ref || ', related: ' || l_loc_rec.v_logi_loc);

      -- Get location info
      OPEN c_loc_info(l_loc_rec.v_logi_loc,
                      l_loc_rec.v_loc_ref,
                      l_loc_rec.v_prod_id,
                      l_loc_rec.v_cust_pref_vendor);
      FETCH c_loc_info
         INTO l_loc_rec.v_loc_type, l_loc_rec.v_status,
              l_loc_rec.v_pallet_type, l_loc_rec.n_rank, l_loc_rec.n_uom,
              l_loc_rec.n_pik_aisle, l_loc_rec.n_pik_slot,
              l_loc_rec.n_pik_level,
              l_loc_rec.n_put_aisle, l_loc_rec.n_put_slot,
              l_loc_rec.n_put_level,
              l_loc_rec.n_cube, l_loc_rec.v_prod_id,
              l_loc_rec.v_cust_pref_vendor, l_loc_rec.v_slot_type,
              l_loc_rec.n_available_height, l_loc_rec.v_deep_ind,
              l_loc_rec.n_deep_positions, l_loc_rec.v_zone_id;
      IF c_loc_info%NOTFOUND THEN
         CLOSE c_loc_info;
         l_msg_text := 'Oracle Unable to Retrieve location info for slot:
            '||i_from_loc || sqlcode || sqlerrm;
         pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_invalid_loc);
         RETURN;
      END IF;
      CLOSE c_loc_info;

      dbms_output.put_line('Type: ' || l_loc_rec.v_loc_type ||
         ', rank: ' || TO_CHAR(l_loc_rec.n_rank) || ', u: ' ||
         TO_CHAR(l_loc_rec.n_uom) || ', paltype: ' ||
         l_loc_rec.v_pallet_type || ', slottype: ' ||
         l_loc_rec.v_slot_type ||
         ', path: ' || TO_CHAR(l_loc_rec.n_put_aisle) || '/' ||
         TO_CHAR(l_loc_rec.n_put_slot) || '/' ||
         TO_CHAR(l_loc_rec.n_put_level) || ', cube: ' ||
         TO_CHAR(l_loc_rec.n_cube) || ', item: ' || l_loc_rec.v_prod_id ||
         '/' || l_loc_rec.v_cust_pref_vendor || ', h: ' ||
         TO_CHAR(l_loc_rec.n_available_height) || ', deep: ' ||
         l_loc_rec.v_deep_ind || '/' ||
         TO_CHAR(l_loc_rec.n_deep_positions) || ', z: ' ||
         l_loc_rec.v_zone_id);

      -- If from slot is a reserved, try to retrieve the location info of its
      -- front rank 1 case home
      l_home := NULL;
      IF l_loc_rec.v_loc_type IN ('R', 'B') THEN
         OPEN c_get_home(l_loc_rec.v_prod_id, l_loc_rec.v_cust_pref_vendor);
         FETCH c_get_home INTO l_home;
         IF c_get_home%NOTFOUND THEN
            -- There is no home for the item. The item might be in bulk pull
            -- zone as a floating slot (strange setup because it shouldn't be)
            l_msg_text := 'Oracle Unable to Retrieve home slot for slot: ' ||
               l_loc_rec.v_logi_loc || '/' || i_from_loc ||
               '. Will try to find slots nearest to the from slot.';
            pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
            dbms_output.put_line(l_msg_text);
         ELSE
            IF l_loc_rec.v_logi_loc <> l_home THEN
               -- Found the home of the from slot (as reserved)
               l_loc_rec.v_logi_loc := l_home;
               CLOSE c_get_home;
               -- Reload the location info for the found home slot
               l_loc_rec.v_loc_ref := 'F';
               OPEN c_loc_info(l_loc_rec.v_logi_loc,
                               l_loc_rec.v_loc_ref,
                               l_loc_rec.v_prod_id,
                               l_loc_rec.v_cust_pref_vendor);
               FETCH c_loc_info
                  INTO l_loc_rec.v_loc_type, l_loc_rec.v_status,
                       l_loc_rec.v_pallet_type, l_loc_rec.n_rank,
                       l_loc_rec.n_uom,
                       l_loc_rec.n_pik_aisle, l_loc_rec.n_pik_slot,
                       l_loc_rec.n_pik_level,
                       l_loc_rec.n_put_aisle, l_loc_rec.n_put_slot,
                       l_loc_rec.n_put_level,
                       l_loc_rec.n_cube, l_loc_rec.v_prod_id,
                       l_loc_rec.v_cust_pref_vendor, l_loc_rec.v_slot_type,
                       l_loc_rec.n_available_height, l_loc_rec.v_deep_ind,
                       l_loc_rec.n_deep_positions, l_loc_rec.v_zone_id;
               IF c_loc_info%NOTFOUND THEN
                  CLOSE c_loc_info;
                  l_msg_text := 'Oracle Unable to Retrieve location info for' ||
                     ' slot (2nd time): '||i_from_loc || sqlcode || sqlerrm;
                  pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
                  i_num_of_locations := 0;
                  o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_invalid_loc);
                  RETURN;
               END IF;
               CLOSE c_loc_info;
               dbms_output.put_line('The home slot is ' ||
                  l_loc_rec.v_logi_loc || ' for from slot ' || i_from_loc);
            END IF;
         END IF;
         IF c_get_home%ISOPEN THEN
            CLOSE c_get_home;
         END IF;
      END IF;

      --Retrieve all item related info.
      BEGIN
         pl_putaway_utilities.p_get_item_info(
            l_loc_rec.v_prod_id, l_loc_rec.v_cust_pref_vendor,
            lt_item_related_info_rec);
      EXCEPTION
         WHEN OTHERS THEN
            i_num_of_locations := 0;
            o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_database_error);
            RETURN;
      END;

      dbms_output.put_line('Item paltype: ' ||
         lt_item_related_info_rec.v_pallet_type || ', spc: ' ||
         TO_CHAR(lt_item_related_info_rec.n_spc) || ', case c/h: ' ||
         TO_CHAR(lt_item_related_info_rec.n_case_cube) || '/' ||
         TO_CHAR(lt_item_related_info_rec.n_case_height) || ', z: ' ||
         l_loc_rec.v_zone_id || ', skid c/h: ' ||
         TO_CHAR(lt_item_related_info_rec.n_skid_cube) || '/' ||
         TO_CHAR(lt_item_related_info_rec.n_skid_height) || ', ti/hi: ' ||
         TO_CHAR(lt_item_related_info_rec.n_ti) || '/' ||
         TO_CHAR(lt_item_related_info_rec.n_hi) || ', # nxz: ' ||
         TO_CHAR(lt_item_related_info_rec.n_num_next_zones) ||
         ', last: ' || lt_item_related_info_rec.v_last_ship_slot);

      --Retrieve SYSPAR values
      l_syspar_rec.v_pallet_type_flag :=
         pl_common.f_get_syspar('PALLET_TYPE_FLAG');
      IF l_syspar_rec.v_pallet_type_flag IS NULL THEN
         l_msg_text := 'Oracle;Unable to retrieve SYSPAR PALLET_TYPE_FLAG';
         pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         RETURN;
      END IF;
      l_sys_put_dim_flag := pl_common.f_get_syspar('PUTAWAY_DIMENSION');
      IF l_sys_put_dim_flag IS NULL THEN
         l_msg_text := 'Oracle;Unable to retrieve SYSPAR PUTAWAY_DIMENSION';
         pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         RETURN;
      END IF;
      l_syspar_rec.v_mix_prod_2d3d_flag :=
         pl_common.f_get_syspar('MIXPROD_2D3D_FLAG');
      IF l_syspar_rec.v_mix_prod_2d3d_flag IS NULL THEN
         l_msg_text := 'Oracle;Unable to retrieve SYSPAR MIXPROD_2D3D_FLAG';
         pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         RETURN;
      END IF;
      l_syspar_rec.v_g_mix_same_prod_deep_slot :=
         pl_common.f_get_syspar('MIX_SAME_PROD_DEEP_SLOT');
      IF l_syspar_rec.v_g_mix_same_prod_deep_slot IS NULL THEN
         l_msg_text :=
            'Oracle;Unable to retrieve SYSPAR MIX_SAME_PROD_DEEP_SLOT';
         pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         RETURN;
      END IF;
      l_syspar_rec.v_mix_prod_bulk_area :=
         pl_common.f_get_syspar('MIX_PROD_BULK_AREA');
      IF l_syspar_rec.v_mix_prod_bulk_area IS NULL THEN
         l_msg_text := 'Oracle;Unable to retrieve SYSPAR MIX_PROD_BULK_AREA';
         pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         RETURN;
      END IF;

      dbms_output.put_line('Ext_case_cube: ' ||
         lt_item_related_info_rec.v_ext_case_cube_flag || ', dim: ' ||
         l_sys_put_dim_flag || ', pallet_type_flag: ' ||
         l_syspar_rec.v_pallet_type_flag || ', mix_prod_2d3d: ' ||
         l_syspar_rec.v_mix_prod_2d3d_flag || ', mix_prod_bulk_area: ' ||
         l_syspar_rec.v_mix_prod_bulk_area || ', mix_same_prod_deep: ' ||
         l_syspar_rec.v_g_mix_same_prod_deep_slot);

      -- Do some basic but will-be fatal checkings
      IF  NVL(lt_item_related_info_rec.n_spc,0) <=0 OR
          NVL(lt_item_related_info_rec.n_ti,0)<=0 THEN
         l_msg_text := 'Oracle;Unable to retrieve valid item info';
         pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
         o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         RETURN;
      END IF;
      IF l_sys_put_dim_flag = 'I' AND
         (NVL(lt_item_related_info_rec.n_case_height,0) <=0 OR
          NVL(lt_item_related_info_rec.n_skid_height,0) < 0) THEN
         l_msg_text := 'Oracle;Unable to retrieve valid item info';
        pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
        o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
         RETURN;
      END IF;
      IF l_sys_put_dim_flag = 'C' AND
         (NVL(lt_item_related_info_rec.n_case_cube,0) <=0 OR
          NVL(lt_item_related_info_rec.n_skid_cube,0) < 0) THEN
        l_msg_text := 'Oracle;Unable to retrieve valid item info';
        pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
         i_num_of_locations := 0;
        o_status := pl_exc.f_get_rf_errcode(pl_exc.ct_data_not_found);
        RETURN;
      END IF;

      IF l_sys_put_dim_flag = 'C' THEN
         -- Recalculate case cube if extended case cube is used
         IF lt_item_related_info_rec.v_ext_case_cube_flag = 'Y' AND
            l_loc_rec.v_loc_type = 'H' THEN
            lt_item_related_info_rec.n_case_cube :=
               ((NVL(l_loc_rec.n_cube, 0) / NVL(l_loc_rec.n_deep_positions,1)) -
                NVL(lt_item_related_info_rec.n_skid_cube, 0)) /
                (lt_item_related_info_rec.n_ti *
                 lt_item_related_info_rec.n_hi);
         END IF;
         IF lt_item_related_info_rec.v_ext_case_cube_flag = 'Y' THEN
            dbms_output.put_line('New case cube: ' ||
               TO_CHAR(lt_item_related_info_rec.n_case_cube));
         END IF;
         l_pallet_size := ROUND(((CEIL((i_qty /
                                        lt_item_related_info_rec.n_spc) /
                                       lt_item_related_info_rec.n_ti) *
                                  lt_item_related_info_rec.n_ti) *
                                 NVL(lt_item_related_info_rec.n_case_cube, 0)) +
                                NVL(lt_item_related_info_rec.n_skid_cube, 0),
                                2);
      END IF;

      IF l_sys_put_dim_flag = 'I' THEN
         l_pallet_size := ROUND((CEIL((i_qty /
                                        lt_item_related_info_rec.n_spc) /
                                       lt_item_related_info_rec.n_ti) *
                                  NVL(lt_item_related_info_rec.n_case_height,
                                      0)) +
                                 NVL(lt_item_related_info_rec.n_skid_height,
                                     0),
                                1);
      END IF;

      dbms_output.put_line('Pallet size: ' || TO_CHAR(l_pallet_size));

      l_num_recs := 1;
      IF l_loc_rec.v_deep_ind = 'Y' THEN
         IF l_sys_put_dim_flag = 'I' THEN
            FOR c_i_deep IN c_get_deep_i_slots(l_loc_rec.v_zone_id,
                                               l_loc_rec.v_loc_type) LOOP
               o_suitable_locations(l_num_recs) :=
                  c_i_deep.logi_loc;
               dbms_output.put_line('ideep: ' || TO_CHAR(l_num_recs) ||
                  ', ' || c_i_deep.logi_loc);
               l_num_recs := l_num_recs + 1;
               EXIT WHEN l_num_recs > i_num_of_locations;
            END LOOP;
            IF l_num_recs < i_num_of_locations THEN
               FOR c_i_edeep IN c_get_deep_i_empty_slots(l_loc_rec.v_zone_id,
                                                      l_loc_rec.v_loc_type) LOOP
                  o_suitable_locations(l_num_recs) :=
                     c_i_edeep.logi_loc;
                  dbms_output.put_line('iedeep: ' || TO_CHAR(l_num_recs) ||
                     ', ' || c_i_edeep.logi_loc);
                  l_num_recs := l_num_recs + 1;
                  EXIT WHEN l_num_recs > i_num_of_locations;
               END LOOP;
            END IF;
         ELSIF l_sys_put_dim_flag = 'C' THEN
            FOR c_c_deep IN c_get_deep_c_slots(l_loc_rec.v_zone_id,
                                               l_loc_rec.v_loc_type) LOOP
               o_suitable_locations(l_num_recs) :=
                  c_c_deep.logi_loc;
               dbms_output.put_line('cdeep: ' || TO_CHAR(l_num_recs) ||
                  ', ' || c_c_deep.logi_loc);
               l_num_recs := l_num_recs + 1;
               EXIT WHEN l_num_recs > i_num_of_locations;
            END LOOP;
            IF l_num_recs < i_num_of_locations THEN
               FOR c_c_edeep IN c_get_deep_c_empty_slots(l_loc_rec.v_zone_id,
                                                      l_loc_rec.v_loc_type) LOOP
                  o_suitable_locations(l_num_recs) :=
                     c_c_edeep.logi_loc;
                  dbms_output.put_line('cedeep: ' || TO_CHAR(l_num_recs) ||
                     ', ' || c_c_edeep.logi_loc);
                  l_num_recs := l_num_recs + 1;
                  EXIT WHEN l_num_recs > i_num_of_locations;
               END LOOP;
            END IF;
         END IF;
      ELSE
         IF l_sys_put_dim_flag = 'I' THEN
            FOR c_i_nondeep IN c_get_nondeep_i_slots(l_loc_rec.v_zone_id,
                                                   l_loc_rec.v_loc_type) LOOP
               o_suitable_locations(l_num_recs) :=
                  c_i_nondeep.logi_loc;
               dbms_output.put_line('inondeep: ' || TO_CHAR(l_num_recs) ||
                  ', ' || c_i_nondeep.logi_loc);
               l_num_recs := l_num_recs + 1;
               EXIT WHEN l_num_recs > i_num_of_locations;
            END LOOP;
         ELSIF l_sys_put_dim_flag = 'C' THEN
            FOR c_c_nondeep IN c_get_nondeep_c_slots(l_loc_rec.v_zone_id,
                                                   l_loc_rec.v_loc_type) LOOP
               o_suitable_locations(l_num_recs) :=
                  c_c_nondeep.logi_loc;
               dbms_output.put_line('cnondeep: ' || TO_CHAR(l_num_recs) ||
                  ', ' || c_c_nondeep.logi_loc);
               l_num_recs := l_num_recs + 1;
               EXIT WHEN l_num_recs > i_num_of_locations;
            END LOOP;
         END IF;
      END IF;

      -- Doing warehouse move transfer. Need to substitute the old area back
      IF i_whousemove = 'W' THEN
         OPEN c_get_whousemove_area(SUBSTR(l_loc_rec.v_logi_loc, 1, 1));
         FETCH c_get_whousemove_area INTO l_putback_wh_area;
         IF c_get_whousemove_area%NOTFOUND THEN
            l_msg_text := 'Oracle;Unable to retrieve putback_wh_area for ' ||
               i_from_loc;
        pl_log.ins_msg('WARN', l_object_name, l_msg_text, NULL, sqlerrm);
            l_putback_wh_area := SUBSTR(l_loc_rec.v_logi_loc, 1, 1);
         END IF;
         CLOSE c_get_whousemove_area;
      END IF;

      l_num_item_next_zone := 0;
      FOR c_next_zone IN c_get_next_zones(l_loc_rec.v_zone_id) LOOP
         l_num_item_next_zone := l_num_item_next_zone + 1;
      END LOOP;
      dbms_output.put_line('# of next zones for zone ' || l_loc_rec.v_zone_id ||
         ': ' || TO_CHAR(l_num_item_next_zone));

      IF (l_num_recs > i_num_of_locations) OR
         ((l_num_recs <= i_num_of_locations) AND
          (lt_item_related_info_rec.n_num_next_zones = 0)) OR
         (l_num_item_next_zone = 0) THEN
         -- Maximum # of requested locations reached, or, if not yet, there
         -- is no more next zone for the item after the 1st run
         IF i_whousemove = 'W' THEN
            FOR l_index IN 1..l_num_recs - 1 LOOP
               o_suitable_locations(l_index) := l_putback_wh_area ||
                  SUBSTR(o_suitable_locations(l_index), 2);
            END LOOP;
         END IF;
         i_num_of_locations := l_num_recs - 1;
         RETURN;
      END IF;

      dbms_output.put_line('Search next zone # of locs found so far: ' ||
         TO_CHAR(l_num_recs - 1));

      -- Go to item's next zone until the maximum requested locations
      -- reached or no more next zone
      l_zone_index := 0;
      FOR c_next_zone IN c_get_next_zones(l_loc_rec.v_zone_id) LOOP
         IF l_loc_rec.v_deep_ind = 'Y' THEN
            IF l_sys_put_dim_flag = 'I' THEN
               FOR c_i_deep IN c_get_deep_i_slots(c_next_zone.next_zone_id,
                                                  l_loc_rec.v_loc_type) LOOP
                  o_suitable_locations(l_num_recs) :=
                     c_i_deep.logi_loc;
                  dbms_output.put_line('next zone ideep: ' ||
                     TO_CHAR(l_num_recs) || ', ' || c_i_deep.logi_loc);
                  l_num_recs := l_num_recs + 1;
                  EXIT WHEN l_num_recs > i_num_of_locations;
               END LOOP;
               IF l_num_recs < i_num_of_locations THEN
                  FOR c_i_edeep IN c_get_deep_i_empty_slots(
                     c_next_zone.next_zone_id, l_loc_rec.v_loc_type) LOOP
                     o_suitable_locations(l_num_recs) :=
                        c_i_edeep.logi_loc;
                     dbms_output.put_line('next zone iedeep: ' ||
                        TO_CHAR(l_num_recs) || ', ' || c_i_edeep.logi_loc);
                     l_num_recs := l_num_recs + 1;
                     EXIT WHEN l_num_recs > i_num_of_locations;
                  END LOOP;
               END IF;
            ELSIF l_sys_put_dim_flag = 'C' THEN
               FOR c_c_deep IN c_get_deep_c_slots(c_next_zone.next_zone_id,
                                                  l_loc_rec.v_loc_type) LOOP
                  o_suitable_locations(l_num_recs) :=
                     c_c_deep.logi_loc;
                  dbms_output.put_line('next zone cdeep: ' ||
                     TO_CHAR(l_num_recs) || ', ' || c_c_deep.logi_loc);
                  l_num_recs := l_num_recs + 1;
                  EXIT WHEN l_num_recs > i_num_of_locations;
               END LOOP;
               IF l_num_recs < i_num_of_locations THEN
                  FOR c_c_edeep IN c_get_deep_c_empty_slots(
                     c_next_zone.next_zone_id, l_loc_rec.v_loc_type) LOOP
                     o_suitable_locations(l_num_recs) :=
                        c_c_edeep.logi_loc;
                     dbms_output.put_line('next zone cedeep: ' ||
                        TO_CHAR(l_num_recs) || ', ' || c_c_edeep.logi_loc);
                     l_num_recs := l_num_recs + 1;
                     EXIT WHEN l_num_recs > i_num_of_locations;
                  END LOOP;
               END IF;
            END IF;
         ELSE
            IF l_sys_put_dim_flag = 'I' THEN
               FOR c_i_nondeep IN c_get_nondeep_i_slots(
                  c_next_zone.next_zone_id, l_loc_rec.v_loc_type) LOOP
                  o_suitable_locations(l_num_recs) :=
                     c_i_nondeep.logi_loc;
                  dbms_output.put_line('next zone inondeep: ' ||
                     TO_CHAR(l_num_recs) || ', ' || c_i_nondeep.logi_loc);
                  l_num_recs := l_num_recs + 1;
                  EXIT WHEN l_num_recs > i_num_of_locations;
               END LOOP;
            ELSIF l_sys_put_dim_flag = 'C' THEN
               FOR c_c_nondeep IN c_get_nondeep_c_slots(
                  c_next_zone.next_zone_id, l_loc_rec.v_loc_type) LOOP
                  o_suitable_locations(l_num_recs) :=
                     c_c_nondeep.logi_loc;
                  dbms_output.put_line('next zone cnondeep: ' ||
                     TO_CHAR(l_num_recs) || ', ' || c_c_nondeep.logi_loc);
                  l_num_recs := l_num_recs + 1;
                  EXIT WHEN l_num_recs > i_num_of_locations;
               END LOOP;
            END IF;
         END IF;

         dbms_output.put_line('Next zone: ' || c_next_zone.next_zone_id ||
            ', # of locs found so far: ' || TO_CHAR(l_num_recs - 1));

         l_zone_index := l_zone_index + 1;
         EXIT WHEN l_num_recs > i_num_of_locations;
         EXIT WHEN l_zone_index >= lt_item_related_info_rec.n_num_next_zones;
      END LOOP;

      IF i_whousemove = 'W' THEN
         FOR l_index IN 1..l_num_recs - 1 LOOP
            o_suitable_locations(l_index) := l_putback_wh_area ||
               SUBSTR(o_suitable_locations(l_index), 2);
         END LOOP;
      END IF;
      i_num_of_locations := l_num_recs - 1;
   EXCEPTION
      WHEN OTHERS THEN
          o_status := 999;
          RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
   END p_find_xfr_slots;

/*-----------------------------------------------------------------------
    -- Procedure:
    --    p_is_loc_zone_restrict
    --
    -- Description:
    -- This procedure returns zone and code_name restriction for a given location's zone
    --
    -- Parameters:
	--    p_loc_id                pass in a location
    --    p_zone_id                - give out zone id of a given location
    --
    --    P_restrict_name - give out code_name_retriction on a zone
    --
 ---------------------------------------------------------------------*/
 Procedure p_is_loc_zone_restrict(p_loc_id IN LOC.LOGI_LOC%TYPE,
                                  p_zone_id OUT  Zone.Zone_id%TYPE,
                                  p_restrict_name OUT  swms_maint_lookup.code_name%TYPE)
 IS
  l_zone_id VARCHAR2(50);
	l_restrict_name VARCHAR2(50);
    
 BEGIN
    Begin
	    SELECT ZONE.ZONE_ID, ZONE.code_name_restrict 
		INTO p_zone_id,p_restrict_name 
		FROM   LOC, LZONE, ZONE
        WHERE  1=1
         AND  LOC.LOGI_LOC = p_loc_id
         AND  LZONE.LOGI_LOC = LOC.LOGI_LOC
         AND  LZONE.ZONE_ID  = ZONE.ZONE_ID
         AND  ZONE.ZONE_TYPE = 'PUT';
	
			   
	Exception 
    when no_data_found then  -- no entry is found for the given Location 
	
           Null;
		   
     when others then 
	
	   Null; -- no entry is found for the given Location 
   End;  
 End p_is_loc_zone_restrict;

 /*-----------------------------------------------------------------------
    -- Function:
    --    F_Retrieve_Aging_Items
    --
    -- Description:
    -- This function retrieves the no. of aging days for any item
    --
    -- Parameters:
    --    i_product_id                - product id of the item for which
                                        details are fetched
    --
    --    i_cust_pref_vendor - customer preferred vendor for the
                                        selected product
    --
 ---------------------------------------------------------------------*/
 FUNCTION f_retrieve_aging_items(i_product_id     IN  pm.prod_id%TYPE,
                               i_cust_pref_vendor IN  pm.cust_pref_vendor%TYPE)
 RETURN NUMBER
 IS
    ln_aging_days NUMBER;
    lv_pname      VARCHAR2(30);
 BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
    lv_pname := 'f_retrieve_aging_items';
    --This will be used in the Exception message in assign putaway
    pl_putaway_utilities.gv_program_name := lv_pname;

    ln_aging_days := -1;--initialise with no aging value
    BEGIN
       SELECT NVL(aging_days, 0) INTO ln_aging_days
         FROM aging_items
        WHERE prod_id = i_product_id
          AND   cust_pref_vendor = i_cust_pref_vendor;
       IF ln_aging_days = 0 THEN
          --commented for testing
          pl_log.ins_msg ('INFO', 'F_Retrieve_Aging_Items',
                          'aging days = 0. Treat as no aging needed', NULL, '');
          ln_aging_days := -1;
       END IF;
       RETURN ln_aging_days;
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          BEGIN
              --commented for testing
              pl_log.ins_msg ('INFO', 'F_Retrieve_Aging_Items',
                              'ORACLE failed to select AGING_ITEMS',
                              NULL, SQLERRM);

              ln_aging_days := -1;
              RETURN ln_aging_days;
          END;
    END;
 END f_retrieve_aging_items ;
 /*-----------------------------------------------------------------------
-- Function:
--    f_ check_home_item
--
-- Description:
-- This function determines if there are slots to attempt to assign
-- the item to.
--
-- Parameters:
--    i_item_related_info_rec     - Item info record.
--
-- RETURN VALUES:
--   TRUE for the following:
--        - The item has a home slot for cases (uom = 0 or 2).
--        - The item does not have a home slot but has a putaway zone
--          and last ship slot and both are valid and the rule id for the
--          putaway zone is 1 (the item is a floating item).
--        - The item does not have a home slot but has a putaway zone
--          and no last ship slot and the putaway zone is valid and
--          the rule id for the putaway zone is 1 (the item is a
--          floating item).
--        - If no. of days > 0, no matter what kind of location the
--          item has.
--   FALSE if the above is not met.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/08/06 prpbcb   WAI changes.
--                      Modifications to handle rule id 3.
--    09/26/14 prpbcb   Changed argument to the item record and not
--                      individual fields.
-------------------------------------------------------------------------*/
FUNCTION f_check_home_item(i_item_related_info_rec  IN OUT t_item_related_info)
/***
FUNCTION f_check_home_item (i_product_id       IN  pm.prod_id%TYPE,
                            i_cust_pref_vendor IN  pm.cust_pref_vendor%TYPE,
                            i_aging_days       IN  NUMBER,
                            i_zone_id          IN  zone.zone_id%TYPE,
                            i_last_ship_slot   IN  pm.last_ship_slot%TYPE)
****/
RETURN BOOLEAN
IS
   ln_rule_id        NUMBER;
   lb_message_logged BOOLEAN;
   lb_home_item      BOOLEAN;
   lv_fname          VARCHAR2(30) := 'f_check_home_item';
   lv_logi_loc       VARCHAR(10);
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_PUTAWAY_UTILITIES';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   lb_home_item := FALSE;
   ln_rule_id := -1;

   IF  (i_item_related_info_rec.aging_days > 0) THEN
      lb_home_item := TRUE;
      RETURN lb_home_item;
   END IF;

   IF (i_item_related_info_rec.v_mx_item_assign_flag = 'Y') THEN
      IF i_item_related_info_rec.v_zone_id IS NULL THEN
         SELECT zone_id INTO i_item_related_info_rec.v_zone_id
           FROM zone
          WHERE rule_id = 5
            AND zone_type = 'PUT';
      END IF;

      lb_home_item := TRUE;-- this happens only when select statement succeeds
      RETURN lb_home_item;
   END IF;

   SELECT l.logi_loc INTO lv_logi_loc
     FROM loc l
    WHERE l.uom              IN (0, 2)
      AND l.rank             = 1
      AND l.prod_id          = i_item_related_info_rec.prod_id
      AND l.cust_pref_vendor = i_item_related_info_rec.cust_pref_vendor;

   lb_home_item := TRUE;-- this happens only when select statement succeeds
                         -- else the control goes to exception block
   RETURN lb_home_item;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      BEGIN
         lb_message_logged := FALSE;

         --select the rule id based on primary putaway zone and last ship slot
         --if the rule id is 1 then floating item, no home slot needed
         IF (    i_item_related_info_rec.v_zone_id        IS NOT NULL
             AND i_item_related_info_rec.v_last_ship_slot IS NOT NULL)
         THEN
            BEGIN
               SELECT rule_id INTO ln_rule_id
                 FROM zone z, lzone lz
                WHERE z.zone_id = lz.zone_id
                  AND lz.zone_id = i_item_related_info_rec.v_zone_id
                  AND lz.logi_loc = i_item_related_info_rec.v_last_ship_slot;
            EXCEPTION
               WHEN OTHERS THEN
                  SELECT rule_id INTO ln_rule_id
                    FROM zone
                   WHERE zone_id = i_item_related_info_rec.v_zone_id;
            END;
         ELSIF (i_item_related_info_rec.v_zone_id IS NOT NULL) THEN
            SELECT rule_id INTO ln_rule_id
              FROM zone
             WHERE zone_id = i_item_related_info_rec.v_zone_id;
          END IF;

          IF ln_rule_id IN (1, 3) THEN
             lb_home_item := TRUE;
          ELSE
             lb_home_item := FALSE;
          END IF;

          IF lb_home_item = FALSE THEN

             pl_log.ins_msg ('WARN', 'F_Check_home_item',
                              'Unable to find home slot for non-floating item',
                              NULL, SQLERRM);

             lb_message_logged := TRUE;
          END IF;
          RETURN lb_home_item;
       EXCEPTION
          WHEN OTHERS THEN
          BEGIN
            -- if failed to select rule id then return false
            IF lb_message_logged = FALSE THEN

                pl_log.ins_msg ('WARN', 'F_Check_home_item',
                                'Unable to find home slot for non-floating item.',
                                NULL, SQLERRM);

             END IF;
             lb_home_item := FALSE;
             RETURN lb_home_item;
          END;
       END;
END f_check_home_item;



/*-----------------------------------------------------------------------
    -- Function:
    --    f_get_HST_prompt
    --
    -- Description:
    -- This function retrieves the prompts for Auto Home Slot Transfer
    --
    -- Parameters:
    --   i_option IN CHAR
    --   i_repltype IN CHAR                         D or N for repl type
    --   i_location IN loc.logi_loc%TYPE
    --   i_qty IN NUMBER                            IN SPLITS
    -- RETURN VALUES:
    --
    -- 04/30/03 prphqb  Change to use max_qty rather than min_qty
    -- 07/22/03 prphqb  Change to handle back location as input
    -- 07/29/05 acppsp  Changes for DMD replenishment.
 ---------------------------------------------------------------------*/

FUNCTION f_get_HST_prompt
        (i_option IN CHAR,
        i_repltype IN CHAR,
        i2_location IN loc.logi_loc%TYPE,
        i_qty IN NUMBER,
        i_task_id IN NUMBER DEFAULT NULL)
RETURN VARCHAR2 IS
l_prompt             VARCHAR2(1) := 'N';
i_location           VARCHAR(10);
/*acppsp: DN#11974: Changes related to DMD replenishment for CF.*/
i_max_qty            NUMBER; /*MAX_QTY in splits */
i_order_qty          float_detail.qty_order%TYPE; /* Ordered Qty in splits */
   /* if input is back, find the front since only it has INV record */
BEGIN
      BEGIN
        SELECT plogi_loc INTO i_location    /* if input is back */
        FROM   loc_reference
        WHERE  bck_logi_loc = i2_location;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           SELECT i2_location into i_location FROM DUAL;
      END;
      IF (i_option = 'P' ) THEN
                  SELECT DECODE( sign(i_qty - p.spc * p.ti * p.hi),
                        -1, pt.putaway_pp_prompt_for_hst_qty,
                        pt.putaway_fp_prompt_for_hst_qty)
                  INTO l_prompt
                  FROM pm p, loc l, pallet_type pt
                  WHERE p.prod_id = l.prod_id
                  AND   p.cust_pref_vendor  = l.cust_pref_vendor
                  AND   l.logi_loc = i_location
                  AND   l.pallet_type = pt.pallet_type;
      ELSIF (i_option = 'R' ) THEN

                  /*acppsp: DN#11974:START: Changes related to DMD replenishment for CF.*/
                  IF (i_repltype = 'D') THEN

                    SELECT pt.dmd_repl_prompt_for_hst_qty,
                           DECODE(p.max_qty,0,p.ti * p.hi,NULL,p.ti * p.hi,p.max_qty) * spc
                      INTO l_prompt,i_max_qty
                      FROM pm p, loc l, pallet_type pt
                     WHERE p.prod_id = l.prod_id
                       AND p.cust_pref_vendor  = l.cust_pref_vendor
                       AND l.logi_loc = i_location
                       AND l.pallet_type = pt.pallet_type;

                  ELSE
                  /*acppsp: DN#11974:END: Changes related to DMD replenishment for CF.*/
                      SELECT pt.ndm_repl_prompt_for_hst_qty
                      INTO l_prompt
                      FROM pm p, loc l, pallet_type pt
                      WHERE p.prod_id = l.prod_id
                      AND   p.cust_pref_vendor  = l.cust_pref_vendor
                      AND   l.logi_loc = i_location
                      AND   l.pallet_type = pt.pallet_type;

                  END IF;
      END IF;

      /* acppsp: DN#11974:START: Changes related to DMD replenishment for CF.
      ** check the replen_type.
      ** if the replen_type is DMD then
      ** syspar is "A": set the prompt to 'Y'
      ** syspar is 'N': set the prompt to 'N'
      ** syspar is 'Y': apply following logic
      **                if MAX_qty i.e.max_qty < qoh + qty_ordered
      **                         set prompt to 'Y'
      **                else
      **                         set prompt to 'N'
      */

      IF (i_repltype = 'D') THEN

          IF (l_prompt = 'A' ) THEN
            l_prompt := 'Y';
          ELSIF (l_prompt = 'Y') THEN
            /*Retrieve the QTY_Ordered from the float_detail table */
            BEGIN
                SELECT fd.qty_order
                  INTO i_order_qty
                  FROM replenlst r, float_detail fd
                 WHERE r.task_id = i_task_id
                   AND r.float_no = fd.float_no;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                i_order_qty := 0;
            END;
            IF i_max_qty < (i_qty + i_order_qty) THEN
               l_prompt := 'Y';
            ELSE
               l_prompt := 'N';
            END IF;

          ELSE
            l_prompt := 'N';
          END IF;

      ELSE

          IF ( l_prompt = 'Y' ) THEN
            SELECT DECODE(sign(
                                   DECODE(p.max_qty,
                                          0,   p.ti * p.hi,
                                          NULL,p.ti * p.hi,
                                          p.max_qty) * spc
                                  - qoh),-1,'Y','N')
                INTO  l_prompt
            FROM  pm p, inv i
            WHERE p.prod_id = i.prod_id
            AND   p.cust_pref_vendor  = i.cust_pref_vendor
            AND   i.logi_loc = i_location;
          END IF;

      END IF;
      /*acppsp: DN#11974:END: Changes related to DMD replenishment for CF.*/
      return l_prompt;

   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_prompt := 'N';
         return l_prompt;
END;

---------------------------------------------------------------------------
-- Function:
--    f_is_pallet_in_pit_location
-- 
-- Description:
--    This function checks to see if this pallet is in a PIT location
--    (a location in a zone with rule 11) and returns Y or N.
---------------------------------------------------------------------------
FUNCTION f_is_pallet_in_pit_location (i_pallet_id IN putawaylst.pallet_id%TYPE)
RETURN CHAR
IS

   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'f_is_pallet_in_pit_location';
   l_rec_id        trans.rec_id%TYPE;
   l_current_loc   trans.dest_loc%TYPE; -- The location of the pallet in the putawaylst.
   l_pit_loc_count         NUMBER := 0;

BEGIN

   SELECT rec_id, dest_loc
   INTO l_rec_id, l_current_loc
   FROM trans
   WHERE pallet_id = i_pallet_id
   AND trans_type = 'PUT'
   AND rownum = 1;

   IF pl_common.f_is_internal_production_po(l_rec_id) = FALSE THEN
      RETURN 'N';
   END IF;

   SELECT count(1)
   INTO l_pit_loc_count
   FROM lzone lz, zone z
   WHERE lz.zone_id = z.zone_id
   AND z.rule_id = 11
   AND z.zone_type = 'PUT'
   AND lz.logi_loc = l_current_loc;

   IF l_pit_loc_count > 0 THEN
      RETURN 'Y';
   ELSE
      RETURN 'N';
   END IF;
   
EXCEPTION 
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(i_pallet_id)'
         || '  i_pallet_id[' || i_pallet_id || ']';

      pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
      RETURN 'N';

END f_is_pallet_in_pit_location;


---------------------------------------------------------------------------
-- Function:
--    f_check_pit_location
-- 
-- Description:
--    This function checks to see if the location is in a pit zone
---------------------------------------------------------------------------
FUNCTION f_check_pit_location (i_location IN loc.logi_loc%TYPE)
RETURN CHAR
IS
   l_count NUMBER := 0;
BEGIN

   SELECT count(1)
   INTO l_count
   FROM lzone lz, zone z
   WHERE lz.zone_id = z.zone_id
   AND z.rule_id = 11
   AND z.zone_type = 'PUT'
   AND lz.logi_loc = i_location;

   IF l_count > 0 THEN
      return 'Y';
   ELSE
      return 'N';
   END IF;

END f_check_pit_location;

/* ---------------------------------------------------------------- */

BEGIN
  --this is used for initialising global variables once
  --global variables set for logging the errors in swms_log table

     pl_log.g_application_func := 'RECEIVING AND PUTAWAY';

END pl_putaway_utilities;
/



