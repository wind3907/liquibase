 
SET DOC OFF;

PROMPT Create package specification: pl_lm_ds

/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_lm_ds
AS

   -- sccs_id=@(#) src/schema/plsql/pl_lm_ds.sql, swms, swms.9, 10.1.1 9/7/06 1.2

   ------------------------------------------------------------------------
   -- Package Name:
   --    pl_lm_ds
   --
   -- Description:
   --    Discrete selection.
   --
   -- Process flow in determining the discrete selection time a selection
   -- batch:
   -- loop
   --    - Select selection batch records.  Ordering is by pik path.
   --
   --    - If first record then:
   --      Get pickup time.  This is the time to travel from the starting point
   --      to the pickup point(s), pickup the pickup object(s) then travel to
   --      the first pick slot.
   --
   --    - If the first record in an aisle:
   --         If a forklift cross aisle is setup for the aisle and if an order
   --         selection cross aisle is setup then get the max picking slot in
   --         the aisle and the min picking slot in the next aisle.
   --         If the min picking slot in the aisle <= cross aisle and the
   --         min picking slot in the next aisle >= cross aisle then set flag
   --         to use the cross aisle.
   --
   --    - If using cross aisle then stop equipment movement at the cross
   --      aisle.  Calculate distance from the cross aisle to the picking slot
   --      then back to the cross aisle.  The order selector will be walking
   --      down to the picking slot then back to the cross aisle where the
   --      equipment is stopped.
   --  
   --    - If not using cross aisle then calculate distance between previous
   --      picking slot and current picking slot.
   -- 
   --    - When traveling from one pick slot to the next ON THE SAME AISLE
   --      and the distance is <= max walking distance and the equipment is
   --      not stopped at the cross aisle then give time for the selector to
   --      walk the equipment.  If the equipment is stopped at the cross aisle
   --      then this means that the cross aisle is used.
   -- 
   --    - If previous picking slot on a different aisle then calculate the
   --      distance from the previous aisle to the current aisle.
   --
   -- end loop
   --
   -- If there was at least one record on the selection batch then:
   --    - Get drop off distance.  This is the distance from the last pick
   --      slot to the door(s) then to the starting point.
   --
   -- In order for a cross aisle to be used the following criteria must be meet:
   --    - The aisles are setup in the FORKLIFT_CROSS_AISLE table.  This
   --      designates the actual bays of the cross aisle which is needed to
   --      calculate the distance traveled.
   --    - The aisle are setup in the CROSS_AISLE table.
   --    - The last picking slot in the aisle is <= the to_cross aisle in
   --       the CROSS_AISLE table.  This is based on the loc.pik_slot value.
   --    - The first picking slot in the next aisle is >= the from_cross aisle
   --      in the CROSS_AISLE table.  This is based on the loc.pik_slot value.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/15/05 prpbcb   Oracle 8 rs239b swms9 DN 11490
   --                      Created for discrete selection.
   --
   --                      Changed made during development:
   --                      Added populating of pm.split_type.  This column
   --                      works like pm.case_type but is for splits.
   --
   --                      Removed references to syspars:
   --                         -  DS_AUDIT_DURING_ORDER_GEN
   --                         - DS_DRY_MAX_WALKING_DISTANCE
   --                         - DS_CLR_MAX_WALKING_DISTANCE
   --                         - DS_FRZ_MAX_WALKING_DISTANCE
   --                      After meeting with Distribution Services it was
   --                      determined these syspars are not needed.
   --
   --                      In cursor c_item changed
   --                         .
   --                         .
   --                         .
   --                               d.ds_tmu_record_exists,
   --                               d.max_walking_dist
   --                          FROM v_ds_floats d
   --                         WHERE d.batch_no        = cp_batch_no
   --                         ORDER BY d.pik_path;
   --                      to
   --                               d.ds_tmu_record_exists,
   --                               -1 max_walking_dist
   --                          FROM v_ds_floats d
   --                         WHERE d.batch_no        = cp_batch_no
   --                         ORDER BY d.pik_path;
   --                      The max walking distance is now always -1 so
   --                      no walking will take place.  This is a piece of
   --                      code left in the program that looks at
   --                      max_walking_dist.
   --
   --                      Removed references to column
   --                      ds_selection_pickup_object.use_for_unitize_flag.
   --                      This column was removed from the table because
   --                      UNI picks are specified at the job code level
   --                      and discrete standards are at the job code level
   --                      so there is no need for a column to designate
   --                      UNI picks.
   --
   --                      The quantity to pickup of the pickup object can
   --                      now be based on the cube of the pickup object.
   --                      Made the required changes.  The rule is if the
   --                      quantity to pickup of the pickup object is based
   --                      on the cube then the quantity will be:
   --                         (cube of the splits on the batch) /
   --                         (cube of the pickup object)
   --                      The value is rounded up to the nearest integer.
   --                      Column ds_pickup_object.qty_based_on designates
   --                      what the quantity of the pickup object is based on.
   --                      If ds_pickup_object.qty_based_on is 'C' then
   --                      ds_pickup_object.cube must have a value > 0.  This
   --                      is enforced in the pickup object form and in a
   --                      database trigger on table ds_pickup_object.
   --
   --                      Added procedure adjust_batch_time which will
   --                      adjust the batch time due to shorts and any
   --                      change in the points visited.
   ------------------------------------------------------------------------

   /*************************************************************************
   ** Private Type Declarations
   **************************************************************************/

   -- Information specific to discrete selection.  These values are
   -- calculated then the labor management batch is updated with these values.
   --    ds_case_time   - Case handling time in tmu.
   --    ds_split_time  - Split handling time in tmu.
   --    travel_time    - Equipment travel time in minutes.
   --    walk_feet      - Number of feet walked.  Selectors will walk to the
   --                     pick slot when the equipment is parked at a cross
   --                     aisle or when the distance between picking slots
   --                     is less than a predetermined distance.
   --    pickup_object_time  - Time to pickup the pickup objects in tmu.
   TYPE t_ds_info_rec IS RECORD
    (ds_case_time           NUMBER                           := 0,
     ds_split_time          NUMBER                           := 0,
     travel_time            NUMBER                           := 0,
     walk_feet              NUMBER                           := 0,
     pickup_object_time     PLS_INTEGER                      := 0);


   /*************************************************************************
   ** Global variables.
   **************************************************************************/


   /*************************************************************************
   ** Public Constants
   **************************************************************************/


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_case_type
   --
   -- Description:
   --    This function determines the case type or split type for an item
   --    which is based on the item's case cube or split cube and gross
   --    weight.
   ---------------------------------------------------------------------------
   FUNCTION f_get_case_type(i_cube      IN pm.case_cube%TYPE,
                            i_g_weight  IN pm.g_weight%TYPE)
   RETURN VARCHAR2;

   ------------------------------------------------------------------------
   -- Function:
   --    f_get_tmu
   --
   -- Description:
   --    This function returns the tmu for a case or split of a particular
   --    case type picked from a specified location.  If unable to
   --    determine the tmu then null is returned.
   ------------------------------------------------------------------------
   FUNCTION f_get_tmu(i_case_type  IN case_type_code.case_type%TYPE,
                       i_location  IN loc.logi_loc%TYPE,
                       i_uom       IN loc.uom%TYPE)
   RETURN ds_tmu.tmu_no_case%TYPE;

   ---------------------------------------------------------------------------
   -- Procedure:
   --    populate_case_type
   --
   -- Description:
   --    This procedure populates the case type and split type for all items
   --    with the appropriate case type.  These are based on the weight and
   --    cube of the case and split.  The case/split type is determined by
   --    looking at the CASE_TYPE_CODE table.  If no case/split type is found
   --    then the column is set to null.
   ---------------------------------------------------------------------------
   PROCEDURE populate_case_type(o_msg  OUT VARCHAR2);

   ---------------------------------------------------------------------------
   -- Function:
   --    f_splits_on_batch
   --
   -- Description:
   --    This function determines if splits are on a selection batch.
   ---------------------------------------------------------------------------
   FUNCTION f_splits_on_batch(i_batch_no IN floats.batch_no%TYPE)
   RETURN BOOLEAN;

   ------------------------------------------------------------------------
   -- Procedure:
   --    validate_case_type_records
   --
   -- Description:
   --    This procedure validates the records in the CASE_TYPE_CODE table.
   --    The cube range and the weight range cannot overlap between records.
   ------------------------------------------------------------------------
   PROCEDURE validate_case_type_records(o_records_valid_bln OUT BOOLEAN,
                                        o_msg               OUT VARCHAR2);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    validate_selection_pup_origin
   --
   -- Description:
   --    This procedure validates the origin column in the
   --    ds_selection_pickup_object table.  Only one record per job code
   --    can have the origin set to 'Y'.  It stops at the first job code
   --    that meets this condition.
   ---------------------------------------------------------------------------
   PROCEDURE validate_selection_pup_origin(o_records_valid_bln OUT BOOLEAN,
                                           o_msg               OUT VARCHAR2);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    copy_pickup_object_setup
   --
   -- Description:
   --    This procedure copies the pickup objects and pickup points defined
   --    for a job code to another job code.  Anything currently setup for the
   --    "copy to" job code will be deleted.
   ---------------------------------------------------------------------------
   PROCEDURE copy_pickup_object_setup
         (i_copy_from_job_code IN  ds_selection_pickup_object.job_code%TYPE,
          i_copy_to_job_code   IN  ds_selection_pickup_object.job_code%TYPE);

   ------------------------------------------------------------------------
   -- Procedure:
   --    populate_ds_tmu
   --
   -- Description:
   --    This procedure populates the DS_TMU table with the distinct
   --    sub area code, slot tpe, pallet type and pik level for
   --    home and floating slots.
   --    The parameter indicates whether to populate the table
   --    using all the records in the LOC table which will delete any
   --    current records in the DS_TMU table or to only populate
   --    the DS_TMU table with records currently not in the table.
   --
   --    The case and split tmu's are taken from the CASE_TYPE_CODE table.
   --    It is required that there is at least one record in the
   --    CASE_TYPE_CODE table.
   ------------------------------------------------------------------------
   PROCEDURE populate_ds_tmu(i_what_records  IN  VARCHAR2,
                             o_msg           OUT VARCHAR2);

   ------------------------------------------------------------------------
   -- Procedure:
   --    delete_invalid_ds_tmu
   --
   -- Description:
   --    This procedure deletes the invalid records from the DS_TMU
   --    table.  A record is considered invalid if the combination of
   --    sub area code, slot tpe, pallet type and pik level does not exist
   --    in the LOC table.  A situation where this could happen is when
   --    the opco makes changes to the warehouse layout.
   --
   --    There is a view called v_ds1sb_invalid_locations used in form ds1sb
   --    to display the invalid records so if the logic changes in this
   --    procedure the view may need to be changed too.
   ------------------------------------------------------------------------
   PROCEDURE delete_invalid_ds_tmu(o_msg    OUT VARCHAR2);

   ------------------------------------------------------------------------
   -- Procedure:
   --    calc_case_split_time
   --
   -- Description:
   --    This procedure calculates the case and split handling time for
   --    a selection batch.  The calculated values will be in TMU units.
   ------------------------------------------------------------------------
   PROCEDURE calc_case_split_time(i_batch_no   IN  floats.batch_no%TYPE,
                                  o_case_time  OUT NUMBER,
                                  o_split_time OUT NUMBER);

   ------------------------------------------------------------------------
   -- Procedure:
   --    get_picking_slots
   --
   -- Description:
   --    This procedure gets the max picking slot an item is to be picked from
   --    on the selection batch  on an aisle and the  min picking slot an item
   --    is to be picked from on the next aisle.  This information is used to
   --    determine if a cross aisle is to be used.
   ---------------------------------------------------------------------------
   PROCEDURE get_picking_slots
               (i_batch_no                    IN  floats.batch_no%TYPE,
                i_pik_aisle                   IN  loc.pik_aisle%TYPE,
                o_max_picking_slot            OUT loc.pik_path%TYPE,
                o_next_aisle_pik_aisle        OUT loc.pik_aisle%TYPE,
                o_next_aisle_min_picking_slot OUT loc.pik_slot%TYPE,
                o_found_picking_slot_bln      OUT BOOLEAN);

   ------------------------------------------------------------------------
   -- Procedure:
   --    get_forklift_cross_aisles
   --
   -- Description:
   --    This procedure function gets the forklift cross aisle information
   --    for an aisle.
   ---------------------------------------------------------------------------
   PROCEDURE get_forklift_cross_aisles
              (i_from_aisle            IN  forklift_cross_aisle.from_aisle%TYPE,
               o_from_bay              OUT forklift_cross_aisle.from_bay%TYPE,
               o_to_aisle              OUT forklift_cross_aisle.to_aisle%TYPE,
               o_to_bay                OUT forklift_cross_aisle.to_bay%TYPE,
               o_found_cross_aisle_bln OUT BOOLEAN);

   ------------------------------------------------------------------------
   -- Procedure:
   --    use_cross_aisle
   --
   -- Description:
   --    This procedure determines if a cross aisle is to be used.
   --
   -- Description:
   ---------------------------------------------------------------------------
   PROCEDURE use_cross_aisle
              (i_batch_no              IN  floats.batch_no%TYPE,
               i_pik_aisle             IN  loc.pik_aisle%TYPE,
               i_aisle                 IN  forklift_cross_aisle.from_aisle%TYPE,
               i_to_cross_pik_slot     IN  cross_aisle.to_cross%TYPE,
               o_cross_aisle_from_bay  OUT forklift_cross_aisle.from_bay%TYPE,
               o_cross_aisle_to_aisle  OUT forklift_cross_aisle.to_aisle%TYPE,
               o_cross_aisle_to_bay    OUT forklift_cross_aisle.to_bay%TYPE,
               o_use_cross_aisle_bln   IN OUT BOOLEAN);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_pickup_time
   --
   -- Description:
   --    This procedure calculates the pickup time for the selection batch.
   --    The pickup time is the time required to travel to the designated
   --    pickup points to pickup wood pallets, plastic pallets, totes, etc.,
   --    the time to pickup the object(s), and the time to travel to the first
   --    pick slot.
   --
   --    The distance will be the shortest distance to travel to all the
   --    defined pickup points then to the first pick slot.
   --    The pickup points are setup for each selection job code.
   ---------------------------------------------------------------------------
   PROCEDURE get_pickup_time
                (i_r_sel_batch        IN     pl_lm_sel.t_sel_batch_rec,
                 i_r_equip            IN     pl_lmc.t_equip_rec,
                 i_first_pick_loc     IN     float_detail.src_loc%TYPE,
                 i_aisle_direction    IN     aisle_info.direction%TYPE,
                 i_unitized_pull_flag IN     VARCHAR2,
                 io_r_ds_info         IN OUT t_ds_info_rec);

   ------------------------------------------------------------------------
   -- Procedure:
   --    get_dropoff_time
   --
   -- Description:
   --    This procedure calculates the drop off distance for a batch
   --    which is the distance traveled from the last pick slot to the
   --    door(s) then to the starting point.  The can be more than one
   --    door if it is an optimal pull batch.
   ------------------------------------------------------------------------
   PROCEDURE get_dropoff_time
                (i_r_sel_batch       IN     pl_lm_sel.t_sel_batch_rec,
                 i_r_equip           IN     pl_lmc.t_equip_rec,
                 i_last_pick_loc     IN     float_detail.src_loc%TYPE,
                 i_aisle_direction   IN     aisle_info.direction%TYPE,
                 i_opt_pull          IN     sel_equip.opt_pull%TYPE,
                 i_float_no          IN     floats.float_no%TYPE,
                 io_r_ds_info        IN OUT t_ds_info_rec);

   ------------------------------------------------------------------------
   -- Procedure:
   --    calc_ds_time
   --
   -- Description:
   --    This procedure calculates the time for discrete selection.
   --    The following values are calculated then the labor mgmt batch
   --    is updated with these values.
   --       - Case handling time (total time in minutes).
   --       - Split handling time (total time in minutes).
   --       - Travel time (in minutes).
   ------------------------------------------------------------------------
   PROCEDURE calc_ds_time(i_r_sel_batch     IN pl_lm_sel.t_sel_batch_rec,
                          i_audit_only_bln  IN BOOLEAN := FALSE);

   ---------------------------------------------------------------------------
   -- Procedure:
   --    adjust_batch_time
   --
   -- Description:
   --    This procedure adjusts the batch time due to shorts and any
   --    change in the points visited.  The adjustment happens when the
   --    batch is being closed.
   ---------------------------------------------------------------------------
   PROCEDURE adjust_batch_time(i_lm_batch_no  IN  arch_batch.batch_no%TYPE);

END pl_lm_ds;  -- end package specification
/

SHOW ERRORS;

PROMPT Create package body: pl_lm_ds

/***************************************************************************
** Package Body
***************************************************************************/
CREATE OR REPLACE PACKAGE BODY swms.pl_lm_ds
AS

   -- sccs_id=@(#) src/schema/plsql/pl_lm_ds.sql, swms, swms.9, 10.1.1 9/7/06 1.2

   ------------------------------------------------------------------------
   -- Package Name:
   --    pl_lm_ds
   --
   -- Description:
   --    Discrete selection.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/17/01 prpbcb   rs239a DN 10859  rs239b DN 10860  Created.  
   ------------------------------------------------------------------------

   /*************************************************************************
   ** Private Cursors
   **************************************************************************/

   --
   -- This cursor selects the items on the selection batch and pickup points
   -- to visit during selection.
   --
   CURSOR c_item(cp_batch_no IN  floats.batch_no%TYPE) IS
      SELECT d.pick_type,    -- Either ITEM or PICKUP_OBJECT
             d.equip_id,
             d.prod_id,
             d.cust_pref_vendor,
             d.case_type,
             d.uom,
             d.qty_alloc,
         --  d.merge_alloc_flag,
             d.no_cases,
             d.no_splits,
             d.tmu_no_case,
             d.tmu_no_split,
             d.item_total_case_tmu,
             d.item_total_split_tmu,
             d.pik_path,
             d.pik_aisle,
             d.pik_slot,
             d.pik_level,
             d.aisle,
             d.bay,
             d.pick_loc,   -- Either a slot or a pickup point.
             d.from_cross,
             d.to_cross,
             d.direction,
             d.physical_aisle_order,
             d.bay_dist,
             d.sel_type,
             d.method_id,
             d.group_no,
             d.job_code,
             d.f_door,
             d.c_door,
             d.d_door,
             d.float_no,    -- Used to get the destination door number
             d.unitized_pull_flag,
             d.opt_pull,
             d.ds_tmu_record_exists,
             -1 max_walking_dist, -- Set to -1 to disable the walking distance
                                  -- check between bays.  This does not affect
                                  -- the walking that may take place with the
                                  -- cross bay logic.
             pickup_object,   -- Pickup object when it is designated to be
                              -- picked up while selecting.
             pickup_object_tmu  -- TMU for the pickup object.
        FROM v_ds_floats d
       WHERE d.batch_no        = cp_batch_no
       ORDER BY NVL(d.pik_path, -1),  -- If the pik_path is null then this 
             pick_loc;                -- means picking up a pickup object
                                      -- (during selecting) at a location that
                                      -- is not a slot.  In this case the
                                      -- pickup point will be the first place
                                      -- visited.
                                      -- Ideally if a pickup object is to be
                                      -- picked up while selecting the point
                                      -- to pick it up from should be a slot.


   --
   -- This cursor selects the pickup points and the objects to pickup.
   -- The origin point is selected first then the ordering is by the pickup
   -- order.  It is also used to get the origin point of the selection batch
   -- which is used when calculating the drop off distance.
   --
   CURSOR c_gl_pup(cp_job_code IN ds_selection_pickup_object.job_code%TYPE) IS
      SELECT dss1.pickup_order          pickup_order,
             dss1.pickup_object         pickup_object,
             po.descrip                 pickup_object_descrip,
             dss1.pickup_point          pickup_point,
             pp.descrip                 pickup_point_descrip,
             dss1.always_pickup_flag    always_pickup_flag,
             dss1.use_for_splits_flag   use_for_splits_flag,
             po.tmu                     tmu,
             po.cube                    cube,
             po.qty_based_on            qty_based_on,
             dss1.pickup_while_selecting_flag  pickup_while_selecting_flag
        FROM ds_pickup_object po,
             ds_pickup_point pp,
             ds_selection_pickup_object dss1
       WHERE dss1.job_code                    = cp_job_code
         AND po.pickup_object                 = dss1.pickup_object
         AND pp.pickup_point                  = dss1.pickup_point
       ORDER BY DECODE(origin, 'Y', 1, 2),
             dss1.pickup_order;


   /*************************************************************************
   ** Private Type Declarations
   **************************************************************************/


   /*************************************************************************
   ** Private Global Variables
   **************************************************************************/
   gl_pkg_name   VARCHAR2(20) := 'pl_lm_ds';   -- Package name.  Used in
                                               -- error messages.

   gl_e_parameter_null  EXCEPTION;     -- A parameter to a procedure/function
                                       -- is null.


   /*************************************************************************
   ** Private Global Variables
   **************************************************************************/
   -- The precision of the case_type table cube and weight columns.
   -- The item's cube and weight need to be rounded to this precision
   -- otherwise it is possible no matching record could be found.
   -- If the precision of the column changes then the constant needs to be
   -- changed to match it.
   ct_case_cube_precision  CONSTANT PLS_INTEGER := 3;
   ct_g_weight_precision   CONSTANT PLS_INTEGER := 2;


   /*************************************************************************
   ** Private Modules
   **************************************************************************/

   ---------------------------------------------------------------------------
   -- Function:
   --    f_calc_pickup_qty
   --
   -- Description:
   --    This function calculates the quantity of a pickup object.
   --    The quantity depends on what has been setup for the pickup object
   --    which is defined in the ds_pickup_object.qty_based_on column.
   --
   -- Parameters:
   --    i_r_pup          - Pickup point record.  This will the
   --                       information about the pickup object.
   --    i_r_sel_batch    - Selection batch record.  This is the
   --                       information from floats, float_detail, ...
   --                       tables used to create the selection labor
   --                       mgmt batch.
   --
   -- Return Value:
   --    Pickup quantity.
   --
   -- Exceptions raised:
   --    pl_exc.ct_data_error     - A parameter is null. 
   --                               Unhandled value in i_qty_based_on.
   --    pl_exc.e_database_error  - Oracle error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    06/26/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_calc_pickup_qty
               (i_r_pup          IN  c_gl_pup%ROWTYPE,
                i_r_sel_batch    IN  pl_lm_sel.t_sel_batch_rec)

   RETURN PLS_INTEGER
   IS
      l_message       VARCHAR2(128);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_calc_pickup_qty';

      l_pickup_qty    PLS_INTEGER;  -- The qty to pickup of the pickup object.

      e_unhandled_qty_based_on  EXCEPTION;  -- Have an unhandled value
                                            -- in i_r_pup._qty_based_on.

   BEGIN

      -- Debug stuff
      /*
      l_message := l_object_name ||
          '(i_pickup_object[' || i_pickup_object || ']' ||
          ',i_qty_based_on[' || i_qty_based_on || ']' ||
          ',i_r_sel_batch)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL);
      */

      IF (i_r_pup.qty_based_on = 'P') THEN
         -- The pickup qty is the number of pallets (floats).
         l_pickup_qty := i_r_sel_batch.num_floats;
      ELSIF (i_r_pup.qty_based_on = 'O') THEN
         -- The pickup qty is always one.
         l_pickup_qty := 1;
      ELSIF (i_r_pup.qty_based_on = 'C') THEN
         -- The pickup qty is based on the cube.  The rule is the pickup qty
         -- will be the
         --     (cube of the splits on the batch) / (cube of the pickup object)
         -- rounded up to the nearest integer.
         l_pickup_qty := CEIL(i_r_sel_batch.split_cube / i_r_pup.cube);
      ELSE
         -- Unhandled value in i_r_pup.qty_based_on.
         RAISE e_unhandled_qty_based_on;
      END IF;

      RETURN(l_pickup_qty);

   EXCEPTION
      WHEN e_unhandled_qty_based_on THEN
         l_message := l_object_name ||
             '(i_r_pup.pickup_object[' || i_r_pup.pickup_object || ']' ||
             ',i_r_pup.qty_based_on[' || i_r_pup.qty_based_on || ']' ||
             ',i_r_sel_batch)  Unhandled value in i_r_pup.qty_based_on.';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                                    l_object_name || ': ' || SQLERRM);
      WHEN OTHERS THEN
         l_message := l_object_name ||
             '(i_r_pup.pickup_object[' || i_r_pup.pickup_object || ']' ||
             ',i_r_pup.qty_based_on[' || i_r_pup.qty_based_on || ']' ||
             ',i_r_sel_batch)';
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
   END f_calc_pickup_qty;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_origin_point
   --
   -- Description:
   --    This function determines the origin for a specified job code.
   --    The origin is the point a selection batch starts.  It will be
   --    the first pickup point for the job code and should be designated as
   --    the origin when the pickup points are defined for a job code.
   --
   -- Parameters:
   --    i_job_code   - Job code to find the origin for.
   --
   -- Return Value:
   --    Origin point.  It can be null if there are no pickup points setup
   --    for the job code.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Oracle error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/01/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_get_origin_point
               (i_job_code IN  ds_selection_pickup_object.job_code%TYPE)
   RETURN VARCHAR2
   IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_get_origin_point';

      l_origin       ds_selection_pickup_object.pickup_point%TYPE;
      l_r_pup        c_gl_pup%ROWTYPE;   -- Private cursor used.

   BEGIN

      l_message_param := l_object_name || '(' || i_job_code || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_gl_pup(i_job_code);

      FETCH c_gl_pup INTO l_r_pup;

      -- If no origin found then write a log message.  Normally a origin
      -- should be defined for each job code.
      IF (c_gl_pup%NOTFOUND) THEN
         l_origin := NULL;

         l_message := l_object_name || '(' || i_job_code || ')' ||
            '  Did not find the origin for this job code.  Using null.';
         pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                        NULL, NULL);
      ELSE
         l_origin := l_r_pup.pickup_point;
      END IF;

      CLOSE c_gl_pup;
    
      RETURN(l_origin);

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END f_get_origin_point;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    update_ds_time
   --
   -- Description:
   --    This procedure updates the selection labor mgmt batch with the
   --    values calculated for discrete selection.  The case handling time
   --    and split handling time are in tmu's.  They are stored in minutes
   --    in the BATCH table thus they are converted in the update statement.
   --    The kvi_distance is stored in minutes.  The travel time is calculated
   --    in minutes so no conversion is necessary.
   --
   --    Value Calculated                               BATCH Column Updated
   --    --------------------------------------------   ----------------------
   --    Case handling time                             ds_case_time
   --    Split handling time                            ds_split_time
   --    Travel time (in minutes)                       kvi_distance
   --    Feet walked                                    kvi_walk
   --
   -- Parameters:
   --    i_lm_batch_no     - Selection labor mgmt batch number.
   --    i_r_equip         - Equipment tmu values.
   --    i_r_ds_info       - Values to update the batch.
   --
   -- Exceptions raised:
   --    pl_exc.e_lm_batch_upd_fail  - Unable to update the batch.
   --    pl_exc.e_database_error     - Any other error.
   --
   -- Called by:
   --    calc_ds_time
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    02/26/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE update_ds_time(i_lm_batch_no  IN  arch_batch.batch_no%TYPE,
                            i_r_ds_info    IN  t_ds_info_rec)
   IS
      l_message       VARCHAR2(128);    -- Message buffer
      l_message_param VARCHAR2(128);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.update_ds_time';
   BEGIN

      l_message_param := l_object_name ||
         '(i_lm_batch_no[' || i_lm_batch_no || '], i_r_ds_info)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      UPDATE batch
         SET ds_case_time          = i_r_ds_info.ds_case_time / 1667,
             ds_split_time         = i_r_ds_info.ds_split_time / 1667,
             kvi_distance          = i_r_ds_info.travel_time,
             kvi_walk              = i_r_ds_info.walk_feet,
             kvi_pickup_object     = i_r_ds_info.pickup_object_time / 1667
       WHERE batch_no = i_lm_batch_no;

      IF (SQL%NOTFOUND) THEN
         l_message :=  l_object_name ||
            '  TABLE=batch  ACTION=UPDATE  i_lm_batch_no=[' ||
            i_lm_batch_no ||']  MESSAGE="Batch not found."';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE pl_exc.e_lm_batch_upd_fail;
      END IF;

   EXCEPTION
      WHEN pl_exc.e_lm_batch_upd_fail THEN
         RAISE_APPLICATION_ERROR(SQLCODE, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END update_ds_time;


   ------------------------------------------------------------------------
   -- Procedure:
   --    print_rec
   --
   -- Description:
   --    This procedure outputs the record read for the batch.
   --    Used for debugging.
   --
   -- Parameters:
   --    i_item    - The selection batch item.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/20/01 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE print_rec(i_item IN  c_item%ROWTYPE)
   IS
   BEGIN
      IF (pl_lmc.f_debugging) THEN
         DBMS_OUTPUT.PUT_LINE('ProdId  SrcLoc  TmuC  TmuS' ||
                   '  TCTmu  TSTmu  Dir' ||
                   ' Aisle Bay BayDist FCross TCross SelType SelMethod Grp#' ||
                   '  JobCode Unitized Pull?');
         DBMS_OUTPUT.PUT_LINE(i_item.prod_id || ' ' ||
                   i_item.pick_loc || ' ' ||
                   TO_CHAR(i_item.tmu_no_case, 9999) || ' ' ||
                   TO_CHAR(i_item.tmu_no_split, 9999) || ' ' ||
                   TO_CHAR(i_item.item_total_case_tmu, 99999) || ' ' ||
                   TO_CHAR(i_item.item_total_split_tmu, 99999) || ' ' ||
                   TO_CHAR(i_item.direction, 999) || ' ' ||
                   i_item.aisle || '    ' ||
                   i_item.bay || '  ' ||
                   TO_CHAR(i_item.bay_dist, 9999.9) ||   ' ' ||
                   TO_CHAR(i_item.from_cross, 999) || '     ' ||
                   TO_CHAR(i_item.to_cross, 999) || '  ' ||
                   i_item.sel_type || '     ' ||
                   i_item.method_id || '  ' ||
                   TO_CHAR(i_item.group_no, 9999) || '     ' ||
                   i_item.job_code || '       ' ||
                   i_item.unitized_pull_flag);
         DBMS_OUTPUT.PUT_LINE('========');
      END IF;

   END print_rec;

   ------------------------------------------------------------------------
   -- Procedure:
   --    print_item_tmu_line
   --
   -- Description:
   --    This procedure prints the item detail line showing the qty and
   --    tmu values.  Used for debugging.
   --
   -- Parameters:
   --    i_item    - The selection batch item.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/07/02 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE print_item_tmu_line(i_item IN  c_item%ROWTYPE)
   IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE('-                 #     #      Case  Split' ||
        '    Total     Total Case' ||
        '  -- ACCLD --  -- TRVLD --  -- DECLD --   Total Time');
      DBMS_OUTPUT.PUT_LINE('Prod Id Location Cases Splits   TMU    TMU' ||
                   ' Case TMU Split TMU Type' ||
                   '  Time  Freq.  Time  Freq.  Time  Freq.' ||
                   '    (Minutes)');
      DBMS_OUTPUT.PUT_LINE('------- -------- ----- ------  ----   ----' ||
                   ' -------- --------- ----' ||
                   '  ----  ------  ----  -----  ----  -----' ||
                   '  ----------');

      DBMS_OUTPUT.PUT_LINE(i_item.prod_id || ' ' ||
                   RPAD(i_item.pick_loc, 8) || ' ' ||
                   TO_CHAR(i_item.no_cases, 9999) || '  ' ||
                   TO_CHAR(i_item.no_splits, 9999) || ' ' ||
                   TO_CHAR(i_item.tmu_no_case, 9999) || '  ' ||
                   TO_CHAR(i_item.tmu_no_split, 9999) || '   ' ||
                   TO_CHAR(i_item.item_total_case_tmu, 99999) || '    ' ||
                   TO_CHAR(i_item.item_total_split_tmu, 99999) || ' ' ||
                   RPAD(i_item.case_type,4) ||
                   '                                            ' ||
                   TO_CHAR((i_item.item_total_case_tmu +
                            i_item.item_total_split_tmu) / 1667, 99.9999));

   END print_item_tmu_line;


   ------------------------------------------------------------------------
   -- Procedure:
   --    print_heading
   --
   -- Description:
   --    This procedure prints the item detail heading line.
   --    Used for debugging.
   --
   -- Parameters:
   --    None
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/07/02 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE print_heading
   IS
   BEGIN
      DBMS_OUTPUT.PUT_LINE('-                 #     #      Case  Split' ||
        '    Total     Total Case' ||
        '  -- ACCLD --  -- TRVLD --  -- DECLD --   Total Time');
      DBMS_OUTPUT.PUT_LINE('Prod Id Location Cases Splits   TMU    TMU' ||
                   ' Case TMU Split TMU Type' ||
                   '  Time  Freq.  Time  Freq.  Time  Freq.' ||
                   '    (Minutes)');
      DBMS_OUTPUT.PUT_LINE('------- -------- ----- ------  ----   ----' ||
                   ' -------- --------- ----' ||
                   '  ----  ------  ----  -----  ----  -----' ||
                   '  ----------');

   END print_heading;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    adjust_batch_time
   --
   -- Description:
   --    This procedure adjusts the goal/target time for selection labor mgmt
   --    batch time due to shorts for SOS OPCOs.  The adjustment happens when
   --    the batch is being completed.  Shorts at non-SOS OPCOs are not
   --    adjusted because the short information is not available when the batch
   --    is being completed.  The data capture items will be adjusted
   --    accordingly.
   --
   --    The original time given to pick the item will be subtracted from the
   --    batch time and the short time will be added to the batch time.  The
   --    proper adjustments will be made for items that required data capture
   --    such as catchweight items and clambed items.  The adjustment will be
   --    logged in the swms log table.
   --
   --    Following is an example of adjusting for shorts.
   --       3 cases of item 1234567 ordered.  Clambed tracked item.
   --       The time given to pick this item will be:
   --            (location case type tmu * 3) + (clambed data capture tmu * 3)
   --       1 case shorted.
   --       The adjustment made to the batch time will be:
   --          batch time = batch time - (location case type tmu * 1)
   --          batch time = batch time - (clambed data capture tmu * 1)
   --          batch time = 1 * short tmu
   --
   -- Parameters:
   --    o_lm_batch_no  - Selection labor mgmt batch number
   --  
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null
   --    pl_exc.e_database_error  - An oracle error occurred.
   --
   -- Called By:
   --    - pl_lm_ds.adjust_batch_time
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/10/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE adjust_time_for_shorts(i_lm_batch_no  IN  arch_batch.batch_no%TYPE)
   IS
      l_message        VARCHAR2(128);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.adjust_time_for_shorts';

      l_syspar_clam_bed_tracked sys_config.config_flag_val%TYPE;
                                              -- CLAM_BED_TRACKED syspar

      l_tmu            ds_tmu.tmu_no_case%TYPE;  -- TMU for the location
                                                 -- case/split type.

      -- This cursor selects the SOS items shorted and information about the
      -- item.
      -- The sos_short.batch_no column has the floats batch number.
      -- The format of the selection labor mgmt batch number is
      -- S<floats batch number>.
      CURSOR c_shorts
               (cp_lm_batch_no             arch_batch.batch_no%TYPE,
                cp_syspar_clam_bed_tracked sys_config.config_flag_val%TYPE) IS
         SELECT pm.case_type,
                pm.split_type,
                pm.catch_wt_trk,
                pl_common.f_is_clam_bed_tracked_item(pm.category,
                              cp_syspar_clam_bed_tracked) clam_bed_tracked,
                d.prod_id,
                d.cust_pref_vendor,
                d.uom,
                s.location,
                s.batch_no,          -- this is the floats.batch_no
                s.qty_short
           FROM pm,
                ordd d,
                sos_short s
          WHERE pm.prod_id          = d.prod_id
            AND pm.cust_pref_vendor = d.cust_pref_vendor
            AND d.seq               = s.orderseq
            AND s.batch_no          = SUBSTR(cp_lm_batch_no, 2);
   BEGIN
      IF (i_lm_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Need the clam bed tracked syspar to use in determining if an item
      -- is clam bed tracked.
      l_syspar_clam_bed_tracked :=
                         pl_common.f_get_syspar('CLAM_BED_TRACKED', 'N');


      -- Make adjustments to the goal/target time for the batch for SOS shorts.
      FOR r_shorts IN c_shorts(i_lm_batch_no, l_syspar_clam_bed_tracked) LOOP
         -- If a case shorted get the tmu based on the case type and location.
         -- If a split shorted get the tmu based on the split type and location.
         l_tmu := f_get_tmu(r_shorts.case_type, r_shorts.location,
                            r_shorts.uom);
      END LOOP;
   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_lm_batch_no[' || i_lm_batch_no ||
                      '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                        l_message || '  Parameter is null.',
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
      WHEN OTHERS THEN
         l_message := l_object_name || '(i_lm_batch_no[' || i_lm_batch_no ||
                      '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END adjust_time_for_shorts;


   /*************************************************************************
   ** Public Modules
   **************************************************************************/

   ---------------------------------------------------------------------------
   -- Procedure:
   --    copy_pickup_object_setup
   --
   -- Description:
   --    This procedure copies the pickup objects and pickup points defined
   --    for a job code to another job code.  Anything currently setup for the
   --    "copy to" job code will be deleted.
   --
   -- Parameters:
   --    i_copy_from_job_code  - The job code to copy the setup from.
   --    i_copy_to_job_code    - The job code to copy to.
   --
   -- Exceptions raised:
   --    pl_exc.ct_data_error      - A parameter is null.
   --    pl_exc.e_database_error   - Any other error.
   --
   -- Called by:
   --    - form ds1se.fmb
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/20/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE copy_pickup_object_setup
         (i_copy_from_job_code IN  ds_selection_pickup_object.job_code%TYPE,
          i_copy_to_job_code   IN  ds_selection_pickup_object.job_code%TYPE)
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_message_param VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                             '.copy_pickup_object_setup';
   BEGIN
      IF (i_copy_from_job_code IS NULL OR i_copy_to_job_code IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Delete any existing records for the "copy to" job code.
      DELETE FROM ds_selection_pickup_object
       WHERE job_code = i_copy_to_job_code;

      INSERT INTO ds_selection_pickup_object
            (job_code,
             pickup_object,
             pickup_point,
             always_pickup_flag,
             use_for_splits_flag,
             pickup_while_selecting_flag,
             pickup_order,
             origin,
             cmt)
      SELECT i_copy_to_job_code,
             pickup_object,
             pickup_point,
             always_pickup_flag,
             use_for_splits_flag,
             pickup_while_selecting_flag,
             pickup_order,
             origin, 
             cmt
        FROM ds_selection_pickup_object
       WHERE job_code = i_copy_from_job_code;

   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name ||
                '(i_copy_from_job_code [' || i_copy_from_job_code || '],' ||
                ' i_copy_to_job_code [' || i_copy_to_job_code || '])' ||
                ' A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
                '(i_copy_from_job_code [' || i_copy_from_job_code || '],' ||
                ' i_copy_to_job_code [' || i_copy_to_job_code || '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                 l_object_name || ': ' || SQLERRM);
   END copy_pickup_object_setup;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    get_pickup_time
   --
   -- Description:
   --    This procedure calculates the pickup time for the selection batch.
   --    The pickup time is the time required to travel to the designated
   --    pickup points to pickup wood pallets, plastic pallets, totes, etc.,
   --    the time to pickup the object(s), and the time to travel to the first
   --    pick slot.
   --
   --    The distance will be the shortest distance to travel to all the
   --    defined pickup points then to the first pick slot.
   --    The pickup points are setup for each selection job code.
   --
   -- Parameters:
   --    i_r_sel_batch         - Selection batch record.  This is the
   --                            information from floats, float_detail, ...
   --                            tables used to create the selection labor
   --                            mgmt batch.
   --    i_r_equip             - Equipment tmu values.
   --    i_first_pick_loc      - The first picking slot for the batch.
   --    i_aisle_direction     - Direction of the pick aisle.
   --    i_unitized_pull_flag  - Designates if a unitized pull.
   --    io_r_ds_info          - Discrete selection info.  Populated with info
   --                            relevant at pickup time.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error       - A called object returned an user defined
   --                                error.
   --    pl_exc.e_database_error   - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    10/16/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_pickup_time
                (i_r_sel_batch        IN     pl_lm_sel.t_sel_batch_rec,
                 i_r_equip            IN     pl_lmc.t_equip_rec,
                 i_first_pick_loc     IN     float_detail.src_loc%TYPE,
                 i_aisle_direction    IN     aisle_info.direction%TYPE,
                 i_unitized_pull_flag IN     VARCHAR2,
                 io_r_ds_info         IN OUT t_ds_info_rec)
   IS
      l_message       VARCHAR2(256);    -- Message buffer
      l_message_param VARCHAR2(256);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.get_pickup_time';

      l_curr_pickup_point  ds_selection_pickup_object.pickup_point%TYPE := NULL;
      l_first_record_bln           BOOLEAN;
      l_no_pickup_points           PLS_INTEGER;
      l_no_pickup_points_visited   PLS_INTEGER;
      l_pickup_qty                 PLS_INTEGER;  -- The pickup object qty.
      l_prev_pickup_point  ds_selection_pickup_object.pickup_point%TYPE;
      l_r_dist             pl_lmc.t_distance_rec;  -- Point to point distance
      l_r_pickup_dist      pl_lmc.t_distance_rec;  -- Running total of the
                                                   -- pickup distance.
      l_splits_on_batch_bln        BOOLEAN;        -- Are there splits on the
                                                   -- batch?

   BEGIN
      l_message_param := l_object_name || '(' || i_r_sel_batch.batch_no ||
         ',i_r_equip,' || i_r_sel_batch.job_code || ',' ||
         i_first_pick_loc || ',o_pickup_dist)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      l_splits_on_batch_bln :=
                        pl_lm_ds.f_splits_on_batch(i_r_sel_batch.batch_no);

      -- If audit is on then write the pickup points to the audit table.
      IF (pl_lma.g_audit_bln) THEN
         pl_lma.audit_cmt('--------------- Get Pickup Time ---------------',
            pl_lma.ct_na, pl_lma.ct_detail_level_1);
         pl_lma.audit_cmt('Get pickup time.  The pickup time is the time to travel to the pickup point(s), pickup the pickup objects then travel to the first pick slot.',
            pl_lma.ct_na, pl_lma.ct_detail_level_1);

         -- Record the pickup points and what is to be picked up for the
         -- audit report.
         --
         -- prpbcb:  Note that the records are selected twice.  Once here and
         -- then again when calculating the distance.  Another way could be
         -- to select the records into tables then process the tables.  Not
         -- sure how much, if any, it would be faster.
         pl_lma.audit_cmt('Pickup Points Defined for Job Code ' ||
                          i_r_sel_batch.job_code || ':',
                          pl_lma.ct_na, pl_lma.ct_detail_level_1);

         l_no_pickup_points := 0;

         FOR r_pup IN c_gl_pup(i_r_sel_batch.job_code) LOOP

            l_no_pickup_points := l_no_pickup_points + 1;

            pl_lma.audit_cmt('Point: ' ||
                             r_pup.pickup_point ||
                             '  Pickup: ' ||
                             r_pup.pickup_object || ' "' ||
                             r_pup.pickup_object_descrip || '"' ||
                             '  Pickup while selecting: ' ||
                             r_pup.pickup_while_selecting_flag,
                             pl_lma.ct_na, pl_lma.ct_detail_level_1);
         END LOOP;

         IF (l_no_pickup_points = 0) THEN
            pl_lma.audit_cmt('No pickup points found for job code ' ||
                             i_r_sel_batch.job_code || '.',
                             pl_lma.ct_na, pl_lma.ct_detail_level_1);
         END IF;

      END IF;  -- end audit

      -- Initialization
      l_first_record_bln := TRUE;
      l_no_pickup_points := 0;
      l_no_pickup_points_visited := 0;
      l_r_dist.equip_accel_distance := i_r_equip.accel_distance;
      l_r_dist.equip_decel_distance := i_r_equip.decel_distance;

      -- Calculate the distance to the pickup points and calculate
      -- the pickup time.
      FOR r_pup IN c_gl_pup(i_r_sel_batch.job_code) LOOP
 
         -- Objects to pickup while selecting are handled in the item selection
         -- processing.
         IF (r_pup.pickup_while_selecting_flag = 'N') THEN

         l_no_pickup_points := l_no_pickup_points + 1;

         l_message := l_object_name || ':' ||
            r_pup.pickup_order || ':' || r_pup.pickup_object || ':' ||
            r_pup.pickup_point || ':' || r_pup.always_pickup_flag || ':' ||
            r_pup.use_for_splits_flag;

         pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                        NULL, NULL);

         IF (  (r_pup.always_pickup_flag = 'Y')
             OR
               (l_splits_on_batch_bln AND r_pup.use_for_splits_flag = 'Y')
             OR
               (i_unitized_pull_flag = 'Y')) THEN

            l_no_pickup_points_visited := l_no_pickup_points_visited + 1;
            l_curr_pickup_point := r_pup.pickup_point;

            IF (NOT l_first_record_bln) THEN
               pl_lmd.get_pt_to_pt_dist
                              (i_src_point => l_prev_pickup_point,
                               i_dest_point => l_curr_pickup_point,
                               i_equip_rec => i_r_equip,
                               i_follow_aisle_direction_bln => TRUE,
                               io_dist_rec => l_r_dist);

               IF (pl_lma.g_audit_bln) THEN
                  -- FALSE in procedure calls designates traveling empty.
                  pl_lma.audit_travel_distance(i_src_loc =>l_prev_pickup_point,
                                               i_dest_loc =>l_curr_pickup_point,
                                               i_dist_rec => l_r_dist,
                                               i_travel_loaded_bln =>FALSE);
               END IF;

               pl_lmd.add_distance(l_r_pickup_dist, l_r_dist);

            ELSE
               l_first_record_bln := FALSE;
            END IF;

            -- Determine the pickup object quantity.
           l_pickup_qty := f_calc_pickup_qty(r_pup, i_r_sel_batch);

            -- Sum the pickup time.
            io_r_ds_info.pickup_object_time :=
                 io_r_ds_info.pickup_object_time + (r_pup.tmu * l_pickup_qty);

            IF (pl_lma.g_audit_bln) THEN
               pl_lma.ds_audit_pickup_object(r_pup.pickup_object,
                                             r_pup.pickup_point,
                                             r_pup.tmu,
                                             l_pickup_qty);
            END IF;

            l_prev_pickup_point := l_curr_pickup_point;
        
         END IF;
         END IF;  -- end pickup while selecting = 'N'

      END LOOP;

      -- If there were pickup points calculate the distance from the last
      -- pickup point to the first pick slot.
      IF (l_curr_pickup_point IS NOT NULL) THEN
         pl_lmd.get_pt_to_pt_dist(i_src_point => l_curr_pickup_point,
                                  i_dest_point => i_first_pick_loc,
                                  i_equip_rec => i_r_equip,
                                  i_follow_aisle_direction_bln => TRUE,
                                  io_dist_rec => l_r_dist);

         IF (pl_lma.g_audit_bln) THEN
            -- FALSE in procedure calls designates traveling empty.
            pl_lma.audit_travel_distance(i_src_loc =>l_curr_pickup_point,
                                         i_dest_loc => i_first_pick_loc,
                                         i_dist_rec => l_r_dist,
                                         i_travel_loaded_bln => FALSE);
         END IF;

         pl_lmd.add_distance(l_r_pickup_dist, l_r_dist);

         -- Calculate the pickup time in minutes.
         io_r_ds_info.travel_time := 
            (l_r_pickup_dist.accel_distance * i_r_equip.accel_rate_empty) +
            (l_r_pickup_dist.decel_distance * i_r_equip.decel_rate_empty) +
            (l_r_pickup_dist.travel_distance * i_r_equip.trav_rate_empty) +
            l_r_pickup_dist.tia_time;
      ELSE
         -- No pickup points found for the job code or the setup of the
         -- pickup points resulted in no points to be visited.  No points
         -- visited could happen if the "always pickup", "use for splits", ...
         -- columns for the job code are all set to 'N' when setting up the
         -- pickup points for the job code.
         io_r_ds_info.travel_time := 0;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         pl_lma.audit_cmt('Total Pickup Accelerate Distance',
            l_r_pickup_dist.accel_distance, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt('Total Pickup Travel Distance',
            l_r_pickup_dist.travel_distance, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt('Total Pickup Decelerate Distance',
            l_r_pickup_dist.decel_distance, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
            -- RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
            --                         l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END get_pickup_time;


   ------------------------------------------------------------------------
   -- Procedure:
   --    get_dropoff_time
   --
   -- Description:
   --    This procedure calculates the drop off distance for a batch
   --    which is the distance traveled from the last pick slot to the
   --    door(s) then to the starting point.  The can be more than one
   --    door if it is an optimal pull batch.
   --
   -- Parameters:
   --    i_r_sel_batch_no  - Selection batch record.  This is the
   --                        information from floats, float_detail, ...
   --                        tables used to create the selection labor
   --                        mgmt batch.
   --    i_r_equip         - Equipment tmu values.
   --    i_last_pick_loc   - The last pick slot for the batch.
   --    i_aisle_direction - Direction of the last pick slot aisle.
   --    i_opt_pull        - Optimal pull flag for the equipment.  This
   --                        can affects the drop off points since if the
   --                        value is 'Y' the batch can have more than
   --                        one route thus it can have more than one
   --                        drop off point.
   --    i_float_no        - Float number of first float on batch.  Used
   --                        when it is not an optimal pull batch to get
   --                        the destination door number.
   --    io_r_ds_info      - Discrete selection info.  Updated with info
   --                        relevant at drop off time.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an
   --                                 user defined error.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    01/28/02 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE get_dropoff_time
                (i_r_sel_batch       IN     pl_lm_sel.t_sel_batch_rec,
                 i_r_equip           IN     pl_lmc.t_equip_rec,
                 i_last_pick_loc     IN     float_detail.src_loc%TYPE,
                 i_aisle_direction   IN     aisle_info.direction%TYPE,
                 i_opt_pull          IN     sel_equip.opt_pull%TYPE,
                 i_float_no          IN     floats.float_no%TYPE,
                 io_r_ds_info        IN OUT t_ds_info_rec)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_dropoff_time';

      l_door_no      point_distance.point_a%TYPE;  -- Door number where the
                                  -- selector will drop off the floats.
      l_origin       ds_selection_pickup_object.pickup_point%TYPE;
      l_r_dist       pl_lmc.t_distance_rec;        -- Point to point distance

      l_r_dropoff_dist  pl_lmc.t_distance_rec;  -- Running total of the
                                                -- drop off distance.
   BEGIN

      l_message_param := l_object_name || '(i_r_sel_batch' ||
         ' batch_no=[' ||TO_CHAR(i_r_sel_batch.batch_no) ||']' ||
         ',i_r_equip,' || i_last_pick_loc || ',' ||
         i_opt_pull || ',' || TO_CHAR(i_float_no) ||
         ',io_r_ds_info)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Initialization
      l_r_dist.equip_accel_distance := i_r_equip.accel_distance;
      l_r_dist.equip_decel_distance := i_r_equip.decel_distance;

      IF (pl_lma.g_audit_bln) THEN
         pl_lma.audit_cmt('Get drop off distance.  The drop off distance is the distance traveled to the drop off point(s) then to the starting point.',
            pl_lma.ct_na, pl_lma.ct_detail_level_1);
      END IF;  -- end audit

      IF (i_opt_pull != 'Y') THEN
         -- Optimal pull is off.

         -- Get the door where the floats will be dropped off.
         l_door_no := pl_lmc.f_get_destination_door_no(i_float_no);

         -- Get the starting point of the selection batch.
         l_origin := f_get_origin_point(i_r_sel_batch.job_code);

         -- It is possible, though unlikely, there is no starting poin which
         -- indicates no pickup points are defined for the job code.
         IF (l_origin IS NOT NULL) THEN
            IF (pl_lma.g_audit_bln) THEN
               pl_lma.audit_cmt('The starting point is ' || l_origin || '.',
                  pl_lma.ct_na, pl_lma.ct_detail_level_1);
            END IF; -- end audit

         ELSE
            -- No starting point.  Write log message.
            l_message := 'No starting point found for job code ' ||
               i_r_sel_batch.job_code || ' when determining the drop off' ||
               ' distance.';

            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           NULL, NULL);

            IF (pl_lma.g_audit_bln) THEN
               pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                pl_lma.ct_detail_level_1);
            END IF; -- end audit

         END IF;

         -- Get the distance from the last pick slot to the door.
         pl_lmd.get_pt_to_pt_dist(i_src_point => i_last_pick_loc,
                                  i_dest_point => l_door_no,
                                  i_equip_rec => i_r_equip,
                                  i_follow_aisle_direction_bln => TRUE,
                                  io_dist_rec =>l_r_dist);

         IF (pl_lma.g_audit_bln) THEN
            -- TRUE in procedure calls designates traveling loaded.
            pl_lma.audit_travel_distance(i_src_loc => i_last_pick_loc,
                                         i_dest_loc => l_door_no,
                                         i_dist_rec => l_r_dist,
                                         i_travel_loaded_bln => TRUE);
         END IF;

         pl_lmd.add_distance(l_r_dropoff_dist, l_r_dist);

         -- If the selection batch has a point of origin then get the distance
         -- from the last door where the floats were dropped to the origin.
         IF (l_origin IS NOT NULL) THEN
            pl_lmd.get_pt_to_pt_dist(i_src_point => l_door_no,
                                     i_dest_point => l_origin,
                                     i_equip_rec => i_r_equip,
                                     i_follow_aisle_direction_bln => TRUE,
                                     io_dist_rec => l_r_dist);

            IF (pl_lma.g_audit_bln) THEN
               -- TRUE in procedure calls designates traveling loaded.
               pl_lma.audit_travel_distance(i_src_loc => l_door_no,
                                            i_dest_loc => l_origin,
                                            i_dist_rec => l_r_dist,
                                            i_travel_loaded_bln => TRUE);
            END IF;

            pl_lmd.add_distance(l_r_dropoff_dist, l_r_dist);

         END IF;

      ELSE
         -- Optimal pull.
         null;
         pl_lma.audit_cmt(l_object_name || ': Handle optimal pull here.',
                          pl_lma.ct_na, pl_lma.ct_detail_level_1);
      END IF;

      -- Calculate, in minutes, the time required to drop off the pallets at
      -- the door(s).
      io_r_ds_info.travel_time := io_r_ds_info.travel_time +
         (l_r_dropoff_dist.accel_distance * i_r_equip.accel_rate_loaded) +
         (l_r_dropoff_dist.decel_distance * i_r_equip.decel_rate_loaded) +
         (l_r_dropoff_dist.travel_distance * i_r_equip.trav_rate_loaded) +
         l_r_dropoff_dist.tia_time;

      IF (pl_lma.g_audit_bln) THEN
         pl_lma.audit_cmt('Total Drop Off Accelerate Distance',
            l_r_dropoff_dist.accel_distance, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt('Total Drop Off Travel Distance',
            l_r_dropoff_dist.travel_distance, pl_lma.ct_detail_level_2);
         pl_lma.audit_cmt('Total Drop Off Decelerate Distance',
            l_r_dropoff_dist.decel_distance, pl_lma.ct_detail_level_2);
      END IF;  -- end audit

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
            -- RAISE_APPLICATION_ERROR(SQLCODE,
            --                         l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END get_dropoff_time;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_splits_on_batch
   --
   -- Description:
   --    This function determines if splits are to be selected on a
   --    selection batch.
   --
   -- Parameters:
   --    i_batch_no    - Selection batch number.  This is not the labor
   --                    mgmt batch number.
   --  
   -- Return Value:
   --    TRUE   -  The batch has splits.
   --    FALSE  -  The batch has no splits.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error        Oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/13/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   FUNCTION f_splits_on_batch(i_batch_no IN floats.batch_no%TYPE)
   RETURN BOOLEAN
   IS
      l_message        VARCHAR2(128);    -- Message buffer
      l_message_param  VARCHAR2(128);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.f_splits_on_batch';

      l_dummy                VARCHAR2(1);  -- Work area
      l_splits_on_batch_bln  BOOLEAN;      -- Return value

      -- This cursor checks if splits are on the batch.
      CURSOR c_splits(cp_batch_no IN floats.batch_no%TYPE) IS
         SELECT 'x'
           FROM float_detail fd, floats f
          WHERE f.batch_no   = cp_batch_no
            AND fd.float_no  = f.float_no
            AND fd.uom       = 1
            AND fd.qty_alloc > 0;
   BEGIN
      l_message_param := l_object_name || '(' || i_batch_no || ')';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_splits(i_batch_no);
      FETCH c_splits INTO l_dummy;
      l_splits_on_batch_bln := c_splits%FOUND;
      CLOSE c_splits;

      IF (pl_lma.g_audit_bln) THEN
         IF (l_splits_on_batch_bln) THEN
            l_message := 'Batch ' || TO_CHAR(i_batch_no) ||
                         ' has splits to pull.';
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         ELSE
            l_message := 'Batch ' || TO_CHAR(i_batch_no) ||
                         ' has no splits to pull.';
            pl_lma.audit_cmt(l_message, pl_lma.ct_na, pl_lma.ct_detail_level_2);
         END IF;
      END IF;

      RETURN(l_splits_on_batch_bln);

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END f_splits_on_batch;


   ---------------------------------------------------------------------------
   -- Function:
   --    f_get_case_type
   --
   -- Description:
   --    This function determines the case type or split type for an item
   --    which is based on the item's case cube or split cube and correspoding
   --    gross weight.
   --
   --    Each item will have a case type and a split type.  This function is
   --    used to determine the type.
   --
   -- Parameters:
   --    i_cube        - Item's case cube or split cube.
   --    i_g_weight    - Item's gross weight of a case or a split depending
   --                    on if i_cube if for a case or split.
   --                    Note that the pm.g_weight is for a split.
   --  
   -- Return Value:
   --    Case type or null if unable to determine the case type.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error   - Oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/17/01 prpbcb   Created.
   --    03/15/04 prpbcb   Tried different indexes on the case_type_code table
   --                      to see if this improved performance but it did not.
   --                      Using no index was just as fast.
   --    06/14/04 prpbcb   Changed comments to reflect this function can
   --                      return the case type for a split too.  The name
   --                      of parameter i_cube is now misleading.
   ---------------------------------------------------------------------------
   FUNCTION f_get_case_type(i_cube      IN pm.case_cube%TYPE,
                            i_g_weight  IN pm.g_weight%TYPE)
   RETURN VARCHAR2
   IS
      l_message      VARCHAR2(128);    -- Message buffer
      l_object_name  VARCHAR2(61) := gl_pkg_name || '.f_get_case_type';

      l_case_type    case_type_code.case_type%TYPE;   -- Selected case type

      -- This cursor selects the case type.
      -- The cube and weight being matched against the CASE_TYPE table need 
      -- to be rounded to the precision of the CASE_TYPE table columns.
      CURSOR c_case_type(cp_cube      pm.case_cube%TYPE,
                         cp_g_weight  pm.g_weight%TYPE)  IS
         SELECT case_type
           FROM case_type_code ct
          WHERE ROUND(cp_cube, ct_case_cube_precision)
                           BETWEEN ct.min_cube AND ct.max_cube
            AND ROUND(cp_g_weight, ct_g_weight_precision)
                           BETWEEN ct.min_g_weight AND ct.max_g_weight;
   BEGIN
      OPEN c_case_type(i_cube, i_g_weight);

      FETCH c_case_type INTO l_case_type;

      IF (c_case_type%NOTFOUND) THEN
         l_case_type := NULL;
      END IF;

      CLOSE c_case_type;
    
      RETURN(l_case_type);

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name || '(' || TO_CHAR( i_cube) ||
                      ',' || TO_CHAR(i_g_weight) || ')';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END f_get_case_type;


   ------------------------------------------------------------------------
   -- Procedure:
   --    populate_case_type
   --
   -- Description:
   --    This procedure populates the case type and split type for all items
   --    with the appropriate case type.  These are based on the weight and
   --    cube of the case and split.  The case/split type is determined by
   --    looking at the CASE_TYPE_CODE table.  If no case/split type is found
   --    then the column is set to null.
   --
   --    Note that the pm.g_weight is for a split.
   --
   -- Parameters:
   --    o_msg         - Message stating how many item records were 
   --                    processed and how many were updated.
   --  
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/04/02 prpbcb   Created.
   --    06/14/04 prpbcb   Modified to also populate pm.split_type.
   ------------------------------------------------------------------------
   PROCEDURE populate_case_type(o_msg  OUT VARCHAR2)
   IS
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.populate_case_type';

      l_case_type      case_type_code.case_type%TYPE;
      l_split_type     case_type_code.case_type%TYPE;
      l_rec_count      PLS_INTEGER := 0;  -- # of records processed
      l_case_update_count   PLS_INTEGER := 0;  -- # of records where the case
                                               -- type was found.
      l_split_update_count  PLS_INTEGER := 0;  -- # of records where the split
                                               -- type was found.
      l_counter             PLS_INTEGER := 0;  -- Work area
  
      -- Note that the pm.g_weight is for a split.
      CURSOR c_pm IS
         SELECT prod_id, case_cube, split_cube, g_weight, NVL(spc, 1) spc,
                rowid
           FROM pm;
   BEGIN
      FOR r_pm IN c_pm LOOP
         l_case_type := pl_lm_ds.f_get_case_type(r_pm.case_cube,
                                                 r_pm.g_weight * r_pm.spc);
         l_split_type := pl_lm_ds.f_get_case_type(r_pm.split_cube,
                                                  r_pm.g_weight);

         IF (l_case_type IS NOT NULL) THEN
            l_case_update_count := l_case_update_count + 1;
         END IF;

         IF (l_split_type IS NOT NULL) THEN
            l_split_update_count := l_split_update_count + 1;
         END IF;

         UPDATE pm
            SET case_type = l_case_type,
                split_type = l_split_type
         WHERE rowid = r_pm.rowid;

         IF (l_counter = 1000) THEN
            COMMIT;
            l_counter := 0;
         ELSE
            l_counter := l_counter + 1;
         END IF;

           l_rec_count := l_rec_count + 1;

      END LOOP;

      COMMIT;

      o_msg := 'Total number of items: ' || TO_CHAR(l_rec_count) || '.' ||
              '  Case type updated: ' || TO_CHAR(l_case_update_count) || 
              '  Split type updated: ' || TO_CHAR(l_split_update_count) || '.';

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, NULL,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   
   END populate_case_type;


   ------------------------------------------------------------------------
   -- Procedure:
   --    calc_case_split_time
   --
   -- Description:
   --    This procedure calculates the case and split handling time for
   --    a selection batch.  The calculated values will be in TMU units.
   --
   -- Parameters:
   --    i_batch_no    - Selection batch number.
   --    o_case_time   - Case handling time in TMU units.
   --    o_split_time  - Split handling time in TMU units.
   --  
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/31/01 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE calc_case_split_time(i_batch_no   IN  floats.batch_no%TYPE,
                                  o_case_time  OUT NUMBER,
                                  o_split_time OUT NUMBER)
   IS
      l_message       VARCHAR2(128);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.calc_case_split_time';

      -- This cursor selects the case and split time.
      CURSOR c_handling_time IS
         SELECT NVL(SUM(DECODE(fd.uom, 2, ds.tmu_no_case * (fd.qty_alloc/pm.spc),
                                   0)), 0) case_time,
                NVL(SUM(DECODE(fd.uom, 1, ds.tmu_no_split * fd.qty_alloc,
                          0)), 0) split_time
           FROM aisle_info ai,
                ds_tmu ds,
                pm,
                loc l,
                float_detail fd,
                floats f
          WHERE fd.float_no         = f.float_no
            AND f.batch_no          = i_batch_no
            AND l.logi_loc          = fd.src_loc
            AND ai.name             = SUBSTR(l.logi_loc,1,2)
            AND pm.prod_id          = fd.prod_id
            AND pm.cust_pref_vendor = pm.cust_pref_vendor
            AND ds.sub_area_code    = ai.sub_area_code
            AND ds.slot_type        = l.slot_type
            AND ds.pallet_type      = l.pallet_type
            AND ds.floor_height     = l.floor_height
            AND ds.pik_level        = l.pik_level
            AND ds.case_type        = pm.case_type;
   BEGIN
      OPEN c_handling_time;
      FETCH c_handling_time INTO o_case_time, o_split_time;
      CLOSE c_handling_time;

   EXCEPTION
      WHEN OTHERS THEN
         l_message := l_object_name || '(' || TO_CHAR(i_batch_no) || ')';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   
   END calc_case_split_time;


   ------------------------------------------------------------------------
   -- Procedure:
   --    get_forklift_cross_aisles
   --
   -- Description:
   --    This procedure function gets the forklift cross aisle information
   --    for an aisle.
   --
   -- Parameters:
   --    i_from_aisle             - Aisle.
   --    o_from_bay               - Cross aisle bay on i_from_aisle.
   --    o_to_aisle               - Next aisle over using the cross aisle.
   --    o_to_bay                 - The bay on o_to_aisle on the cross aisle.
   --    o_found_cross_aisle_bln  - Indicates if cross aisle found.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Oracle error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/19/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_forklift_cross_aisles
              (i_from_aisle            IN  forklift_cross_aisle.from_aisle%TYPE,
               o_from_bay              OUT forklift_cross_aisle.from_bay%TYPE,
               o_to_aisle              OUT forklift_cross_aisle.to_aisle%TYPE,
               o_to_bay                OUT forklift_cross_aisle.to_bay%TYPE,
               o_found_cross_aisle_bln OUT BOOLEAN)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                              '.get_forklift_cross_aisles';

      l_from_bay        forklift_cross_aisle.from_bay%TYPE;
      l_to_aisle        forklift_cross_aisle.to_aisle%TYPE;
      l_to_bay          forklift_cross_aisle.to_bay%TYPE;

      CURSOR c_cross_aisle IS
         SELECT from_bay, to_aisle, to_bay
           FROM forklift_cross_aisle
          WHERE from_aisle = i_from_aisle;
   BEGIN

      l_message_param := l_object_name || '(' || i_from_aisle ||
         ',o_from_bay, o_to_aisle, o_to_bay, o_found_cross_aisle_bln)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_cross_aisle;
      FETCH c_cross_aisle INTO l_from_bay, l_to_aisle, l_to_bay;

      IF (c_cross_aisle%NOTFOUND) THEN
         o_found_cross_aisle_bln := FALSE;
      ELSE
         o_from_bay := l_from_bay;
         o_to_aisle := l_to_aisle;
         o_to_bay := l_to_bay;
         o_found_cross_aisle_bln := TRUE;

         l_message := 'i_from_aisle: ' || i_from_aisle || ' ' ||
                      'o_from_bay: '   || l_from_bay || ' ' ||
                      'i_to_aisle: '   || l_to_aisle || ' ' ||
                      'o_to_bay: '     || l_to_bay;

         pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                        NULL, NULL);

      END IF;

      CLOSE c_cross_aisle;

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END get_forklift_cross_aisles;


   ------------------------------------------------------------------------
   -- Procedure:
   --    get_picking_slots
   --
   -- Description:
   --    This procedure gets the max picking slot an item is to be picked from
   --    on an aisle and the min picking slot an item is to be picked from on
   --    the next aisle.  This information is used to determine if a cross
   --    aisle is to be used.
   --
   -- Parameters:
   --    i_batch_no                    - Selection batch being processed.
   --    i_pik_aisle                   - Aisle being processed.
   --    o_max_picking_slot            - Maximum picking slot to pick from
   --                                    in i_pik_aisle.
   --    o_next_aisle_pik_aisle        - The next aisle after i_pik_aisle on
   --                                    the selection batch.
   --    o_next_aisle_min_picking_slot - The next aisle mininum slot to pick
   --                                    from.
   --    o_found_picking_slot_bln      - Indicates if there is a slot on the
   --                                    next aisle to pick from.
   --
   -- Exceptions raised:
   --    pl_exc.e_database_error  - Oracle error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/19/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE get_picking_slots
               (i_batch_no                    IN  floats.batch_no%TYPE,
                i_pik_aisle                   IN  loc.pik_aisle%TYPE,
                o_max_picking_slot            OUT loc.pik_path%TYPE,
                o_next_aisle_pik_aisle        OUT loc.pik_aisle%TYPE,
                o_next_aisle_min_picking_slot OUT loc.pik_slot%TYPE,
                o_found_picking_slot_bln      OUT BOOLEAN)
   IS
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.get_picking_slots';

      l_next_aisle_pik_aisle         loc.pik_aisle%TYPE;
      l_next_aisle_min_picking_path  loc.pik_path%TYPE;
   
      -- This cursor selects the last picking slot in an aisle for a batch.
      -- The last picking slot will be the one with the maximum pik_aisle value.
      CURSOR c_max_picking_slot IS
         SELECT MAX(l.pik_slot)
           FROM loc l, float_detail fd, floats f
          WHERE fd.float_no  = f.float_no
            AND l.logi_loc   = fd.src_loc
            AND l.pik_aisle  = i_pik_aisle
            AND f.batch_no   = i_batch_no;

      -- This cursor selects the first picking slot in the next aisle for a
      -- batch.  This slot will be the one with the minimum pik_aisle value.
      CURSOR c_min_picking_path IS
         SELECT MIN(l.pik_path)
           FROM loc l, float_detail fd, floats f
          WHERE fd.float_no  = f.float_no
            AND l.logi_loc   = fd.src_loc
            AND l.pik_aisle  > i_pik_aisle
            AND f.batch_no   = i_batch_no;
   BEGIN

      l_message_param := l_object_name || '(' || TO_CHAR(i_batch_no) ||
                   ',' || TO_CHAR(i_pik_aisle) ||
                   ',o_max_picking_slot, o_next_aisle_pik_aisle,' ||
                   'o_next_aisle_min_picking_slot,o_found_picking_slot_bln)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      OPEN c_max_picking_slot;
      FETCH c_max_picking_slot INTO o_max_picking_slot;
      CLOSE c_max_picking_slot;

      OPEN c_min_picking_path;
      FETCH c_min_picking_path INTO l_next_aisle_min_picking_path;
      IF (l_next_aisle_min_picking_path IS NOT NULL) THEN
         o_next_aisle_pik_aisle :=
                       TO_NUMBER(SUBSTR(l_next_aisle_min_picking_path, 1, 3));
         o_next_aisle_min_picking_slot :=
                       TO_NUMBER(SUBSTR(l_next_aisle_min_picking_path, 4, 3));
         o_found_picking_slot_bln := TRUE;
      ELSE
         o_found_picking_slot_bln := FALSE;
      END IF;
     
      CLOSE c_min_picking_path;

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END get_picking_slots;


   ------------------------------------------------------------------------
   -- Procedure:
   --    use_cross_aisle
   --
   -- Description:
   --    This procedure determines if a cross aisle is to be used.
   --
   -- Parameters:
   --    i_batch_no             - Selection batch being processed.
   --    i_pik_aisle            - pik_aisle value of the aisle being processed.
   --    i_aisle                - Aisle being processed.
   --    i_to_cross_pik_slot    - pik_slot value of the bay at the cross aisle
   --    o_cross_aisle_from_bay - Cross aisle bay.
   --    o_cross_aisle_to_aisle - The next aisle over at the cross aisle.
   --    o_cross_aisle_to_bay   - The bay on the next aisle over at the cross
   --                             aisle.
   --    o_use_cross_aisle_bln  - Indicates to use or not use the cross aisle.
   --
   -- o_use_cross_aisle_bln is IN OUT so it can be read by this procedure.
   --
   -- Exceptions raised:
   --    pl_exc.e_data_error      - A called object returned an user defined
   --                               error.
   --    pl_exc.e_database_error  - Oracle error occurred.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/19/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE use_cross_aisle
              (i_batch_no              IN  floats.batch_no%TYPE,
               i_pik_aisle             IN  loc.pik_aisle%TYPE,
               i_aisle                 IN  forklift_cross_aisle.from_aisle%TYPE,
               i_to_cross_pik_slot     IN  cross_aisle.to_cross%TYPE,
               o_cross_aisle_from_bay  OUT forklift_cross_aisle.from_bay%TYPE,
               o_cross_aisle_to_aisle  OUT forklift_cross_aisle.to_aisle%TYPE,
               o_cross_aisle_to_bay    OUT forklift_cross_aisle.to_bay%TYPE,
               o_use_cross_aisle_bln   IN  OUT BOOLEAN)
   IS
      l_message        VARCHAR2(256);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.use_cross_aisle';

      l_fkca_from_bay         forklift_cross_aisle.from_bay%TYPE;
      l_fkca_to_aisle         forklift_cross_aisle.to_aisle%TYPE;
      l_fkca_to_bay           forklift_cross_aisle.to_bay%TYPE;
      l_fkca_found_bln        BOOLEAN;

      l_max_picking_slot             loc.pik_path%TYPE;
      l_next_aisle_pik_aisle         loc.pik_aisle%TYPE;
      l_next_aisle_min_picking_slot  loc.pik_slot%TYPE;

      l_from_cross_pik_slot          cross_aisle.from_cross%TYPE;

      l_found_picking_slot_bln       BOOLEAN;

      CURSOR c_cross_aisle IS
         SELECT from_cross
           FROM cross_aisle
          WHERE pick_aisle = l_next_aisle_pik_aisle;
   BEGIN

      l_message_param := l_object_name || '(' || TO_CHAR(i_batch_no) || ',' ||
                    TO_CHAR(i_pik_aisle) || ',' ||
                    i_aisle || ',' || TO_CHAR(i_to_cross_pik_slot) || ',' ||
                    'o_cross_aisle_from_bay, o_cross_aisle_to_aisle,' ||
                    'o_cross_aisle_to_bay, o_use_cross_aisle_bln)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      get_forklift_cross_aisles(i_aisle, l_fkca_from_bay,
                                l_fkca_to_aisle, l_fkca_to_bay,
                                l_fkca_found_bln);

      IF (l_fkca_found_bln) THEN
         -- Forklift cross aisles defined.

         get_picking_slots(i_batch_no, i_pik_aisle, l_max_picking_slot,
                           l_next_aisle_pik_aisle,
                           l_next_aisle_min_picking_slot,
                           l_found_picking_slot_bln);

         IF (l_found_picking_slot_bln) THEN
            OPEN c_cross_aisle;
            FETCH c_cross_aisle INTO l_from_cross_pik_slot;

            IF (c_cross_aisle%FOUND) THEN

               l_message := 'Found cross aisle.' ||
                  ' l_max_picking_slot: ' || TO_CHAR(l_max_picking_slot, 999) ||
                  ' i_to_cross_pik_slot: ' ||
                  TO_CHAR(i_to_cross_pik_slot, 999) ||
                  ' l_next_aisle_min_picking_slot: ' ||
                  TO_CHAR(l_next_aisle_min_picking_slot, 999);

               pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message,
                              NULL, NULL);

               IF (l_max_picking_slot <= i_to_cross_pik_slot AND
                   l_next_aisle_min_picking_slot >= l_from_cross_pik_slot) THEN
                  o_cross_aisle_from_bay := l_fkca_from_bay;
                  o_cross_aisle_to_aisle := l_fkca_to_aisle;
                  o_cross_aisle_to_bay := l_fkca_to_bay;
                  o_use_cross_aisle_bln := TRUE;
               ELSE
                  o_use_cross_aisle_bln := FALSE;
               END IF;
            ELSE
               o_use_cross_aisle_bln := FALSE;
            END IF;

            CLOSE c_cross_aisle;

         ELSE
            o_use_cross_aisle_bln := FALSE;
         END IF;
      ELSE
         o_use_cross_aisle_bln := FALSE;
      END IF;

      IF (pl_lma.g_audit_bln) THEN
         IF (o_use_cross_aisle_bln) THEN
            pl_lma.audit_cmt('Use cross aisle.', pl_lma.ct_na,
                             pl_lma.ct_detail_level_1);
         ELSE
            pl_lma.audit_cmt('Do not use cross aisle.', pl_lma.ct_na,
                             pl_lma.ct_detail_level_1);
         END IF;
      END IF;
    
   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
            -- RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
            --                         l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END use_cross_aisle;


-- AAAAA
   ---------------------------------------------------------------------------
   -- Procedure:
   --    calc_ds_time
   --
   -- Description:
   --    This procedure calculates the time for discrete selection.
   --    The selection batch has been created before calling this procedure.
   --    The following values are calculated then the selection batch columns
   --    are updated with these values.
   --    
   --    Value to Calculate                             BATCH Column Updated
   --    --------------------------------------------   ----------------------
   --    Case handling time (in minutes)                ds_case_time
   --    Split handling time (in minutes)               ds_split_time
   --    Equipment travel time (in minutes)             kvi_distance
   --    Feet walked                                    kvi_walk
   --
   --    If i_audit_only_bln is TRUE then audit records are created.
   --
   -- Parameters:
   --    i_r_sel_batch_no  - Selection batch record.  This is the information
   --                        from floats, float_detail, ... used to create
   --                        the selection labor mgmt batch.
   --    i_audit_only_bln  - Designates to only audit the batch.  The
   --                        processing is the same but only audit records
   --                        are created.  The labor mgmt batch must exist. 
   --                        No labor mgmt batches are created or updated.  
   --                        This parameter is optional.
   --                        The default value is FALSE.
   --
   -- Exceptions raised:
   --    User defined exception     - A called object returned an user
   --                               - defined error.
   --    pl_exc.e_database_error    - Any other error.
   --
   -- Called by:
   --    pl_lm_sel.create_selection_batches
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    12/19/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE calc_ds_time(i_r_sel_batch     IN pl_lm_sel.t_sel_batch_rec,
                          i_audit_only_bln  IN BOOLEAN := FALSE)
   IS
      l_message        VARCHAR2(512);    -- Message buffer
      l_message_param  VARCHAR2(256);    -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.calc_ds_time';

      l_aisle_to_aisle_dist    NUMBER := 0;  -- Aisle to aisle distance.
      l_bay_to_bay_dist        NUMBER := 0;  -- Bay to bay distance.
      l_counter                PLS_INTEGER;
      l_dist                   NUMBER := 0;  -- Work variable
      l_dock_num               point_distance.point_dock%TYPE; -- The dock
                                     -- number for the selection location.
      l_max_picking_slot             loc.pik_path%TYPE;
      l_next_aisle_min_picking_slot  loc.pik_slot%TYPE;
      l_next_aisle_pik_aisle         loc.pik_aisle%TYPE;
      l_parked_at_cross_aisle_bln  BOOLEAN;    -- Indicates if the equipment is
                                               -- parked at the cross aisle.
      l_point_type             point_distance.point_type%TYPE; -- Holding place
                                       -- for the point type of the selection
                                       -- location.  Should be a bay.
      l_save_float_no          floats.float_no%TYPE;  -- For saving the float
                                  -- number because the float number is needed
                                  -- after processing the items.
      l_save_opt_pull          sel_equip.opt_pull%TYPE;  -- Optimal pull flag
                                   -- for the equipment.  Need to save it
                                   -- since it is needed after processing
                                   -- the items.
      l_r_dist                 pl_lmc.t_distance_rec; -- Point to point distance
      l_r_ds_info              t_ds_info_rec;
      l_r_equip                pl_lmc.t_equip_rec;  -- Equipment tmu values.
      l_r_total_dist           pl_lmc.t_distance_rec;  -- Running total of the
                                                   -- point to point distances.

      l_temp_bay_to_bay_dist   NUMBER := 0;  -- Holding area

      -----------------------------------------------
      ---------- Walking distance variables ---------
      -----------------------------------------------
      l_walk_bln               BOOLEAN; -- Designates if walking to slot.
      l_walk_dist              NUMBER; -- Distance to walk.
      l_walk_src_bay           bay_distance.bay%TYPE;  -- Bay to walk from.
      l_walk_src_bay_dist      NUMBER; -- Bay distance to the bay to walk from.
      l_walk_src_loc           loc.logi_loc%TYPE;  -- Location to walk from.

      --------------------------------------------
      ---------- Saving previous values ----------
      --------------------------------------------
      l_previous_aisle         bay_distance.aisle%TYPE     := NULL;
      l_previous_bay           bay_distance.bay%TYPE       := NULL;
      l_previous_bay_dist      bay_distance.bay_dist%TYPE  := NULL;
      l_previous_direction     aisle_info.direction%TYPE   := NULL;
      l_previous_pik_aisle     loc.pik_aisle%TYPE          := NULL;
      l_previous_pik_slot      loc.pik_slot%TYPE           := NULL;
      l_previous_pick_loc      float_detail.src_loc%TYPE   := NULL;

      -------------------------------------------
      ---------- Cross aisle variables ----------
      -------------------------------------------
      -- Forklift
      l_fkca_from_bay         forklift_cross_aisle.from_bay%TYPE;
      l_fkca_to_aisle         forklift_cross_aisle.to_aisle%TYPE;
      l_fkca_to_bay           forklift_cross_aisle.to_bay%TYPE;
      l_fkca_found_bln        BOOLEAN;

      -- Order selection
      l_cross_aisle_from_bay  forklift_cross_aisle.from_bay%TYPE;
      l_cross_aisle_to_aisle  forklift_cross_aisle.to_aisle%TYPE;
      l_cross_aisle_to_bay    forklift_cross_aisle.to_bay%TYPE;
      l_use_cross_aisle_bln   BOOLEAN;

   BEGIN

      IF (i_audit_only_bln) THEN
         l_message := 'TRUE';
      ELSE
         l_message := 'FALSE';
      END IF;

      l_message_param := l_object_name || '(' ||
        'i_r_sel.batch_no[' || TO_CHAR(i_r_sel_batch.batch_no) || ']' ||
        '  i_r_sel_batch.lm_batch_no[' || i_r_sel_batch.lm_batch_no || ']' ||
        ',i_audit_only_bln[' || l_message || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Initialization
      l_counter := 0;
      l_use_cross_aisle_bln := FALSE;
      l_parked_at_cross_aisle_bln := FALSE;

      -- Process the records in the selection batch.
      <<item_loop>>
      FOR r_item in c_item(i_r_sel_batch.batch_no) LOOP
         l_counter := l_counter + 1;
         l_dist := 0;
         l_walk_bln := FALSE;

         -- Clear the distance record.
         l_r_dist.accel_distance   := 0;
         l_r_dist.decel_distance   := 0;
         l_r_dist.travel_distance  := 0;
         l_r_dist.total_distance   := 0;
         l_r_dist.tia_time         := 0;
         l_r_dist.distance_time    := 0;

         DBMS_OUTPUT.PUT_LINE('=============================================');
         --print_rec(r_item);

         -- Initialization required after first record selected.  Need to
         -- retrieve values and save others from r_item and get the
         -- pickup distance.
         IF (l_counter = 1) THEN
            l_walk_src_bay := r_item.bay;
            l_walk_src_loc := r_item.pick_loc;
            l_walk_src_bay_dist := r_item.bay_dist;
            l_save_float_no := r_item.float_no;
            l_save_opt_pull := r_item.opt_pull;
            l_r_equip.equip_id := r_item.equip_id;
            pl_lmg.get_equip_values(l_r_equip);
            l_r_dist.equip_accel_distance := l_r_equip.accel_distance;
            l_r_dist.equip_decel_distance := l_r_equip.decel_distance;
            pl_lmd.get_point_type(r_item.pick_loc, l_point_type, l_dock_num);

            -- Set globals used by auditing if auditing is on.
            IF (pl_lma.g_audit_bln) THEN
               pl_lma.set_batch_no(i_r_sel_batch.lm_batch_no);
               pl_lma.set_equip_rec(l_r_equip);
               pl_lma.set_audit_func(pl_lma.ct_audit_func_ds);
            END IF;

            -- Get distance traveled to pickup the labels and pallets before
            -- starting the actual picking.
            get_pickup_time(i_r_sel_batch,
                            l_r_equip,
                            r_item.pick_loc,
                            r_item.direction,
                            r_item.unitized_pull_flag,
                            l_r_ds_info);

            -- If auditing is on write a separation line to make the audit
            -- report more readable.
            IF (pl_lma.g_audit_bln) THEN
               pl_lma.audit_cmt('--------------- Start Picking ---------------',
                                pl_lma.ct_na, pl_lma.ct_detail_level_1);
            END IF;

         END IF;  -- end if counter = 1

         -- See if cross aisle is to be used.
         IF ( ((r_item.aisle != l_previous_aisle) OR l_counter = 1)
              AND r_item.to_cross IS NOT NULL) THEN
            use_cross_aisle(i_r_sel_batch.batch_no,
                            r_item.pik_aisle,
                            r_item.aisle,
                            r_item.to_cross,
                            l_cross_aisle_from_bay,
                            l_cross_aisle_to_aisle,
                            l_cross_aisle_to_bay,
                            l_use_cross_aisle_bln);
         ELSE
            l_use_cross_aisle_bln := FALSE;
         END IF;

         -- Get the distance from the previous pick location to the current
         -- pick location.  We do not do this for the first pick location
         -- because it is processed when determining the pickup distance.
         IF (l_counter > 1) THEN
            IF (pl_lma.g_audit_bln) THEN
               pl_lma.audit_cmt('*** Get Point to Point Distance  ' ||
                  l_previous_pick_loc || ' ->' || r_item.pick_loc || ' ***',
                  pl_lma.ct_na, pl_lma.ct_detail_level_2);
            END IF;  -- end audit

            -- Check for change of aisle.
            IF (r_item.aisle != l_previous_aisle) THEN
               -- Aisle change.
               -- If using cross aisle then get following distance:
               --    - distance from previous aisle to current aisle.
               -- If not using cross aisle then get following distances:
               --    - distance from previous bay to end of previous aisle.
               --    - distance from previous aisle to current aisle.
               --    - distance from start of current aisle to current bay.

               IF (pl_lma.g_audit_bln) THEN
                  pl_lma.audit_cmt('Change in aisle.', pl_lma.ct_na,
                                   pl_lma.ct_detail_level_2);
               END IF;

               -- Need to initialize the walk variables to reflect the
               -- new aisle.
               l_walk_src_bay := r_item.bay;
               l_walk_src_loc := r_item.pick_loc;
               l_walk_src_bay_dist := r_item.bay_dist;

               IF (l_use_cross_aisle_bln) THEN
                  l_aisle_to_aisle_dist :=
                       pl_lmd.f_get_aisle_to_aisle_dist(l_dock_num,
                                              l_previous_aisle, r_item.aisle);

                  l_dist := l_dist + l_aisle_to_aisle_dist;

                  IF (pl_lma.g_audit_bln) THEN
                     pl_lma.audit_cmt('Equipment stopped at cross aisle' ||
                           ' located at aisle ' || r_item.aisle || ' bay '  ||
                           l_cross_aisle_from_bay || '.',
                           pl_lma.ct_na, pl_lma.ct_detail_level_2);
                     pl_lma.audit_cmt('Get aisle to aisle distance.',
                                      pl_lma.ct_na, pl_lma.ct_detail_level_2);
                     pl_lma.audit_cmt('Aisle to aisle distance is: ' ||
                                      TO_CHAR(l_aisle_to_aisle_dist),
                                      pl_lma.ct_na, pl_lma.ct_detail_level_2);
                  END IF;  -- end audit
               ELSE
                  l_bay_to_bay_dist :=
                        pl_lmd.f_ds_get_bay_to_bay_dist(l_dock_num,
                                   l_previous_aisle, l_previous_bay,
                                   l_previous_direction, r_item.aisle,
                                   r_item.bay, r_item.direction);

                  IF (pl_lma.g_audit_bln) THEN
                     pl_lma.audit_cmt('Bay to bay distance: ' ||
                                      TO_CHAR(l_bay_to_bay_dist), pl_lma.ct_na,
                                      pl_lma.ct_detail_level_2);
                  END IF;

                  l_dist := l_dist + l_bay_to_bay_dist;
               END IF;

               l_parked_at_cross_aisle_bln := FALSE;

            ELSE
               -- No aisle change.
               -- The previous location and the current location are on the
               -- same aisle.  If using a cross aisle then the distance will
               -- be one of the following:
               --    - Equipment travel time from the previous pick slot to the
               --      pick slot if the cross aisle has not been reached
               --      and not walking to the pick slot.
               --    - Equipment travel time from the previous pick slot
               --      to the cross aisle bay if the picking location is past
               --      the cross aisle bay then time to walking distance from
               --      the cross aisle bay to the picking slot then back to the
               --      cross aisle bay.
               --    - Walking distance from the cross aisle bay to
               --      the picking slot then back to the cross aisle bay.
               -- If not using a cross aisle then distance will be one of
               -- the following:
               --    - Walking distance from the slot the equipment
               --      is stopped to the pick slot if the distance between
               --      these two slots <= max walking distance.
               --    - Equipment travel time from the previous pick slot to the
               --      pick slot.

               IF (l_use_cross_aisle_bln) THEN
                  -- Using cross aisle.

                  IF (r_item.bay <= l_cross_aisle_from_bay) THEN
                     -- Have not reached the cross aisle.
                     l_bay_to_bay_dist := ABS(l_previous_bay_dist -
                                              r_item.bay_dist);

                  ELSIF (NOT l_parked_at_cross_aisle_bln) THEN
                     -- The previous item picked was before the cross aisle
                     -- and the item to pick is after the cross aisle.  Travel 
                     -- to the cross aisle, stop the equipment, walk to
                     -- the pick slot then walk back to the equipment.

                     -- Get the distance from the previous pick slot to the
                     -- cross aisle.
                     l_bay_to_bay_dist := pl_lmd.f_get_bay_to_bay_on_aisle_dist
                                             (r_item.aisle, l_previous_bay,
                                              l_cross_aisle_from_bay);

                     -- Get the distance from the cross aisle to the pick slot.
                     -- The selector will walk this distance.
                     l_temp_bay_to_bay_dist :=
                                 pl_lmd.f_get_bay_to_bay_on_aisle_dist
                                      (r_item.aisle, l_cross_aisle_from_bay,
                                       r_item.bay);
                     l_r_ds_info.walk_feet := l_r_ds_info.walk_feet +
                                              (l_temp_bay_to_bay_dist * 2);

                     l_parked_at_cross_aisle_bln := TRUE;

                     IF (pl_lma.g_audit_bln) THEN
                        pl_lma.audit_cmt('Stop equipment at cross aisle ' ||
                           r_item.aisle || l_cross_aisle_from_bay || '.' ||
                           '  Walk to slot ' || r_item.pick_loc ||
                           '  which is ' || TO_CHAR(l_temp_bay_to_bay_dist) ||
                           '  feet away,' ||
                           ' pick item then walk back to the equipment.',
                           pl_lma.ct_na, pl_lma.ct_detail_level_1);
                        pl_lma.audit_cmt('Total feet walked.',
                           (l_temp_bay_to_bay_dist * 2),
                           pl_lma.ct_detail_level_1);
                     END IF;  -- end audit

                  ELSE
                     -- The equipment is stopped at the cross aisle.  The
                     -- selector will walk to the pick slot, pick the item
                     -- then walk back to the equipment.
                     l_temp_bay_to_bay_dist :=
                         pl_lmd.f_get_bay_to_bay_on_aisle_dist (r_item.aisle,
                                       l_cross_aisle_from_bay, r_item.bay);

                     l_r_ds_info.walk_feet := l_r_ds_info.walk_feet +
                                              (l_temp_bay_to_bay_dist * 2);

                     IF (pl_lma.g_audit_bln) THEN
                        pl_lma.audit_cmt('Equipment stopped at cross aisle ' ||
                           r_item.aisle || l_cross_aisle_from_bay || '.' ||
                           '  Walk to slot ' || r_item.pick_loc ||
                           '  which is ' || TO_CHAR(l_temp_bay_to_bay_dist) ||
                           '  feet away,' ||
                           ' pick item then walk back to the equipment.',
                        pl_lma.ct_na, pl_lma.ct_detail_level_1);
                        pl_lma.audit_cmt('Total feet walked.',
                           (l_temp_bay_to_bay_dist * 2),
                           pl_lma.ct_detail_level_1);
                     END IF;  -- end audit

                  END IF;
             
                  l_dist := l_dist + l_bay_to_bay_dist;

               ELSE
                  -- Not using cross aisle or it does not exist.
                  -- Either leave the equipment at the slot it is stopped at
                  -- and walk to the pick slot or travel with the equipment
                  -- to the pick slot.
                  l_walk_dist := ABS(r_item.bay_dist - l_walk_src_bay_dist);

                  IF (l_walk_dist <= r_item.max_walking_dist) THEN
                     -- Leave the equipment where it is at, walk to the
                     -- pick slot, pick the item then walk back to the
                     -- equipment.
                     l_walk_bln := TRUE;
                     l_r_ds_info.walk_feet := l_r_ds_info.walk_feet +
                                              (l_walk_dist * 2);
                     IF (pl_lma.g_audit_bln) THEN
                        l_message := 'The distance from ' ||
                           l_walk_src_loc || ' to ' || r_item.pick_loc ||
                           ' is ' || TO_CHAR(l_walk_dist) ||
                           ' feet which is less than' ||
                           ' or equal to the maximum walk distance of ' ||
                           TO_CHAR(r_item.max_walking_dist) || '.  Walk to' ||
                           ' the pick slot.';
                        pl_lma.audit_cmt(l_message, pl_lma.ct_na,
                                         pl_lma.ct_detail_level_2);

                        l_message := 'Walk ' || TO_CHAR(l_walk_dist) ||
                           ' feet from ' || l_walk_src_loc || ' to ' ||
                           r_item.pick_loc || ', pick item then' || 
                           ' walk back.';
                        pl_lma.audit_cmt(l_message, l_walk_dist * 2,
                                         pl_lma.ct_detail_level_1);
                     END IF;  -- end audit

                  ELSE
                     -- Travel to the pick slot.
                     l_bay_to_bay_dist := ABS(l_previous_bay_dist -
                                              r_item.bay_dist);

                     IF (pl_lma.g_audit_bln) THEN
                        pl_lma.audit_cmt('Bay to bay distance.  From bay: ' ||
                            l_previous_bay || '  To bay: ' || r_item.bay ||
                            ' Distance: ' || TO_CHAR(l_bay_to_bay_dist, 999.9),
                            pl_lma.ct_na, pl_lma.ct_detail_level_2);
                     END IF;  -- end audit

                     l_dist := l_dist + l_bay_to_bay_dist;


                  END IF;

               END IF;   -- end if using cross aisle

            END IF;  -- end if same aisle

            l_r_dist.total_distance := l_dist;
            pl_lmd.segment_distance(l_r_dist);

            IF (pl_lma.g_audit_bln) THEN
               -- TRUE in procedure calls designates traveling loaded.
               pl_lma.audit_travel_distance(i_src_loc => l_previous_pick_loc,
                                            i_dest_loc => r_item.pick_loc,
                                            i_dist_rec => l_r_dist,
                                            i_travel_loaded_bln => TRUE);
            END IF; -- end audit

         END IF;  -- end IF (l_counter > 1)

         l_previous_aisle := r_item.aisle;
         l_previous_bay := r_item.bay;
         l_previous_pick_loc := r_item.pick_loc;
         l_previous_pik_aisle := r_item.pik_aisle;
         l_previous_pik_slot := r_item.pik_slot;
         l_previous_bay_dist := r_item.bay_dist;
         l_previous_direction := r_item.direction;

         -- Sum things up.
         l_r_ds_info.ds_case_time := l_r_ds_info.ds_case_time +
                                             r_item.item_total_case_tmu;
         l_r_ds_info.ds_split_time := l_r_ds_info.ds_split_time +
                                             r_item.item_total_split_tmu;

         -- If a DS TMU record does not exist for the slot then write a aplog
         -- message.  The view the cursor is based on would have used default
         -- values.
         IF (r_item.ds_tmu_record_exists = 'N') THEN
            -- No tmu values are setup for the location.  The view would have
            -- used the default values.
            -- Write aplog message.
            l_message := 'Selection batch[' ||
               TO_CHAR(i_r_sel_batch.batch_no) || ']' ||
               '  Labor mgmt batch[' || i_r_sel_batch.lm_batch_no || ']' ||
               '  Location[' || r_item.pick_loc || ']' ||
               '  Item[' || r_item.prod_id || ']' ||
               '  Case Type[' || r_item.case_type || ']' ||
               '  TMU values not setup for this location and case type.' ||
               '  Default values used.';
            pl_log.ins_msg(pl_lmc.ct_warn_msg, l_object_name, l_message,
                           pl_exc.ct_data_error, NULL);

            IF (pl_lma.g_audit_bln) THEN
               pl_lma.audit_cmt('TMU values not setup for location ' ||
                  r_item.pick_loc || ' and case type ' ||
                  r_item.case_type || '.  Default values used.',
                  pl_lma.ct_na, pl_lma.ct_detail_level_1);
            END IF;  -- end audit
         END IF;

         -- Keep running total of the distance.
         pl_lmd.add_distance(l_r_total_dist, l_r_dist); 

         -- print_item_tmu_line(r_item);    -- debug stuff

         IF (pl_lma.g_audit_bln) THEN
            -- Write audit record for the pick time.
            pl_lma.ds_audit_pick_time(r_item.prod_id, r_item.pick_loc,
                                      r_item.no_cases, r_item.no_splits,
                                      r_item.tmu_no_case, r_item.tmu_no_split);
         END IF;  -- end audit

         DBMS_OUTPUT.PUT_LINE('=============================================');

      END LOOP item_loop;

      -- If items found on the batch then calculate the point to point travel
      -- time, get the drop off distance then update
      -- the selection labor mgmt batch.
      IF (l_counter > 0) THEN

         -- If auditing is on write a separation line to make the audit
         -- report more readable.
         IF (pl_lma.g_audit_bln) THEN
            pl_lma.audit_cmt('--------------- End Picking ---------------',
                             pl_lma.ct_na, pl_lma.ct_detail_level_1);
         END IF;

         -- Calculate, in minutes, the time required to travel between the
         -- pick slots.
         l_r_ds_info.travel_time := l_r_ds_info.travel_time +
            (l_r_total_dist.accel_distance * l_r_equip.accel_rate_loaded) +
            (l_r_total_dist.decel_distance * l_r_equip.decel_rate_loaded) +
            (l_r_total_dist.travel_distance * l_r_equip.trav_rate_loaded) +
            l_r_total_dist.tia_time;

         -- Get the time required to drop off the pallets at the door(s).
         get_dropoff_time(i_r_sel_batch,
                          l_r_equip,
                          l_previous_pick_loc,
                          l_previous_direction,
                          l_save_opt_pull,
                          l_save_float_no,
                          l_r_ds_info);

         -- Update the batch with the calculated discrete selection values.
         -- If only auditing the batch then no update is made.
         IF (NOT i_audit_only_bln) THEN
            update_ds_time(i_r_sel_batch.lm_batch_no, l_r_ds_info);
         END IF;

         -- Audit the manual time if auditing is on.
         IF (pl_lma.g_audit_bln) THEN
            pl_lma.ds_audit_manual_time(i_r_sel_batch.lm_batch_no);
         END IF;  -- end audit

      END IF;

      DBMS_OUTPUT.PUT_LINE('=================================================');
      DBMS_OUTPUT.PUT_LINE('Total Case TMU: ' ||
           TO_CHAR(l_r_ds_info.ds_case_time, 9999999) || '     ' ||
           'Total Split TMU: ' || TO_CHAR(l_r_ds_info.ds_split_time, 9999999));
   
      DBMS_OUTPUT.PUT_LINE('Number of Records Processed: ' ||
                            TO_NUMBER(l_counter));

   EXCEPTION
      WHEN OTHERS THEN
         IF (SQLCODE <= -20000) THEN
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE;
            -- RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
            --                         l_object_name || ': ' || SQLERRM);
         ELSE
            pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                           SQLCODE, SQLERRM);
            RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                    l_object_name || ': ' || SQLERRM);
         END IF;

   END calc_ds_time;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    populate_ds_tmu
   --
   -- Description:
   --    This procedure populates the DS_TMU table with the distinct
   --    sub area code, slot tpe, pallet type and pik level for
   --    home and floating slots.
   --    The parameter indicates whether to populate the table
   --    using all the records in the LOC table which will delete any
   --    current records in the DS_TMU table or to only populate
   --    the DS_TMU table with records currently not in the table.
   --
   --    The case and split tmu's are taken from the case_type_code table.
   --    It is required that there is at least one record in the
   --    CASE_TYPE_CODE table.
   --
   -- Parameters:
   --    i_what_records - Designates whether to populate the table using
   --                     all the records in the LOC table which will delete
   --                     any current records in the DS_TMU table
   --                     or to only populate the DS_TMU table
   --                     with records currently not in the table.
   --                     The valid values are:
   --                        - ALL  populate with all LOC records
   --                        - NEW  populate only with new LOC records
   --    o_msg          - Message stating how many records were inserted.
   --  
   -- Exceptions raised:
   --    pl_exc.e_data_error        -- Invalid parameter.
   --                               -- Table CASE_TYPE_CODE is empty.
   --    pl_exc.e_database_error    -- Database error.
   --
   -- Called by:
   --    Form ds1sb
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/29/01 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE populate_ds_tmu(i_what_records  IN  VARCHAR2,
                             o_msg           OUT VARCHAR2)
   IS
      l_message        VARCHAR2(128);  -- Message buffer
      l_message_param  VARCHAR2(128);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.populate_ds_tmu';

      l_count          PLS_INTEGER;   -- Work area.
      l_no_records_inserted PLS_INTEGER := 0;   -- Number of records inserted.
      l_what_records   VARCHAR2(30);  -- How to populate the table.
                                      -- Assigned value from i_what_records.

      e_invalid_parameter     EXCEPTION;  -- Invalid value for parameter.
      e_case_type_code_empty  EXCEPTION;  -- Table CASE_TYPE_CODE is empty.

      -- This cursor selects the records from the LOC table to use in
      -- populating the DS_TMU table.  Only perm and floating
      -- slots are selected.
      CURSOR c_loc IS                  -- Home slots
         SELECT DISTINCT ai.sub_area_code,
                         l.slot_type,
                         l.pallet_type,
                         NVL(l.floor_height, 0) floor_height,
                         l.pik_level,
                         ct.case_type,
                         ct.default_tmu_no_case,
                         ct.default_tmu_no_split
           FROM case_type_code ct,
                aisle_info ai,
                loc l
          WHERE ai.name = SUBSTR(l.logi_loc,1,2)
            AND l.perm = 'Y'
         UNION                         -- Floating slots
         SELECT DISTINCT ai.sub_area_code,
                         l.slot_type,
                         l.pallet_type,
                         NVL(l.floor_height, 0) floor_height,
                         l.pik_level,
                         ct.case_type,
                         ct.default_tmu_no_case,
                         ct.default_tmu_no_split
           FROM case_type_code ct,
                zone z,
                lzone lz,
                aisle_info ai,
                loc l
          WHERE ai.name = SUBSTR(l.logi_loc,1,2)
            AND lz.logi_loc = l.logi_loc
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
            AND z.rule_id = 1;

      -- This cursor counts the records in the CASE_TYPE_CODE table.
      -- It is required that there is at least one record in the
      -- CASE_TYPE_CODE table.
      CURSOR c_count_case_type IS
         SELECT COUNT(1)
           FROM case_type_code;
   BEGIN

      l_message_param := l_object_name || '(i_what_records[' ||
                         i_what_records || '])';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);
      
      l_what_records := UPPER(i_what_records);  -- Parameter can be lower
                                                -- or upper.
      -- Validate the parameter.
      IF (l_what_records NOT IN ('ALL', 'NEW')) THEN
         RAISE e_invalid_parameter;
      END IF;

      -- Make sure there is at least one record in the CASE_TYPE_CODE table.
      OPEN c_count_case_type;
      FETCH c_count_case_type INTO l_count;
      CLOSE c_count_case_type;
      IF (l_count = 0) THEN
         RAISE e_case_type_code_empty;
      END IF;

      -- Delete the existing records if doing all records.
      IF (l_what_records = 'ALL') THEN
         DELETE FROM ds_tmu;
      END IF;

      -- Populate
      FOR r_loc IN c_loc LOOP
         BEGIN
            INSERT INTO ds_tmu(sub_area_code,
                               slot_type,
                               pallet_type,
                               floor_height,
                               pik_level,
                               case_type,
                               tmu_no_case,
                               tmu_no_split)
            SELECT r_loc.sub_area_code,
                   r_loc.slot_type,
                   r_loc.pallet_type,
                   r_loc.floor_height,
                   r_loc.pik_level,
                   r_loc.case_type,
                   r_loc.default_tmu_no_case,
                   r_loc.default_tmu_no_split
              FROM DUAL
            WHERE NOT EXISTS
                  (SELECT 'x'
                     FROM ds_tmu ds
                    WHERE l_what_records = 'NEW'
                      AND ds.sub_area_code = r_loc.sub_area_code
                      AND ds.slot_type     = r_loc.slot_type
                      AND ds.pallet_type   = r_loc.pallet_type
                      AND ds.floor_height  = r_loc.floor_height
                      AND ds.pik_level     = r_loc.pik_level
                      AND ds.case_type     = r_loc.case_type);

            l_no_records_inserted := l_no_records_inserted + SQL%ROWCOUNT;

         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               NULL;
         END;
      END LOOP;

      o_msg := 'Number of records added: ' || TO_CHAR(l_no_records_inserted);

   EXCEPTION
      WHEN e_invalid_parameter THEN
         l_message :=   l_object_name || ': ' ||
              'Invalid value [' || i_what_records || ']' ||
              ' for parameter i_what_records.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN e_case_type_code_empty THEN
         l_message :=   l_message_param ||
            '  Table CASE_TYPE_CODE is empty.  It needs at least one record.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END populate_ds_tmu;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    delete_invalid_ds_tmu
   --
   -- Description:
   --    This procedure deletes the invalid records from the DS_TMU
   --    table.  A record is considered invalid if the combination of the
   --    sub area code, slot tpe, pallet type and pik level does not exist
   --    in the LOC table.  A situation where this could happen is when
   --    the opco makes changes to the warehouse layout.
   --
   --    There is a view called v_ds1sb_invalid_locations used in form ds1sb
   --    to display the invalid records so if the logic changes in this
   --    procedure the view may need to be changed too.
   --
   -- Parameters:
   --    o_msg     - Message stating how many records were deleted.
   --  
   -- Exceptions raised:
   --    pl_exc.e_database_error    -- Database error.
   --
   -- Called by:
   --    Form ds1sb
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/18/04 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE delete_invalid_ds_tmu(o_msg      OUT VARCHAR2)
   IS
      l_message        VARCHAR2(128);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.populate_ds_tmu';

   BEGIN
      DELETE
        FROM ds_tmu ds
       WHERE NOT EXISTS
                  (SELECT 1
                     FROM aisle_info ai,
                          loc l
                    WHERE ai.name          = SUBSTR(l.logi_loc,1,2)
                      AND ai.sub_area_code = ds.sub_area_code
                      AND l.slot_type      = ds.slot_type
                      AND l.pallet_type    = ds.pallet_type
                      AND l.floor_height   = ds.floor_height
                      AND l.pik_level      = ds.pik_level);

      o_msg := 'Number of records deleted: ' || TO_CHAR(SQL%ROWCOUNT);

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, 'OTHERS exception',
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);

   END delete_invalid_ds_tmu;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    validate_case_type_records
   --
   -- Description:
   --    This procedure validates the recorsd in the CASE_TYPE_CODE table.
   --    The cube range and the weight range cannot overlap between records.
   --
   --    To validate a check is make for the records that have overlapping
   --    min cube and max cube.  For these records the min gross weight and
   --    max gross weight cannot overlap.
   --
   -- Parameters:
   --    o_records_valid_bln  - Designates if the records are valid.
   --    o_msg                - Message stating what is invalid when
   --                           validation fails.
   --  
   -- Exceptions raised:
   --    pl_exc.e_database_error  -  An oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    05/23/01 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE validate_case_type_records(o_records_valid_bln OUT BOOLEAN,
                                        o_msg               OUT VARCHAR2)
   IS
      l_message_param  VARCHAR2(128);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                               '.validate_case_type_code';

      e_overlapping_record  EXCEPTION;

      CURSOR c_case_type IS
         SELECT case_type, min_cube, max_cube, min_g_weight, max_g_weight
           FROM case_type_code
          ORDER BY case_type;      -- Ordering required.

      CURSOR c_case_type_chk(cp_case_type case_type_code.case_type%TYPE) IS
         SELECT case_type, min_cube, max_cube, min_g_weight, max_g_weight
           FROM case_type_code
          WHERE case_type > cp_case_type;   -- Ordering required.
   BEGIN

      l_message_param := l_object_name || '(o_records_valid_bln, o_msg)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Initialize
      o_records_valid_bln := TRUE;
      o_msg := NULL;

      FOR r_case_type IN c_case_type LOOP
         FOR r_case_type_chk IN c_case_type_chk(r_case_type.case_type) LOOP
            IF ( (r_case_type_chk.min_cube BETWEEN r_case_type.min_cube
                                               AND r_case_type.max_cube)
                    OR
                 (r_case_type_chk.max_cube BETWEEN r_case_type.min_cube
                                               AND r_case_type.max_cube) ) THEN
               IF ( (r_case_type_chk.min_g_weight
                                      BETWEEN r_case_type.min_g_weight
                                          AND r_case_type.max_g_weight)
                    OR
                 (r_case_type_chk.max_g_weight
                              BETWEEN r_case_type.min_g_weight
                                  AND r_case_type.max_g_weight) ) THEN
                  o_msg := l_object_name || ': Error: Case types '
                           || r_case_type.case_type
                           || ' and '
                           || r_case_type_chk.case_type
                           || ' have min and max values that overlap.';
                  RAISE e_overlapping_record;
               END IF;
            END IF;
         END LOOP;
      END LOOP;
   EXCEPTION
      WHEN e_overlapping_record THEN
         o_records_valid_bln := FALSE;

      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END validate_case_type_records;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    validate_selection_pup_origin
   --
   -- Description:
   --    This procedure validates the origin column in the
   --    ds_selection_pickup_object table.  Only one record per job code
   --    can have the origin set to 'Y'.  It stops at the first job code
   --    that meets this condition.
   --
   -- Parameters:
   --    o_records_valid_bln  - Designates if the records are valid.
   --    o_msg                - Message stating what is invalid when
   --                           validation fails.  Be sure the calling
   --                           program has declared this at least
   --                           100 characters.
   --  
   -- Exceptions raised:
   --    pl_exc.e_database_error  -  An oracle error occurred.
   --
   -- Called by:
   --    - After insert and update statement database trigger on
   --      ds_selection_pickup_object table.
   --    - Form ds1se.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    03/01/02 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE validate_selection_pup_origin(o_records_valid_bln OUT BOOLEAN,
                                           o_msg               OUT VARCHAR2)
   IS
      l_message_param  VARCHAR2(128);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name ||
                                          '.validate_selection_pup_origin';

      -- This cursor selects the job codes that have more than one
      -- origin.
      CURSOR c_pup_chk IS
         SELECT job_code, COUNT(*) rec_count
           FROM ds_selection_pickup_object
          WHERE origin = 'Y'
          GROUP BY job_code
         HAVING COUNT(*) > 1
          ORDER BY job_code;

      l_r_pup     c_pup_chk%ROWTYPE;
   BEGIN

      l_message_param := l_object_name || '(o_records_valid_bln, o_msg)';

      pl_log.ins_msg(pl_lmc.ct_debug_msg, l_object_name, l_message_param,
                     NULL, NULL);

      -- Initialize
      o_records_valid_bln := TRUE;
      o_msg := NULL;

      OPEN c_pup_chk;
      FETCH c_pup_chk INTO l_r_pup;

      IF (c_pup_chk%FOUND) THEN
         o_records_valid_bln := FALSE;
         o_msg := 'Job code ' || l_r_pup.job_code || ' has ' || 
            TO_CHAR(l_r_pup.rec_count) || ' points that have the origin' ||
            ' set to Y.  Only one point can be the origin.';
      END IF;

      CLOSE c_pup_chk;

   EXCEPTION
      WHEN OTHERS THEN
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message_param,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END validate_selection_pup_origin;


   ---------------------------------------------------------------------------
   -- Procedure:
   --    adjust_batch_time
   --
   -- Description:
   --    This procedure adjusts the batch time due to shorts and any
   --    change in the points visited.  The adjustment happens when the
   --    batch is being closed.
   --
   --    The following data capture items will be adjusted accordingly:
   --       - catch weight tracked.
   --       - clam bed tracked.
   --
   --    SOS OPCOs will have the SOS shorts adjusted.
   --    Shorts at non-SOS OPCOs are not adjusted because the short 
   --    information is not available when the batch is being completed.
   --
   -- Parameters:
   --    o_lm_batch_no  - Selection labor mgmt batch number
   --  
   -- Exceptions raised:
   --    pl_exc.e_data_error      - Parameter is null
   --    pl_exc.e_database_error  - An oracle error occurred.
   --
   -- Called By:
   --    - pl_lm1.create_schedule
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/10/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE adjust_batch_time(i_lm_batch_no  IN  arch_batch.batch_no%TYPE)
   IS
      l_message        VARCHAR2(128);  -- Message buffer
      l_object_name    VARCHAR2(61) := gl_pkg_name || '.adjust_batch_time';

      l_tmu            ds_tmu.tmu_no_case%TYPE;

      -- This cursor selects the SOS items shorted.  The sos_short.batch_no
      -- column has the floats batch number.
      --
      -- The format of the selection labor mgmt batch number is
      -- S<floats batch number>.
      CURSOR c_shorts IS
         SELECT pm.case_type,
                pm.split_type,
                pm.catch_wt_trk,
                d.prod_id,
                d.cust_pref_vendor,
                d.uom,
                s.location,
                s.batch_no
           FROM pm,
                ordd d,
                sos_short s
          WHERE pm.prod_id          = d.prod_id
            AND pm.cust_pref_vendor = d.cust_pref_vendor
            AND d.seq               = s.orderseq
            AND s.batch_no          = SUBSTR(i_lm_batch_no, 2);

   BEGIN
      IF (i_lm_batch_no IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      -- Make adjustments to the goal/target time for the batch for SOS shorts.
      FOR r_shorts IN c_shorts LOOP
         -- If a case shorted get the tmu based on the case type and location.
         -- If a split shorted get the tmu based on the split type and location.
         l_tmu := f_get_tmu(r_shorts.case_type, r_shorts.location,
                            r_shorts.uom);
      END LOOP;
   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name || '(i_lm_batch_no[' || i_lm_batch_no ||
                      '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                        l_message || '  Parameter is null.',
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
      WHEN OTHERS THEN
         l_message := l_object_name || '(i_lm_batch_no[' || i_lm_batch_no ||
                      '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   END adjust_batch_time;




   ------------------------------------------------------------------------
   -- Function:
   --    f_get_tmu
   --
   -- Description:
   --    This function returns the tmu for picking a case or split, depending
   --    on the uom, with a specified case type from a specified location for
   --    a case or split.  If unable to determine the tmu then null is
   --    returned.
   --
   --    Each item has a case type and and a split type which
   --
   -- Parameters:
   --    i_case_type   - The case type.  This can be referring to that of
   --                    a split if i_uom = 1.
   --    i_location    - The location the case type is at.
   --    i_uom         - Designates what was picked from the slot.
   --                       1 - split
   --                       anything else - case
   --  
   -- Exceptions raised:
   --    pl_exc.ct_data_error     - A parameter is null.
   --    pl_exc.e_database_error  - Oracle error occurred.
   -- 
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    09/13/04 prpbcb   Created.
   ------------------------------------------------------------------------
   FUNCTION f_get_tmu(i_case_type  IN case_type_code.case_type%TYPE,
                       i_location  IN loc.logi_loc%TYPE,
                       i_uom       IN loc.uom%TYPE)
   RETURN ds_tmu.tmu_no_case%TYPE
   IS
      l_message       VARCHAR2(128);    -- Message buffer
      l_object_name   VARCHAR2(61) := gl_pkg_name || '.f_get_tmu';

      l_return_value  ds_tmu.tmu_no_case%TYPE;  -- TMU determined

      -- This cursor selects the tmu for picking the specified case type from
      -- the specified location.
      -- Note that a case type could also be referring to a split picked from
      -- the location.  
      CURSOR c_tmu(cp_case_type  case_type_code.case_type%TYPE,
                   cp_location   loc.logi_loc%TYPE) IS
         SELECT ds.tmu_no_case,
                ds.tmu_no_split
           FROM aisle_info ai,   -- To get the sub area the location is in.
                ds_tmu ds,
                loc l
          WHERE l.logi_loc          = cp_location
            AND ai.name             = SUBSTR(cp_location, 1, 2)
            AND ds.sub_area_code    = ai.sub_area_code
            AND ds.slot_type        = l.slot_type
            AND ds.pallet_type      = l.pallet_type
            AND ds.floor_height     = l.floor_height
            AND ds.pik_level        = l.pik_level
            AND ds.case_type        = cp_case_type;

      r_tmu   c_tmu%ROWTYPE;    -- TMUs selected.
   BEGIN

      -- Check for null parameters.
      IF (i_case_type IS NULL OR i_location IS NULL OR i_uom IS NULL) THEN
         RAISE gl_e_parameter_null;
      END IF;

      OPEN c_tmu(i_case_type, i_location);

      FETCH c_tmu INTO r_tmu;

      IF (c_tmu%NOTFOUND) THEN
         l_return_value := NULL;
      ELSE
         IF (i_uom = 1) THEN
            l_return_value := r_tmu.tmu_no_case;
         ELSE
            l_return_value := r_tmu.tmu_no_split;
         END IF;
      END IF;

      CLOSE c_tmu;

      RETURN(l_return_value);
   EXCEPTION
      WHEN gl_e_parameter_null THEN
         l_message := l_object_name ||
                      '(i_case_type[' || i_case_type || ']' ||
                      ',i_location[' || i_location || ']' ||
                      ',i_uom[' || TO_CHAR(i_uom) || '])' ||
                ' A parameter is null.';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        pl_exc.ct_data_error, NULL);
         RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);

      WHEN OTHERS THEN
         l_message := l_object_name ||
                      '(i_case_type[' || i_case_type || ']' ||
                      ',i_location[' || i_location || ']' ||
                      ',i_uom[' || TO_CHAR(i_uom) || '])';
         pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM);
         RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                 l_object_name || ': ' || SQLERRM);
   
   END f_get_tmu;


END pl_lm_ds;  -- end package body
/

SHOW ERRORS;

SET DOC ON;

