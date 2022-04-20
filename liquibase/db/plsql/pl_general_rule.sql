--PACKAGE SPEC
PROMPT Creating package PL_GENERAL_RULE ..
CREATE OR REPLACE PACKAGE swms.pl_general_rule IS

   --  sccs_id=@(#) src/schema/plsql/pl_general_rule.sql, swms, swms.9, 10.1.1 3/22/07 1.6

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_general_rule
   --
   -- Description:
   --    Find home slot as putaway slot.
   --    This function is called the first time
   --    to get the home putaway zone and if not found the 1st time,
   --    the next zone is fetched and checked if item can be putaway there.
   --    The iteration is done for all the zones specified as next zones
   --    for the items primary zone.
   --    The logic to find the appropriate slots for partial pallets
   --    is also part of this function.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/04/02          Initial Version   RDC non-dependent.
   --    10/03/03 acpaks   Changes made to the f_check_home_slot method,
   --                      Added check based on number of cases to partial
   --                      pallet putaway and included stackability check for
   --                      full pallet.
   --    03/20/03 prpbcb   DN 11202  Had the scan character in the file.
   --    07/23/03 acppzp   DN 11336 Changes for OSD
   --    08/19/03 acpaks   DN 11309 Changes for Multi SKU
   --    05/26/04 acphxs   DN 11626 Fixed a bug in putaway of non floating aging
   --                        items without a home slot (A location with perm='N 
   --                       will always have cust_pref_vendor as null)
   --    09/10/04 prpbcb   swms8 DN None.  Change already made.
   --                      swms9 11824
   --                      Ticket:  None
   --                      Add sccs_id.
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
    --------------------------------------------------------------------------

    ---------------------------------------------------------------------------
   -- Public Constants
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
   -- Global Type Declarations
    ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Function Declarations
   ---------------------------------------------------------------------------


 FUNCTION f_general_rule
    (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
     i_product_id                IN     pm.prod_id%TYPE,
     i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
     i_aging_days                IN     aging_items.aging_days%TYPE,
     i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
     io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
     i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
     i_first_or_second_flag      IN     number,
     i_zone_id                   IN     zone.zone_id%TYPE)
    RETURN BOOLEAN;


 FUNCTION f_check_avail_slot
    (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
     i_product_id                IN     pm.prod_id%TYPE,
     i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
     i_aging_days                IN     aging_items.aging_days%TYPE,
     i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
     io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
     i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
     i_zone_id                   IN     zone.zone_id%TYPE)
    RETURN BOOLEAN;




 FUNCTION f_avl_slot_diff_prod_loop
    (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
     i_product_id                IN     pm.prod_id%TYPE,
     i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
     i_aging_days                IN     aging_items.aging_days%TYPE,
     i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
     io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
     i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)
    RETURN BOOLEAN;



 FUNCTION f_avail_slot_assign_loop
    (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
     i_product_id                IN     pm.prod_id%TYPE,
     i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
     i_aging_days                IN     aging_items.aging_days%TYPE,
     i_item_info_rec             IN    pl_putaway_utilities.t_item_related_info,
     io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
     i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
     i_same_or_different_flag    IN     number)
    RETURN BOOLEAN;


   FUNCTION f_check_avail_slot_same_prod
      (i_dest_loc         IN      loc.logi_loc%TYPE,
       i_zone             IN      zone.zone_id%TYPE,
       i_prod_id          IN      pm.prod_id%TYPE,
       i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
       i_aging_days       IN      aging_items.aging_days%TYPE,
       i_po_info_rec      IN      pl_putaway_utilities.t_po_info,
       io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
       io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
       io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
    RETURN BOOLEAN;




    FUNCTION f_two_d_three_d
       (i_dest_loc         IN      loc.logi_loc%TYPE,
        i_zone             IN      zone.zone_id%TYPE,
        i_erm_id           IN      erm.erm_id%TYPE,
        i_prod_id          IN      pm.prod_id%TYPE,
        i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
        i_aging_days       IN      aging_items.aging_days%TYPE,
        io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
        io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
        io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
  RETURN BOOLEAN;



    FUNCTION f_two_d_three_d_open_slot
       (i_zone_id          IN      zone.zone_id%TYPE,
        i_prod_id          IN      pm.prod_id%TYPE,
        i_aging_days       IN      aging_items.aging_days%TYPE,
        i_erm_id           IN      erm.erm_id%TYPE,
        i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
        io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
        io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
        io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
   RETURN BOOLEAN;

   FUNCTION f_deep_slot_assign_loop
      (i_same_diff_flag   IN      integer,
       i_erm_id           IN      erm.erm_id%TYPE,
       i_zone_id          IN      zone.zone_id%TYPE,
       i_prod_id          IN      pm.prod_id%TYPE,
       i_aging_days       IN      aging_items.aging_days%TYPE,
       i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
       io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
       io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
       io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
  RETURN BOOLEAN;

  FUNCTION f_check_open_slot
     (i_dest_loc         IN      loc.logi_loc%TYPE,
      i_zone             IN      zone.zone_id%TYPE,
      i_erm_id           IN      erm.erm_id%TYPE,
      i_prod_id          IN      pm.prod_id%TYPE,
      i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
      i_aging_days       IN      aging_items.aging_days%TYPE,
      io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
      io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
      io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
  RETURN BOOLEAN;


  FUNCTION f_open_slot_assign_loop
     (i_erm_id           IN      erm.erm_id%TYPE,
      i_zone_id          IN      zone.zone_id%TYPE,
      i_prod_id          IN      pm.prod_id%TYPE,
      i_aging_days       IN      aging_items.aging_days%TYPE,
      i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
      io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
      io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
      io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
  RETURN BOOLEAN;

  FUNCTION f_check_home_slot
   (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
    i_product_id                IN     pm.prod_id%TYPE,
    i_pm_category               IN     pm.category%TYPE,
    i_customer_preferred_vendor IN     pm.cust_pref_vendor%TYPE,
    io_work_var_rec             IN OUT pl_putaway_utilities.t_work_var,
    io_item_info_rec            IN     pl_putaway_utilities.
                                       t_item_related_info,
    i_aging_days                IN     aging_items.aging_days%TYPE,
    i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)

  RETURN BOOLEAN;


   END pl_general_rule;
/
------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY swms.pl_general_rule
AS

   --  sccs_id=@(#) src/schema/plsql/pl_general_rule.sql, swms, swms.9, 10.1.1 3/22/07 1.6

   ---------------------------------------------------------------------------
   --  FUNCTION:
   --      f_general_rule
   --  DESCRIPTION:
   --      Find home slot as putaway slot.
   --  PARAMETERS:
   --      i_first_or_second_flag - Indicates if this function is being
   --                               called using the item's primary putaway
   --                               zone or if it is being called using a
   --                               zone from next zones.
   --      i_po_info_rec          - all relevant info pertaining to PO
   --      i_product_id           - product id of the item to be putaway
   --      i_cust_pref_vendor     - customer preferred vendor for the item
   --                               to be putaway
   --      i_aging_days           - aging days for items that need aging,-1
   --                               for non aging items
   --      i_item_info_rec        - all relevant details pertaining to the
   --                               item to be putaway
   --      io_workvar_rec         - all the variables shared across the
   --                               functions reside in this record
   --      i_syspar_var_rec       - all the system parameters
   --      i_zone_id              - zone id of the zone for which this
   --                               function is called
   --  RETURN VALUES:
   --   TRUE  - All the pallets for the item were assigned a putaway slot.
   --   FALSE - All the pallets for the item were not assigned a putaway slot.
   ---------------------------------------------------------------------------

FUNCTION f_general_rule
  (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
   i_product_id                IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
   i_first_or_second_flag      IN     NUMBER,
   i_zone_id                   IN     zone.zone_id%TYPE)
RETURN BOOLEAN
IS
   lb_done                 BOOLEAN;
   lb_last_query_error     BOOLEAN;--This flag holds the status of
                                   --last query executed
   --it is true if last query resulted in an error and false otherwise
   lb_revisit_open_slot    BOOLEAN;--if set to true then home slot is
                                   --revisited to putaway the remaining
                                   --pallet
   lb_no_records           BOOLEAN;--checks whether last query returned
                                   --any records or not
   lv_fname                VARCHAR2(30);--holds the function name
   lt_dest                 loc.logi_loc%TYPE;
   lt_aisle1               loc.put_aisle%TYPE;
   lt_slot1                loc.put_slot%TYPE;
   lt_level1               loc.put_level%TYPE;
   lt_slot_type            loc.slot_type%TYPE;
   lt_dest_loc1            loc.logi_loc%TYPE;
   lt_loc_height1          loc.slot_height%TYPE;
   lt_put_aisle1           loc.put_aisle%TYPE;
   lt_put_slot1            loc.put_slot%TYPE;
   lt_put_level1           loc.put_level%TYPE;
   lt_put_path1            loc.put_path%TYPE;
   ------------------------------------------------------------------------
   -- following cursor returns the details of slots already having
   --the product to be putaway ,if any
   /*D#11626 Fixed a bug in putaway of non floating aging items without a home 
    slot  (A location with perm='N' will always have cust_pref_vendor as null)*/
   CURSOR c_prim_zone_occupd_slot IS
   SELECT l.logi_loc  logi_loc,
          l.put_aisle  put_aisle,
          l.put_slot put_slot,
          l.put_level put_level,
          l.slot_type slot_type,
          (NVL(l.slot_height,0)
            *NVL(l.width_positions,1)
            *NVL(s.deep_positions,1))home_loc_height ,
          NVL(l.slot_height,0) slot_height,
          s.deep_ind deep_ind,
          l.put_path put_path
     FROM slot_type s,
          loc l,
          lzone lz,
          pm p
    WHERE s.slot_type = l.slot_type
      AND p.prod_id = i_product_id
      AND p.cust_pref_vendor = i_cust_pref_vendor
      AND p.pallet_type = l.pallet_type
      AND s.deep_ind = 'N'
      AND l.status = 'AVL'
      AND lz.logi_loc = l.logi_loc
      AND lz.zone_id = i_zone_id
      AND l.perm ='N'
      AND l.available_height IS NOT NULL
      AND  EXISTS (SELECT NULL FROM inv i
                                   WHERE prod_id = i_product_id
                                     AND cust_pref_vendor =i_cust_pref_vendor
                                     AND plogi_loc = l.logi_loc)
      AND NOT EXISTS (SELECT NULL FROM inv i
                      WHERE
                     /*D# 11309 MSKU changes*/
                     ((i.parent_pallet_id IS NOT NULL)
                            OR  (i.dmg_ind = 'Y'))
                     /*END D# 11309 MSKU changes*/
                     AND   plogi_loc = l.logi_loc)
  ORDER BY l.available_height;
  /*END D#11626 changes*/
  -------------------------------------------------------------------------
  --following cursor returns open slots in the order of proximity to the
  --home slot
  CURSOR c_revisit_open_slot(n_height IN  NUMBER)
  IS
  SELECT l.logi_loc logi_loc,
         NVL(l.available_height,0) available_height ,
         l.put_slot put_slot,
         l.put_level put_level,
         l.put_path put_path
    FROM pallet_type p,
         slot_type s,
         loc l,
         lzone lz
   WHERE p.pallet_type = l.pallet_type
     AND s.slot_type = l.slot_type
     AND s.deep_ind = 'N'
     AND ( ( i_syspar_var_rec.v_pallet_type_flag = 'Y'
              AND(l.pallet_type = i_item_info_rec.v_pallet_type
                  OR(l.pallet_type IN
                     (SELECT mixed_pallet
                      FROM pallet_type_mixed pmix
                      WHERE pmix.pallet_type = i_item_info_rec.v_pallet_type)
                     )
                    )
                  )
           OR ( i_syspar_var_rec.v_pallet_type_flag = 'N'
                AND s.slot_type = io_workvar_rec.v_slot_type
              )
          )
      AND l.perm = 'N'
      AND l.status = 'AVL'
      AND l.available_height IS NOT NULL
      AND l.slot_height >= n_height
      AND lz.logi_loc = l.logi_loc
      AND lz.zone_id = i_zone_id
      AND NOT EXISTS(SELECT 'x'
                       FROM inv
                      WHERE plogi_loc = l.logi_loc)
      ORDER BY l.available_height,
               ABS(io_workvar_rec.n_put_aisle1 - l.put_aisle),
               l.put_aisle,
               ABS(io_workvar_rec.n_put_slot1 - l.put_slot),
               l.put_slot,
               ABS(io_workvar_rec.n_put_level1 - l.put_level),
               l.put_level;
---------------------------------------------------------------------------
--following cursor locates the slot in secondary zone where product to be
--putawaay already exists
CURSOR c_sec_zone_occupd_slot IS
         SELECT l.logi_loc logi_loc ,
                l.put_aisle put_aisle,
                l.put_slot put_slot,
                l.put_level put_level
           FROM lzone lz,
                loc l,
                inv i
          WHERE lz.logi_loc = l.logi_loc
            AND lz.zone_id = i_zone_id
            AND l.logi_loc = i.plogi_loc
            AND l.available_height IS NOT NULL
            AND i.cust_pref_vendor = i_cust_pref_vendor
            AND i.prod_id = i_product_id
            AND i.dmg_ind <> 'Y'
            /*D# 11309 MSKU changes*/
            AND i.parent_pallet_id IS NULL
            /*END D# 11309 MSKU changes*/
         ORDER BY i.exp_date, i.qoh;
---------------------------------------------------------------------------
--following cursor locates a non-deep open slot closest to the home slot ,
--if any,in secondary zone
 CURSOR c_sec_zone_opn_slot
 IS
 SELECT   l.logi_loc logi_loc,
          l.put_aisle put_aisle,
          l.put_slot put_slot,
          l.put_level put_level
   FROM   slot_type s,
          pallet_type p,
          loc l,
          lzone lz
   WHERE  s.slot_type = l.slot_type
     AND  s.deep_ind = 'N'
     AND p.pallet_type = l.pallet_type
     AND (( i_syspar_var_rec.v_pallet_type_flag = 'Y'
            AND (l.pallet_type = i_item_info_rec.v_pallet_type
               OR(l.pallet_type IN
                  (SELECT mixed_pallet
                    FROM pallet_type_mixed pmix
                   WHERE pmix.pallet_type = i_item_info_rec.v_pallet_type)
                 )
               )
          )
          OR ( i_syspar_var_rec.v_pallet_type_flag = 'N'
               AND s.slot_type = io_workvar_rec.v_slot_type ))
     AND l.perm = 'N'
     AND l.status = 'AVL'
     AND l.available_height IS NOT NULL
     AND NVL(l.available_height,0) >= io_workvar_rec.n_std_pallet_height
     AND lz.logi_loc = l.logi_loc
     AND lz.zone_id = i_zone_id
     AND NOT EXISTS(SELECT 'x'
                    FROM inv
                    WHERE plogi_loc = l.logi_loc)
   ORDER BY l.available_height,
            ABS(io_workvar_rec.n_put_aisle1 - l.put_aisle),l.put_aisle,
            ABS(io_workvar_rec.n_put_slot1 - l.put_slot),l.put_slot,
            ABS(io_workvar_rec.n_put_level1 - l.put_level),l.put_level;
---------------------------------------------------------------------------
--following cursor locates a non-deep open slot with maximum slot height,
--if any,in secondary zone
 CURSOR c_sec_zone_opn_slt2
 IS
 SELECT l.logi_loc,
        l.put_aisle,
        l.put_slot,
        l.put_level
   FROM pallet_type p,
        slot_type s,
        loc l,
        lzone lz
   WHERE p.pallet_type = l.pallet_type
     AND s.slot_type = l.slot_type
     AND s.deep_ind = 'N'
     AND ( ( i_syspar_var_rec.v_pallet_type_flag = 'Y'
           AND(l.pallet_type = i_item_info_rec.v_pallet_type
               OR(l.pallet_type IN
                  (SELECT mixed_pallet
                   FROM pallet_type_mixed pmix
                   WHERE pmix.pallet_type = i_item_info_rec.v_pallet_type)
                  )
               )
            )
           OR ( i_syspar_var_rec.v_pallet_type_flag = 'N'
                AND s.slot_type = io_workvar_rec.v_slot_type ))
     AND l.perm = 'N'
     AND l.status = 'AVL'
     AND l.available_height IS NOT NULL
     AND NVL(l.available_height,0) >= io_workvar_rec.n_std_pallet_height
     AND lz.logi_loc = l.logi_loc
     AND lz.zone_id = i_zone_id
     AND NOT EXISTS(SELECT 'x'
                    FROM inv
                    WHERE plogi_loc = l.logi_loc)
   ORDER BY l.available_height, l.put_slot;
---------------------------------------------------------------------------
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_GENERAL_RULE';
   lv_fname             := 'f_general_rule';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;
   lb_done              := FALSE;
   lb_revisit_open_slot := FALSE;
   io_workvar_rec.b_first_home_assign := FALSE;
   lb_last_query_error  := FALSE;
   -- Get Home slot location
   IF   i_first_or_second_flag  = pl_putaway_utilities.FIRST  THEN
      --  Usage of general rule for the first time.  Called for the items
      -- primary putaway zone.

      pl_log.ins_msg ('DEBUG', lv_fname, 'PO='||i_po_info_rec.v_erm_id
                          ||'prod_id='
                          || i_product_id||' zone='||i_zone_id ||'  cpv='
                          ||i_cust_pref_vendor
                          ||' i_first_or_second_flag==FIRST'  ,NULL, NULL);
      BEGIN
         --Retrieve putpath for home slot of product.
         SELECT l.logi_loc,
                l.put_aisle,
                l.put_slot,
                l.put_level,
                l.slot_type,
                (NVL(l.slot_height,0)
                 *NVL(l.width_positions,1)
                 *NVL(s.deep_positions,1)),
                NVL(l.slot_height,0),
                s.deep_ind,
                l.put_path
         INTO io_workvar_rec.v_dest_loc,
              io_workvar_rec.n_put_aisle1,
              io_workvar_rec.n_put_slot1,
              io_workvar_rec.n_put_level1,
              io_workvar_rec.v_slot_type,
              io_workvar_rec.n_home_loc_height,
              io_workvar_rec.n_height,
              io_workvar_rec.v_deep_ind,
              io_workvar_rec.n_put_path1
         FROM slot_type s, loc l
         WHERE s.slot_type = l.slot_type
         AND l.uom IN (0, 2)
         AND l.perm ='Y'
         AND l.rank = 1
         AND l.cust_pref_vendor = i_cust_pref_vendor
         AND l.prod_id = i_product_id
         AND l.available_height IS NOT NULL;
         --Don't display the no home slot message if the item needs aging
         --but cannot find the home slot for it. We will search for a
         --starting slot (set the put_aisle1/slot1/level1 variables) with
         --the same item for the item to-be-aged in the same zone.
      EXCEPTION
         WHEN OTHERS THEN
         BEGIN
            lb_last_query_error :=TRUE;
            IF  i_aging_days = -1 THEN
              pl_log.ins_msg('WARN', lv_fname,
                             'PO='||i_po_info_rec.v_erm_id
                             ||'TABLE=lzone,loc,inv KEY='||i_product_id
                             ||','||i_cust_pref_vendor
                             ||'  ACTION=SELECT '||
                             'MESSAGE=ORACLE No case home slot found for item.'
                             ,NULL, SQLERRM);
            ELSE
               BEGIN
                  io_workvar_rec.b_home_slot_flag := FALSE;
                  lb_last_query_error :=FALSE;
                  lb_no_records := FALSE;
                  FOR r_prim_zone_occupd_slot IN c_prim_zone_occupd_slot LOOP
                    io_workvar_rec.v_dest_loc
                                    := r_prim_zone_occupd_slot.logi_loc;
                    io_workvar_rec.n_put_aisle1
                                    := r_prim_zone_occupd_slot.put_aisle;
                    io_workvar_rec.n_put_slot1
                                    := r_prim_zone_occupd_slot.put_slot;
                    io_workvar_rec.n_put_level1
                                    := r_prim_zone_occupd_slot.put_level;
                    io_workvar_rec.v_slot_type
                                    := r_prim_zone_occupd_slot.slot_type;
                    io_workvar_rec.n_home_loc_height
                                    := r_prim_zone_occupd_slot.home_loc_height;
                    io_workvar_rec.n_height
                                    := r_prim_zone_occupd_slot.slot_height;
                    io_workvar_rec.v_deep_ind
                                    := r_prim_zone_occupd_slot.deep_ind;
                    io_workvar_rec.n_put_path1
                                    := r_prim_zone_occupd_slot.put_path;
                    lb_no_records := TRUE;
                    --only one will be picked
                    --(First record from the recordset) and then exit from the
                    --cursor.
                    EXIT;
                  END LOOP;
                   IF lb_no_records = FALSE THEN
                      lb_last_query_error :=TRUE;
                      pl_log.ins_msg ('WARN', lv_fname,
                                     'PO='||i_po_info_rec.v_erm_id
                                     ||'TABLE=lzone,loc,inv KEY='
                                     ||i_product_id
                                     ||','||i_cust_pref_vendor ||
                                     'ACTION=SELECT MESSAGE=ORACLE ' ||
                                     'No reserved or' ||
                                     ' floating slot found for aging item.'
                                     ,NULL, SQLERRM);
                   END IF;

               EXCEPTION
                  WHEN OTHERS THEN
                  BEGIN
                     lb_last_query_error :=TRUE;
                     pl_log.ins_msg ('WARN', lv_fname,
                                     'PO='||i_po_info_rec.v_erm_id
                                     ||'TABLE=lzone,loc,inv KEY='
                                     ||i_product_id
                                     ||','||i_cust_pref_vendor ||
                                     'ACTION=SELECT MESSAGE=ORACLE ' ||
                                     'No reserved or' ||
                                     ' floating slot found for aging item.'
                                     ,NULL, SQLERRM);
                  END;
               END;
            END IF;--i_aging_days = -1
         END;
      END;
   ELSIF i_first_or_second_flag  = pl_putaway_utilities.SECOND THEN
      -- Usage of general rule for the second time.  Called using a
      -- zone from next zones.
      pl_log.ins_msg ('DEBUG', lv_fname, 'PO='||i_po_info_rec.v_erm_id
                      ||'prod_id='
                      || i_product_id||' zone='||i_zone_id ||'  cpv='
                      ||i_cust_pref_vendor
                      ||' i_first_or_second_flag==SECOND'
                      ,NULL, SQLERRM);
      --Select slot base on FIFO rule as new home_slot.
      --This is setting the base putaway slot for the current next zone
      --if the product exists in the current next zone.
      BEGIN
         lb_last_query_error :=FALSE;
         lb_no_records := TRUE;
         FOR r_sec_zone_occupd_slot IN c_sec_zone_occupd_slot LOOP
           lt_dest   := r_sec_zone_occupd_slot.logi_loc;
           lt_aisle1 := r_sec_zone_occupd_slot.put_aisle;
           lt_slot1  := r_sec_zone_occupd_slot.put_slot;
           lt_level1 := r_sec_zone_occupd_slot.put_level;
           lb_no_records := FALSE;
           --only one will be picked
           --(First record from the recordset) and then exit from the
           --cursor.
           EXIT;
         END LOOP;
         IF lb_no_records = TRUE THEN
            lb_last_query_error :=TRUE;

            BEGIN
               --The product does not exist in this next zone.
               --Select the open slot closest to home slot as the new home'
               --slot.

               pl_log.ins_msg ('WARN', lv_fname,
                               'PO='||i_po_info_rec.v_erm_id
                               ||'TABLE=lzone,loc,inv KEY='||i_product_id
                               ||','||i_cust_pref_vendor
                               ||'  ACTION=SELECT MESSAGE=No inventory found '
                               ||'in next zone.'
                               ,NULL, SQLERRM);
               IF   io_workvar_rec.b_home_slot_flag = TRUE THEN
                 pl_log.ins_msg ('DEBUG', lv_fname,
                                 'PO='||i_po_info_rec.v_erm_id
                                 ||'home_slot_flag is true' ,NULL, SQLERRM);
                 lb_last_query_error :=FALSE;
                 lb_no_records :=TRUE;
                 FOR r_sec_zone_opn_slot IN c_sec_zone_opn_slot
                 LOOP
                     lt_dest      := r_sec_zone_opn_slot.logi_loc;
                     lt_aisle1    := r_sec_zone_opn_slot.put_aisle;
                     lt_slot1     := r_sec_zone_opn_slot.put_slot;
                     lt_level1    := r_sec_zone_opn_slot.put_level;
                     lb_no_records := FALSE;
                     --only one will be picked
                     --(First record from the recordset) and then exit from the
                     --cursor.
                     EXIT;
                  END LOOP;
                  IF lb_no_records = FALSE THEN
                     io_workvar_rec.v_dest_loc   := lt_dest;
                     io_workvar_rec.n_put_aisle1 := lt_aisle1;
                     io_workvar_rec.n_put_level1 := lt_level1;
                     io_workvar_rec.n_put_slot1  := lt_slot1;
                     pl_log.ins_msg ('DEBUG', lv_fname, 'PO='
                                     ||i_po_info_rec.v_erm_id
                                     ||'floating: slot='
                                     ||lt_dest||' put_aisle='
                                     ||lt_put_aisle1
                                     || ' put_slot='||lt_put_slot1
                                     ||' put_level='
                                     ||lt_put_level1,NULL, SQLERRM);
                  ELSE
                    lb_last_query_error := TRUE;
                  END IF;

               ELSE
                  pl_log.ins_msg ('DEBUG', lv_fname,
                                  'PO='||i_po_info_rec.v_erm_id
                                  ||'home_slot_flag is false'  ,
                                  NULL, SQLERRM);

                  -- Since there is no home location we must establish a
                  --location to start from.
                  lb_last_query_error :=FALSE;
                  lb_no_records :=TRUE;
                  FOR r_sec_zone_opn_slt2 IN c_sec_zone_opn_slt2
                  LOOP
                      lt_dest      := r_sec_zone_opn_slt2.logi_loc;
                      lt_aisle1    := r_sec_zone_opn_slt2.put_aisle;
                      lt_slot1     := r_sec_zone_opn_slt2.put_slot;
                      lt_level1    := r_sec_zone_opn_slt2.put_level;
                      lb_no_records :=FALSE;
                      --only one will be picked
                      --(First record from the recordset) and then exit from the
                      --cursor.
                      EXIT;
                  END LOOP;
                  IF lb_no_records =FALSE THEN
                     io_workvar_rec.v_dest_loc   := lt_dest;
                     io_workvar_rec.n_put_aisle1 := lt_aisle1;
                     io_workvar_rec.n_put_level1 := lt_level1;
                     io_workvar_rec.n_put_slot1  := lt_slot1;
                     pl_log.ins_msg('DEBUG', lv_fname, 'PO='
                                      ||i_po_info_rec.v_erm_id
                                      ||'floating: slot='
                                      ||lt_dest||' put_aisle='
                                      ||lt_put_aisle1
                                      ||' put_slot='||lt_put_slot1||
                                      ' put_level='
                                      ||lt_put_level1,NULL, SQLERRM);
                  ELSE
                     lb_last_query_error :=TRUE;
                  END IF;
               END IF;-- no home slot
            EXCEPTION
               WHEN OTHERS THEN
               BEGIN
                  lb_last_query_error :=TRUE;
                  pl_log.ins_msg ('WARN', lv_fname,
                                  'PO='||i_po_info_rec.v_erm_id
                                  ||'TABLE=lzone,loc,inv KEY='
                                  ||i_product_id
                                  ||','
                                  ||i_cust_pref_vendor ||','||i_zone_id
                                  ||'  ACTION=SELECT '
                                  ||'MESSAGE=NEXT ZONE: ' ||
                                  ' No existing inventory and ' ||
                                  ' no open slots in zone: ' ||
                                  i_zone_id ,NULL, SQLERRM);
               END;
            END;
         END IF;--IF lb_no_records := TRUE THEN
      END;
   END IF;-- i_first_or_second_flag  = pl_putaway_utilities.SECOND
   io_workvar_rec.n_home_slot_height := io_workvar_rec.n_home_loc_height;

   IF lb_last_query_error = FALSE THEN
      --Starting slot found
      pl_log.ins_msg ('DEBUG', lv_fname,
                      'PO='||i_po_info_rec.v_erm_id
                      ||'starting loc='
                      ||io_workvar_rec.v_dest_loc||', home_loc_height='
                      ||io_workvar_rec.n_home_loc_height||', put_aisle='
                      ||io_workvar_rec.n_put_aisle1||', put_slot='
                      ||io_workvar_rec.n_put_slot1||', put_level='
                      ||io_workvar_rec.n_put_level1,NULL, NULL);
      pl_log.ins_msg ('DEBUG', lv_fname, 'PO='
                      ||i_po_info_rec.v_erm_id ||'starting loc='
                      ||io_workvar_rec.v_dest_loc||', slot type='
                      ||io_workvar_rec.v_slot_type||', deep_ind='
                      ||io_workvar_rec.v_deep_ind,NULL, NULL);
      --Only  for non-aging items
      IF i_first_or_second_flag = pl_putaway_utilities.FIRST
         AND i_aging_days = -1 THEN
         --for first time in general rule for given item
         IF i_item_info_rec.n_case_cube = 0 THEN
            pl_log.ins_msg ('INFO', lv_fname,
                           'PO='||i_po_info_rec.v_erm_id
                           ||'cube = 0, loading all pallets to loc='
                           ||io_workvar_rec.v_dest_loc ,NULL, SQLERRM);
            FOR pallet_counter IN 0..(io_workvar_rec.n_num_pallets -1)
            LOOP
               pl_putaway_utilities.p_insert_table
                              ( i_product_id,
                                i_cust_pref_vendor,
                                io_workvar_rec.v_dest_loc,
                                pl_putaway_utilities.ADD_HOME,
                                --io_workvar_rec.b_first_home_assign,
                                i_po_info_rec.v_erm_id,
                                i_aging_days,
                                i_syspar_var_rec.v_clam_bed_tracked_flag,
                                i_item_info_rec ,
                                io_workvar_rec);
            END LOOP;
            lb_done := TRUE;
            RETURN lb_done;
         END IF;
         io_workvar_rec.b_home_slot_flag := TRUE;--since home slot was
                                                 --found
         IF  i_syspar_var_rec.v_allow_flag = 'Y'AND io_workvar_rec.v_dmg_ind <> 'DMG' THEN
            pl_log.ins_msg ('DEBUG', lv_fname, 'PO='
                            ||i_po_info_rec.v_erm_id
                            ||'Checking home slot='
                            ||io_workvar_rec.v_dest_loc ,NULL, SQLERRM);
            --Check home slot for space available

            lb_done := f_check_home_slot(  i_po_info_rec,
                                           i_product_id,
                                           i_item_info_rec.v_category,
                                           i_cust_pref_vendor,
                                           io_workvar_rec,
                                           i_item_info_rec,
                                           i_aging_days,
                                           i_syspar_var_rec);


         END IF;
      END IF;--i_first_or_second_flag = pl_putaway_utilities.FIRST
             --AND i_aging_days = -1
      IF lb_done = FALSE AND io_workvar_rec.v_dmg_ind <> 'DMG' THEN
         --If pallets remaining after visiting the home slot
         -- check for availability in deep slots
         pl_log.ins_msg ('DEBUG', lv_fname,
                         'PO='||i_po_info_rec.v_erm_id
                         ||'Using deep logic',NULL, NULL);
         lb_done := f_two_d_three_d(io_workvar_rec.v_dest_loc,
                                    i_zone_id,
                                    i_po_info_rec.v_erm_id,
                                    i_product_id,
                                    i_cust_pref_vendor,
                                    i_aging_days,
                                    io_workvar_rec,
                                    i_item_info_rec,
                                    i_syspar_var_rec);

         IF lb_done = TRUE THEN
            RETURN lb_done;
         END IF;

         --If pallets remaining after visiting home slot and deep slots
         --(if product home slot is deep).
         IF   lb_done = FALSE  AND io_workvar_rec.n_num_pallets = 1
             AND io_workvar_rec.b_partial_pallet = TRUE THEN
            pl_log.ins_msg ('DEBUG', lv_fname,
                            'PO='||i_po_info_rec.v_erm_id
                            ||'only one partial pallet ,'
                            ||'hence checking same product slots',
                            NULL,NULL);
            -- Check available space in slot with same product
            IF  i_item_info_rec.n_stackable > 0
                AND io_workvar_rec.v_dmg_ind <> 'DMG' THEN

               lb_done := f_check_avail_slot_same_prod
                                     (io_workvar_rec.v_dest_loc,
                                      i_zone_id,
                                      i_product_id,
                                      i_cust_pref_vendor,
                                      i_aging_days,
                                      i_po_info_rec,
                                      io_workvar_rec,
                                      i_item_info_rec,
                                      i_syspar_var_rec);

            END IF;
         END IF;
         IF  lb_done = FALSE  AND io_workvar_rec.n_num_pallets = 1
             AND io_workvar_rec.b_partial_pallet = TRUE
             AND io_workvar_rec.b_home_slot_flag = TRUE THEN
            pl_log.ins_msg ('DEBUG', lv_fname,
                           'PO='||i_po_info_rec.v_erm_id
                            ||'Set revisit_open_slot due to only partial'
                            ||' pallet not putaway',
                           NULL,NULL);
            lb_revisit_open_slot := TRUE;
         END IF;
         IF  lb_done = FALSE  AND NOT(io_workvar_rec.n_num_pallets = 1
             AND io_workvar_rec.b_partial_pallet = TRUE) THEN
            --Check open slots to put item away only if
            --there is a full pallet to put away
            pl_log.ins_msg ('DEBUG',lv_fname,
                            'PO='||i_po_info_rec.v_erm_id
                            ||'Not only partial and find open slots '
                            ||'using dest_loc='
                            ||io_workvar_rec.v_dest_loc,NULL,NULL);
            lb_done := f_check_open_slot(io_workvar_rec.v_dest_loc,
                                         i_zone_id,
                                         i_po_info_rec.v_erm_id,
                                         i_product_id,
                                         i_cust_pref_vendor,
                                         i_aging_days,
                                         io_workvar_rec,
                                         i_item_info_rec,
                                         i_syspar_var_rec);

         END IF;
         IF lb_done = FALSE AND i_item_info_rec.n_stackable > 0 THEN
            --if not done, recheck available slot
            -- same product only if not already checked
            IF  NOT(io_workvar_rec.n_num_pallets =1
                AND io_workvar_rec.b_partial_pallet = TRUE)
                AND io_workvar_rec.v_dmg_ind <> 'DMG' THEN
               pl_log.ins_msg ('DEBUG', lv_fname,
                               'PO='||i_po_info_rec.v_erm_id
                               ||' Not only partial and find same product slots',
                               NULL,NULL);
               lb_done := f_check_avail_slot_same_prod
                              (io_workvar_rec.v_dest_loc,
                               i_zone_id,
                               i_product_id,
                               i_cust_pref_vendor,
                               i_aging_days,
                               i_po_info_rec,
                               io_workvar_rec,
                               i_item_info_rec,
                               i_syspar_var_rec);

            END IF;
         END IF;
         IF lb_done = FALSE AND i_item_info_rec.n_stackable > 0
            AND io_workvar_rec.v_dmg_ind <> 'DMG' THEN
            pl_log.ins_msg ('DEBUG', lv_fname,
                             'PO='||i_po_info_rec.v_erm_id
                             ||' find different product slots',NULL,NULL);
            --if not done, check all available slot
            lb_done := f_check_avail_slot( i_po_info_rec,
                                           i_product_id,
                                           i_cust_pref_vendor,
                                           i_aging_days ,
                                           i_item_info_rec,
                                           io_workvar_rec,
                                           i_syspar_var_rec,
                                           i_zone_id);
         END IF;
      END IF;--if lb_done = false then
      --When partial_pallet is the only pallet has not been assigned
      --and open slot have more space
      IF  lb_done = FALSE  AND  lb_revisit_open_slot = TRUE
          AND i_first_or_second_flag = pl_putaway_utilities.FIRST THEN
        pl_log.ins_msg ('DEBUG', lv_fname,
                         'PO='||i_po_info_rec.v_erm_id
                         ||' revisiting open slots',NULL,NULL);
        pl_log.ins_msg ('DEBUG',lv_fname,
                         'PO='||i_po_info_rec.v_erm_id
                         ||' pallet_type_flag='||
                         i_syspar_var_rec.v_pallet_type_flag
                         ||', pallet_type='||i_item_info_rec.v_pallet_type
                         ||', slot_type='||io_workvar_rec.v_slot_type,
                         NULL,NULL);
        pl_log.ins_msg ('DEBUG', lv_fname,
                         'PO='||i_po_info_rec.v_erm_id
                         ||' home_slot_height='
                         ||io_workvar_rec.n_home_slot_height
                         ||', zone_id='||i_zone_id||', put_aisle1='
                         ||io_workvar_rec.n_put_aisle1||', put_slot1='
                         ||io_workvar_rec.n_put_slot1||', put_level1='
                         ||io_workvar_rec.n_put_level1,NULL,NULL);
        BEGIN
          lb_no_records := FALSE;
          FOR r_revisit_open_slot
              IN c_revisit_open_slot(io_workvar_rec.n_height)
          LOOP
               lt_dest_loc1  := r_revisit_open_slot.logi_loc;
               lt_loc_height1:= r_revisit_open_slot.available_height;
               lt_put_slot1  := r_revisit_open_slot.put_slot;
               lt_put_level1 := r_revisit_open_slot.put_level;
               lt_put_path1  := r_revisit_open_slot.put_path;
               lb_no_records := TRUE;
               --only one will be picked
               --(First record from the recordset) and then exit from the
               --cursor.
               EXIT;
          END LOOP;
          IF lb_no_records = TRUE THEN
             io_workvar_rec.n_each_pallet_qty
                                  := io_workvar_rec.n_last_pallet_qty;
             pl_log.ins_msg ('DEBUG', lv_fname,
                              'PO='||i_po_info_rec.v_erm_id
                              ||'  putting partial in open slot='
                              ||io_workvar_rec.v_dest_loc ,NULL,NULL);
             pl_putaway_utilities.p_insert_table
                                  (i_product_id,
                                   i_cust_pref_vendor,
                                   lt_dest_loc1,
                                   pl_putaway_utilities.ADD_RESERVE,
                                   i_po_info_rec.v_erm_id,
                                   i_aging_days,
                                   i_syspar_var_rec.v_clam_bed_tracked_flag,
                                   i_item_info_rec,
                                   io_workvar_rec);
              lb_done := TRUE;
              RETURN lb_done ;
           ELSE
              pl_log.ins_msg ('DEBUG', lv_fname,
                               'PO='||i_po_info_rec.v_erm_id
                                ||'TABLE=lzone,loc,inv KEY=' ||i_product_id
                                ||','|| i_cust_pref_vendor||','|| i_zone_id
                                ||','||io_workvar_rec.n_home_slot_height
                                ||' ACTION=SELECT  MESSAGE=ORACLE No open slots'
                                ||'> than home slot height in zone on revisit',
                                 NULL,SQLERRM);
           END IF;
         EXCEPTION
            WHEN OTHERS THEN
            BEGIN
               pl_log.ins_msg ('DEBUG', lv_fname,
                               'PO='||i_po_info_rec.v_erm_id
                               ||'TABLE=lzone,loc,inv KEY=' ||i_product_id
                               ||','|| i_cust_pref_vendor||','|| i_zone_id
                               ||','||io_workvar_rec.n_home_slot_height
                               ||' ACTION=SELECT  MESSAGE=ORACLE No open slots'
                               ||'> than home slot height in zone on revisit',
                               NULL,SQLERRM);
            END;
         END;
      END IF;
   ELSE
      io_workvar_rec.b_home_slot_flag := FALSE;
   END IF;--error in the query last executed

   RETURN lb_done;
END f_general_rule;




/*----------------------------------------------------------------------------
--  FUNCTION:
--      f_check_avail_slot
--  DESCRIPTION:
--      Find non-open slot of all aisle as putaway slot
--  PARAMETERS:
--      i_po_info_rec          -  all relevant info pertaining to PO
--      i_product_id           -  product id of the item to be putaway
--      i_cust_pref_vendor     -  customer preferred vendor for the item
                               -  to be putaway
--      i_aging_days           -  aging days for items that need aging,-1
                                  for non aging items
--      i_item_info_rec        - all relevant details pertaining to the
                                  item to be putaway
--      io_workvar_rec         -  all the variables shared across the
                                  functions reside in this record
--      i_syspar_var_rec       - all the system parameters
--      i_zone_id              - zone id of the zone for which this
                                 function is called
--  RETURN VALUES:
--      TRUE  - All the pallets for the item were assigned a putaway slot.
--      FALSE - All the pallets for the item were not assigned a putaway slot.
-----------------------------------------------------------------------------*/
FUNCTION f_check_avail_slot
 (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
  i_product_id                IN     pm.prod_id%TYPE,
  i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
  i_aging_days                IN     aging_items.aging_days%TYPE,
  i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
  io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
  i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
  i_zone_id                   IN     zone.zone_id%TYPE)
RETURN BOOLEAN
IS
   lb_status        BOOLEAN;   --flag to check if all the pallets have been
                               --put away
   ln_temp_height   NUMBER;
   ln_count         NUMBER; --used for counting lines fetched by the cursor
                            --and also for assigning values to pl/sql tables
   lv_fname         VARCHAR2(30);
   l_work_var_rec   pl_putaway_utilities.t_work_var;

   --------------------------------------------------------------------------
  --following cursor fetches available slots in the zone in the order of
  --availabe height and their proximity to the home slot (or base slot
  --if putting away in secondary zone )
  CURSOR c_loc_zone(temp_height IN NUMBER ) IS
   SELECT DISTINCT l.logi_loc AS logi_loc,
          NVL(l.available_height,0) AS loc_height,
          l.put_aisle AS put_aisle,
          l.put_slot  AS put_slot,
          l.put_level AS put_level,
          l.put_path  AS put_path
     FROM  slot_type s, loc l, lzone lz, inv i
    WHERE s.slot_type = l.slot_type
      AND s.deep_ind = 'N'
      AND ( ( i_syspar_var_rec.v_pallet_type_flag = 'Y'
             AND (l.pallet_type = i_item_info_rec.v_pallet_type
                  OR(l.pallet_type IN
                     ( SELECT mixed_pallet
                        FROM pallet_type_mixed pmix
                        WHERE pmix.pallet_type = i_item_info_rec.v_pallet_type)
                    )
                 )
          )
        OR ( i_syspar_var_rec.v_pallet_type_flag = 'N'
            AND s.slot_type = io_workvar_rec.v_slot_type )
         )
     AND l.logi_loc = lz.logi_loc
     AND l.perm = 'N'
     AND l.status = 'AVL'
     AND l.available_height IS NOT NULL
     AND NVL((l.available_height),0) >=  temp_height
     AND lz.logi_loc = i.plogi_loc
     AND lz.zone_id = i_zone_id
     AND (i.prod_id <> i_product_id
          OR i.cust_pref_vendor <> i_cust_pref_vendor)
    AND NOT EXISTS(SELECT NULL 
                    FROM inv 
                    WHERE plogi_loc = l.logi_loc 
                    AND (dmg_ind = 'Y'
                          /*D# 11309 MSKU changes*/
                          OR parent_pallet_id IS NOT NULL
                          /*END D# 11309 MSKU changes*/))
     AND NOT EXISTS (SELECT 'x'
                       FROM pm p2, inv k
                      WHERE p2.prod_id = k.prod_id
                        AND p2.cust_pref_vendor = k.cust_pref_vendor
                        AND k.plogi_loc = l.logi_loc
                        AND ((
                             (i_item_info_rec.n_stackable > 0)
                               AND (p2.stackable >
                                    i_item_info_rec.n_stackable
                                     OR p2.stackable = 0)
                            )
                           OR (p2.stackable = 0))
                   AND k.plogi_loc = l.logi_loc)
   ORDER BY NVL(l.available_height,0),
        ABS(io_workvar_rec.n_put_aisle1 - l.put_aisle), l.put_aisle,
        ABS(io_workvar_rec.n_put_slot1 - l.put_slot), l.put_slot,
        ABS(io_workvar_rec.n_put_level1 - l.put_level), l.put_level ;
   --------------------------------------------------------------------------
  --following cursor fetches available slots in a particular aisle
  --in the order ofavailabe height and there proximity to
  --the home slot (or base slot if putting away in secondary zone )
   CURSOR c_loc_aisle(next_aisle IN LOC.PUT_AISLE%TYPE,
                      temp_height IN NUMBER,lheight IN NUMBER) IS
   SELECT DISTINCT l.logi_loc AS logi_loc,
          NVL(l.available_height,0) AS loc_height,
          l.put_aisle AS put_aisle,
          l.put_slot  AS put_slot,
          l.put_level AS put_level,
          l.put_path  AS put_path
     FROM slot_type s,
          loc l,
          lzone lz,
          inv i
    WHERE s.slot_type = l.slot_type
      AND s.deep_ind = 'N'
      AND l.logi_loc = lz.logi_loc
      AND l.perm = 'N'
      AND l.status = 'AVL'
      AND NVL(l.available_height,0) = lheight
      AND l.put_aisle = next_aisle
      AND l.available_height IS NOT NULL
      AND NVL((l.available_height),0)  >=temp_height
      AND lz.zone_id = i_zone_id
      AND (i.prod_id <> i_product_id
           OR i.cust_pref_vendor <> i_cust_pref_vendor)
      AND NOT EXISTS(SELECT NULL 
                          FROM inv 
                          WHERE plogi_loc = l.logi_loc 
                          AND (dmg_ind = 'Y'
                          /*D# 11309 MSKU changes*/
                               OR parent_pallet_id IS NOT NULL
                          /*END D# 11309 MSKU changes*/))
      AND NOT EXISTS (SELECT 'x'
                        FROM pm p2, inv k
                       WHERE p2.prod_id = k.prod_id
                         AND p2.cust_pref_vendor = k.cust_pref_vendor
                         AND (((i_item_info_rec.n_stackable > 0)
                             AND (p2.stackable > i_item_info_rec.n_stackable
                                  OR p2.stackable = 0))
                              OR (p2.stackable = 0))
                         AND k.plogi_loc = l.logi_loc)
    ORDER BY  NVL((l.available_height),0),
              ABS(io_workvar_rec.n_put_aisle1 - l.put_aisle), l.put_aisle,
              ABS(io_workvar_rec.n_put_slot1 - l.put_slot), l.put_slot,
              ABS(io_workvar_rec.n_put_level1 - l.put_level), l.put_level;

   ----------------------------------------------------------------------
  --following cursor selects  aisles and slot height pairs ( slots  with a
  --particular available height in that particular aisle)
  --in the order of availabe height and there proximity to
  --the home slot (or base slot if putting away in secondary zone )
   CURSOR c_nextaisle IS
   SELECT DISTINCT l.put_aisle AS next_aisle,
          NVL(l.available_height,0) AS loc_height
     FROM slot_type s,
          loc l,
          lzone lz
    WHERE s.slot_type = l.slot_type
      AND s.deep_ind = 'N'
      AND ( (  i_syspar_var_rec.v_pallet_type_flag = 'Y'
             AND (l.pallet_type = i_item_info_rec.v_pallet_type
                   OR (l.pallet_type IN
                          (SELECT mixed_pallet
                             FROM pallet_type_mixed pmix
                            WHERE pmix.pallet_type =
                                  i_item_info_rec.v_pallet_type)
                          ))
         OR (  i_syspar_var_rec.v_pallet_type_flag = 'N'
             AND (s.slot_type = io_workvar_rec.v_slot_type)
            )
            )
         )
      AND l.perm = 'N'
      AND l.status = 'AVL'
      AND l.available_height IS NOT NULL
      AND NVL(l.available_height,0) >= io_workvar_rec.n_std_pallet_height
      AND l.logi_loc = lz.logi_loc
      AND lz.zone_id = i_zone_id
    ORDER BY NVL(l.available_height,0),
            ABS(io_workvar_rec.n_put_aisle1 - l.put_aisle),
            l.put_aisle ;
----------------------------------------------------------------------------
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_GENERAL_RULE';
   lv_fname  := 'f_check_avail_slot';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;
   lb_status := FALSE;
   --Retrive location from other aisle with enough space for one pallet
   --regardless of prod_id.  The locations are put into an array, sorted
   --from closest to farest
   IF i_item_info_rec.v_max_slot_flag = 'Z'
      AND i_item_info_rec.n_max_slot > io_workvar_rec.n_slot_cnt THEN
      IF  io_workvar_rec.n_current_pallet = (io_workvar_rec.n_num_pallets - 1)
         AND io_workvar_rec.b_partial_pallet = TRUE THEN
         ln_temp_height := io_workvar_rec.n_lst_pallet_height;
      ELSE
         ln_temp_height := io_workvar_rec.n_std_pallet_height;
      END IF;

      io_workvar_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
      io_workvar_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
      io_workvar_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
      io_workvar_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
      io_workvar_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
      io_workvar_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;



      ln_count := 0;
      FOR r_loc_zone IN c_loc_zone(ln_temp_height) LOOP
         ln_count := ln_count + 1;
         io_workvar_rec.gtbl_phys_loc (ln_count) := r_loc_zone.logi_loc;
         io_workvar_rec.gtbl_loc_height(ln_count):= r_loc_zone.loc_height;
         io_workvar_rec.gtbl_put_aisle2(ln_count):= r_loc_zone.put_aisle;
         io_workvar_rec.gtbl_put_slot2(ln_count) := r_loc_zone.put_slot;
         io_workvar_rec.gtbl_put_level2(ln_count):= r_loc_zone.put_level;
         io_workvar_rec.gtbl_put_path2(ln_count) := r_loc_zone.put_path;

      END LOOP;

      IF ln_count = 0 THEN
         pl_log.ins_msg ('WARN',lv_fname ,
                         'PO='||i_po_info_rec.v_erm_id
                          ||'TABLE=inv,loc,lzone,slot_type,pm  KEY='
                          ||i_product_id
                          ||','||i_cust_pref_vendor||','||i_zone_id||','
                          ||i_item_info_rec.n_stackable
                          ||' ACTION=SELECT '
                          ||' MESSAGE=ORACLE unable to select'
                          ||' slots having different item in zone with '
                          ||'correct stackability',
                          NULL,SQLERRM);
      ELSE
      pl_log.ins_msg ('DEBUG', lv_fname,
                      'PO='||i_po_info_rec.v_erm_id
                      ||'number of slots with different item in zone='
                      ||ln_count   ,NULL,SQLERRM);
      io_workvar_rec.n_total_cnt := ln_count;
      lb_status := f_avl_slot_diff_prod_loop(  i_po_info_rec,
                                               i_product_id,
                                               i_cust_pref_vendor,
                                               i_aging_days,
                                               i_item_info_rec,
                                               io_workvar_rec,
                                               i_syspar_var_rec);
      END IF;

   ELSIF i_item_info_rec.v_max_slot_flag = 'A' THEN
      FOR r_nextaisle in c_nextaisle LOOP
         SELECT COUNT(DISTINCT i.plogi_loc) INTO io_workvar_rec.n_slot_cnt
           FROM lzone lz, loc l, inv i
          WHERE lz.logi_loc = l.logi_loc
            AND lz.zone_id = i_zone_id
            AND l.logi_loc = i.plogi_loc
            AND l.put_aisle = r_nextaisle.next_aisle
            AND i.cust_pref_vendor = i_cust_pref_vendor
            AND i.prod_id = i_product_id ;
         IF i_item_info_rec.n_max_slot > io_workvar_rec.n_slot_cnt THEN
            IF  io_workvar_rec.n_current_pallet =
                (io_workvar_rec.n_num_pallets - 1)
                AND io_workvar_rec.b_partial_pallet = TRUE THEN
               ln_temp_height := io_workvar_rec.n_lst_pallet_height;
            ELSE
               ln_temp_height := io_workvar_rec.n_std_pallet_height;
            END IF;

            io_workvar_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
            io_workvar_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
            io_workvar_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
            io_workvar_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
            io_workvar_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
            io_workvar_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

            --Either the cust_pref_vendor or the prod_id can be
            -- different.
            ln_count := 0;
            FOR r_loc_aisle IN c_loc_aisle(r_nextaisle.next_aisle,
                                           ln_temp_height,
                                           r_nextaisle.loc_height)
            LOOP
              ln_count := ln_count + 1;
              io_workvar_rec.gtbl_phys_loc(ln_count):= r_loc_aisle.logi_loc;
              io_workvar_rec.gtbl_loc_height(ln_count):= r_loc_aisle.loc_height;
              io_workvar_rec.gtbl_put_aisle2(ln_count):= r_loc_aisle.put_aisle;
              io_workvar_rec.gtbl_put_slot2(ln_count):= r_loc_aisle.put_slot;
              io_workvar_rec.gtbl_put_level2(ln_count):= r_loc_aisle.put_level;
              io_workvar_rec.gtbl_put_path2(ln_count):= r_loc_aisle.put_path;
            END LOOP;
            IF ln_count = 0 THEN
               pl_log.ins_msg ('WARN', lv_fname,
                               'PO='||i_po_info_rec.v_erm_id
                               ||'TABLE=inv,loc,lzone,slot_type,pm  KEY='
                               ||i_product_id||','||i_cust_pref_vendor||','
                               ||i_zone_id||','||r_nextaisle.next_aisle||','
                               ||i_item_info_rec.n_stackable
                               ||' ACTION=SELECT  MESSAGE=ORACLE unable to '
                               ||'select slots having different item in'
                               ||' zone for aisle with correct stackability'
                               ,NULL,SQLERRM);
            ELSE
               pl_log.ins_msg('DEBUG', lv_fname,
                              'PO='||i_po_info_rec.v_erm_id
                              ||' number of slots with different item in aisle ='
                              ||ln_count   ,NULL,SQLERRM);
               io_workvar_rec.n_total_cnt := ln_count;
               lb_status := f_avl_slot_diff_prod_loop(i_po_info_rec,
                                                      i_product_id,
                                                      i_cust_pref_vendor,
                                                      i_aging_days,
                                                      i_item_info_rec,
                                                      io_workvar_rec,
                                                      i_syspar_var_rec);
               EXIT WHEN lb_status = TRUE;
            END IF;
         END IF;
      END LOOP;
   END IF;-- end max_slot_flag A
   RETURN lb_status;
END f_check_avail_slot;

   /*------------------------------------------------------------------------
   --  FUNCTION:
   --      f_avl_slot_diff_prod_loop
   --  DESCRIPTION:
   --      Assigns items to locations
   --  PARAMETERS:
   --      i_po_info_rec          - all relevant info pertaining to PO
   --      i_product_id           - product id of the item to be putaway
   --      i_cust_pref_vendor     -  customer preferred vendor for the item
                                    to be putaway
   --      i_aging_days           - aging days for items that need aging,-1
                                    for non aging items
   --      i_item_info_rec        - all relevant details pertaining to the
                                    item to be putaway
   --      io_workvar_rec         -  all the variables shared across the
                                     functions reside in this record
   --      i_syspar_var_rec       - all the system parameters

   --  RETURN VALUES:
   --      TRUE  - All the pallets for the item were assigned a putaway slot.
   --      FALSE - All the pallets for the item were not assigned a putaway
                   slot.
   --------------------------------------------------------------------------*/
   FUNCTION f_avl_slot_diff_prod_loop
         (i_po_info_rec        IN     PL_PUTAWAY_UTILITIES.T_PO_INFO,
          i_product_id         IN     pm.prod_id%TYPE,
          i_cust_pref_vendor   IN     pm.cust_pref_vendor%TYPE,
          i_aging_days         IN     aging_items.aging_days%TYPE,
          i_item_info_rec      IN     PL_PUTAWAY_UTILITIES.T_ITEM_RELATED_INFO,
          io_workvar_rec       IN OUT PL_PUTAWAY_UTILITIES.T_WORK_VAR,
          i_syspar_var_rec     IN     PL_PUTAWAY_UTILITIES.T_SYSPAR_VAR)
   RETURN BOOLEAN
   IS
      ln_index                     NUMBER;--count of the slot number
                                          --currently filled
      ln_pallet_cnt                NUMBER;
      lt_location                  loc.logi_loc%TYPE;--holds the location
                                                     --currently filled
      lt_old_loc                   loc.logi_loc%TYPE;
      lv_fname                     VARCHAR2(30);

   BEGIN
      --reset the global variable
      pl_log.g_program_name     := 'PL_GENERAL_RULE';
      ln_pallet_cnt   := 0;
      ln_index        := 1;
      lv_fname        := 'f_avl_slot_diff_prod_loop';
      --This will be used in the Exception message in assign putaway
      pl_putaway_utilities.gv_program_name := lv_fname;
      lt_location     := io_workvar_rec.gtbl_phys_loc(ln_index);
      --continue untill all the slots are filled or entire quantity
      --is putaway or the product exceeds maximum number of slots allowed
      --for that product
      WHILE ln_index <= io_workvar_rec.n_total_cnt
            AND io_workvar_rec.n_current_pallet < io_workvar_rec.n_num_pallets
            AND i_item_info_rec.n_max_slot > io_workvar_rec.n_slot_cnt
      LOOP
        --pallet qty fits in the remaining space
        pl_log.ins_msg ('DEBUG', lv_fname,'PO='||i_po_info_rec.v_erm_id
                        ||'Different prod loop: loc('||ln_index||')='
                        ||io_workvar_rec.gtbl_phys_loc(ln_index)
                        ||', slot_cnt='||io_workvar_rec.n_slot_cnt
                        ||', current_pallet='
                        ||(io_workvar_rec.n_current_pallet -1)
                        ||', pallet_cnt='
                        ||ln_pallet_cnt,NULL,NULL);
        IF  io_workvar_rec.gtbl_loc_height(ln_index)
            >= ((CEIL(io_workvar_rec.n_each_pallet_qty
                      /i_item_info_rec.n_ti))
                * i_item_info_rec.n_case_height
                + i_item_info_rec.n_skid_height)
        AND i_item_info_rec.n_pallet_stack > ln_pallet_cnt
        THEN
           --update inv and putawaylst tables
           pl_putaway_utilities.p_insert_table
                                    (i_product_id,
                                     i_cust_pref_vendor,
                                     io_workvar_rec.gtbl_phys_loc(ln_index),
                                     pl_putaway_utilities.ADD_RESERVE,
                                     i_po_info_rec.v_erm_id,
                                     i_aging_days,
                                     i_syspar_var_rec.v_clam_bed_tracked_flag,
                                     i_item_info_rec,
                                     io_workvar_rec);
           --reset the global variable
           pl_log.g_program_name     := 'PL_GENERAL_RULE';
           io_workvar_rec.n_current_pallet:=io_workvar_rec.n_current_pallet + 1;
           ln_pallet_cnt:=ln_pallet_cnt +1;
           IF io_workvar_rec.n_current_pallet =
             (io_workvar_rec.n_num_pallets - 1) THEN
              io_workvar_rec.n_each_pallet_qty := io_workvar_rec.
                                                  n_last_pallet_qty;
           END IF;
           --if slot being filled has change then increment the slot count
           IF lt_location = lt_old_loc THEN
             NULL;
           ELSE
             io_workvar_rec.n_slot_cnt := io_workvar_rec.n_slot_cnt + 1;
             lt_old_loc := lt_location;
           END IF;
            --if stackability index of the product is not zero then continue
            --putting away in the same slot else change the slot
           IF io_workvar_rec.n_current_pallet < io_workvar_rec.n_num_pallets
             AND i_item_info_rec.n_stackable > 0 THEN
             io_workvar_rec.gtbl_loc_height(ln_index) := io_workvar_rec.
                                                     gtbl_loc_height(ln_index)
                                                     -(((CEIL(io_workvar_rec.
                                                        n_each_pallet_qty
                                                        /i_item_info_rec.n_ti))
                                                        * i_item_info_rec.
                                                          n_case_height)
                                                        + i_item_info_rec.
                                                          n_skid_height);
             pl_log.ins_msg ('DEBUG', lv_fname,'PO='||i_po_info_rec.v_erm_id
                                              ||'Different prod loop: after '
                                              ||'insert  loc_height('||ln_index
                                              ||')='
                                              ||io_workvar_rec.
                                                gtbl_loc_height(ln_index)
                                              ,NULL,NULL);
             IF io_workvar_rec.n_current_pallet =
                (io_workvar_rec.n_num_pallets - 1) THEN
                io_workvar_rec.n_each_pallet_qty := io_workvar_rec.
                                                    n_last_pallet_qty;
             END IF;
          ELSE
             ln_pallet_cnt := 0;
             ln_index := ln_index + 1;
             IF ln_index <= io_workvar_rec.n_total_cnt THEN
                lt_location :=  io_workvar_rec.gtbl_phys_loc(ln_index);
             END IF; --end if ln_index <= io_workvar_rec.n_total_cnt
          END IF;--io_workvar_rec.n_current_pallet<io_workvar_rec.n_num_pallets
                 --AND i_item_info_rec.n_stackable > 0
       ELSE
          --if slot's available height is not enought
          --to putaway the current pallet then go to the next slot
          ln_index := ln_index + 1;
          ln_pallet_cnt := 0;
          IF ln_index <= io_workvar_rec.n_total_cnt THEN
             lt_location := io_workvar_rec.gtbl_phys_loc(ln_index);
          END IF;--ln_index <= io_workvar_rec.n_total_cnt
       END IF;
     END LOOP;
     IF  io_workvar_rec.n_current_pallet >= io_workvar_rec.n_num_pallets THEN
         RETURN(TRUE);
     ELSE
         RETURN(FALSE);
     END IF;
   END f_avl_slot_diff_prod_loop;


---------------------------------------------------------------------------
/* *****************************************************************************
-----------------------------------------------------------------------
-- Function:
--    F_Check_avail_slot_same_prod
--
-- Description:
-- Find available (non-open) slot of the same aisle with same
                             prod_id as putaway slot
--  PARAMETERS:
--      i_po_info_rec          - all relevant info pertaining to PO
--      i_product_id           - product id of the item to be putaway
--      i_cust_pref_vendor     -  customer preferred vendor for the item
                                 to be putaway
--      i_aging_days           - aging days for items that need aging,-1
                                 for non aging items
--      i_item_info_rec        - all relevant details pertaining to the
                                 item to be putaway
--      io_workvar_rec         -  all the variables shared across the
                                  functions reside in this record
--      i_syspar_var_rec       - all the system parameters
--      i_zone_id              - zone id of the zone for which this
                                 function is called
-- Return Values:
--    Returns TRUE if all the pallets for the item were assigned a
      putaway slot.
--    Returns FALSE if all the pallets for the item were NOT assigned
      a putaway slot.
--
--
-- Exceptions raised:
--
---------------------------------------------------------------------
*****************************************************************************/
   FUNCTION f_check_avail_slot_same_prod
          (i_dest_loc         IN      loc.logi_loc%TYPE,
           i_zone             IN      zone.zone_id%TYPE,
           i_prod_id          IN      pm.prod_id%TYPE,
           i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
           i_aging_days       IN      aging_items.aging_days%TYPE,
           i_po_info_rec      IN      pl_putaway_utilities.t_po_info,
           io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
           io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
           io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)

   RETURN BOOLEAN
   IS
      lt_dest_loc     io_work_var_rec.v_dest_loc%TYPE;
      lv_fname        VARCHAR2(30):= 'f_check_avail_slot_same_prod';
      lv_msg_text     VARCHAR2(500);

      l_work_var_rec  pl_putaway_utilities.t_work_var;

      ln_temp_height  NUMBER;
      ln_count        NUMBER := 0;
      li_counter      BINARY_INTEGER := 1;
      lb_more         BOOLEAN;
      lb_status       BOOLEAN := FALSE;

--this cursor fetches all the slots containing the product being putaway
--and having enough height available
      CURSOR c_avail_loc(i_temp_height number)
      IS
      SELECT DISTINCT l.logi_loc logi_loc,
                      l.available_height available_height,
                      l.put_aisle put_aisle,
                      l.put_slot put_slot,
                      l.put_level put_level,
                      l.put_path put_path
      FROM slot_type s,
           loc l,
           lzone lz,
           inv i
     WHERE s.slot_type = l.slot_type
       AND s.deep_ind = 'N'
       AND l.perm = 'N'
       AND l.status = 'AVL'
       AND l.available_height IS NOT NULL
       AND NVL(l.available_height,0)>=  i_temp_height
       AND l.logi_loc = lz.logi_loc
       AND lz.logi_loc = i.plogi_loc
       AND lz.zone_id = i_zone
       AND i.prod_id = i_prod_id
       AND i.cust_pref_vendor = i_cust_pref_vendor
       AND NOT EXISTS(SELECT NULL 
                           FROM inv 
                           WHERE plogi_loc = l.logi_loc 
                           AND (dmg_ind = 'Y'
                                /*D# 11309 MSKU changes*/
                                OR parent_pallet_id IS NOT NULL
                                /*END D# 11309 MSKU changes*/))
       AND NOT EXISTS (SELECT 'x'
                         FROM pm p2, inv k
                        WHERE p2.prod_id = k.prod_id
                          AND (p2.stackable > io_item_info_rec.n_stackable
                               OR p2.stackable = 0)
                          AND p2.cust_pref_vendor = k.cust_pref_vendor
                          AND k.plogi_loc = i.plogi_loc)
     ORDER BY l.available_height,
      ABS(io_work_var_rec.n_put_aisle1- l.put_aisle), l.put_aisle,
      ABS(io_work_var_rec.n_put_slot1- l.put_slot), l.put_slot,
      ABS(io_work_var_rec.n_put_level1- l.put_level), l.put_level ;

   BEGIN
      --reset the global variable
      pl_log.g_program_name     := 'PL_GENERAL_RULE';
      --This will be used in the Exception message in assign putaway
      pl_putaway_utilities.gv_program_name := lv_fname;
      --reset the array count also
      li_counter := 1;
      --reset the cursor count also
      ln_count := 0;
      --clear the array
      io_work_var_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
      io_work_var_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
      io_work_var_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
      io_work_var_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
      io_work_var_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
      io_work_var_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

      --Set the temp height to std pallet height
      IF (io_work_var_rec.n_current_pallet=io_work_var_rec.n_num_pallets - 1)
         AND io_work_var_rec.b_partial_pallet THEN
         ln_temp_height := io_work_var_rec.n_lst_pallet_height;
      ELSE
         ln_temp_height := io_work_var_rec.n_std_pallet_height;
      END IF;

      FOR v_avail_loc in c_avail_loc(ln_temp_height)
      LOOP
         --store everything in respective arrays

         io_work_var_rec.gtbl_phys_loc(li_counter)   := v_avail_loc.logi_loc;
         io_work_var_rec.gtbl_loc_height(li_counter) := v_avail_loc.available_height;
         io_work_var_rec.gtbl_put_aisle2(li_counter) := v_avail_loc.put_aisle;
         io_work_var_rec.gtbl_put_slot2(li_counter)  := v_avail_loc.put_slot;
         io_work_var_rec.gtbl_put_level2(li_counter) := v_avail_loc.put_level;
         io_work_var_rec.gtbl_put_path2(li_counter)  := v_avail_loc.put_path;
         --increment the array count
         li_counter:=li_counter+1;
         ln_count :=  c_avail_loc % ROWCOUNT;

      END LOOP;

      IF ln_count > 0 THEN
         lb_more := TRUE;
         --store total no of locations obtained
         --for particular product in its primary zone
         --io_work_var_rec.v_total_cnt := c_avail_loc % ROWCOUNT;
         io_work_var_rec.n_total_cnt := ln_count;
         lv_msg_text := 'PO='||i_po_info_rec.v_erm_id
                        ||'Matching same item slots = '
                        || io_work_var_rec.n_total_cnt;
         pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

         /* Process the records selected into the host arrays. */
         lb_status  := f_avail_slot_assign_loop(i_po_info_rec,
                                                i_prod_id,
                                                i_cust_pref_vendor,
                                                i_aging_days,
                                                io_item_info_rec,
                                                io_work_var_rec,
                                                io_syspar_var,
                                                pl_putaway_utilities.SAME);
      ELSIF ln_count = 0 THEN
         lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                       'PO='||i_po_info_rec.v_erm_id ||
                        ' ,TABLE = "LOC,INV"
                       ,KEY = ' || i_prod_id || ','
                        ||i_cust_pref_vendor || ','
                        || io_work_var_rec.v_slot_type || ','
                        ||i_zone || ' ,ACTION = "SELECT",'
                        ||'MESSAGE = "ORACLE no matching avail slots '
                        ||'with same item found in zone"';
         pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
      END IF;
      RETURN lb_status;
   EXCEPTION
      WHEN OTHERS THEN
         BEGIN
         lv_msg_text :='PO='||i_po_info_rec.v_erm_id
                   ||'f_check_avail_slot_same_prod unable to putaway product '
                   ||i_prod_id;
         pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
         END;

   END f_check_avail_slot_same_prod;




/* **********************************************************************
-----------------------------------------------------------------------
-- FUNCTION:
--    f_avail_slot_assign_loop
--
-- DESCRIPTION:
-- putaway pallets to the locations identified by
    f_check_avail_slot_same_prod
--  PARAMETERS:
--      i_po_info_rec          - all relevant info pertaining to PO
--      i_product_id           - product id of the item to be putaway
--      i_cust_pref_vendor     - customer preferred vendor for the item
                                 to be putaway
--      i_aging_days           - aging days for items that need aging,-1
                                 for non aging items
--      i_item_info_rec        - all relevant details pertaining to the
                                 item to be putaway
--      io_workvar_rec         - all the variables shared across the
                                 functions reside in this record
--      i_syspar_var_rec       - all the system parameters
--      i_same_or_different_flag - whether the function is called for
                                   putaway to locations containig same
                                   product or locations containing
                                   different product
-- RETURN VALUES:
--    Returns TRUE if all the pallets for the item were assigned a
      putaway slot.
--    Returns FALSE if all the pallets for the item were NOT assigned
      a putaway slot.
--
--
-- Exceptions raised:
--
---------------------------------------------------------------------
*************************************************************************/
FUNCTION f_avail_slot_assign_loop
  (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
   i_product_id                IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
   i_same_or_different_flag    IN     NUMBER)
RETURN BOOLEAN
IS
   lv_fname                     VARCHAR2(30);
   lt_location                  loc.logi_loc%TYPE;--holds the location
                                                     --currently filled
   lt_old_loc                   loc.logi_loc%TYPE;
   ln_pallet_cnt                NUMBER;
   ln_index                     NUMBER;--count of the slot number
                                          --currently filled
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_GENERAL_RULE';
   lv_fname        := 'f_avail_slot_assign_loop';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;
   ln_pallet_cnt   := 0;
   ln_index        := 1;
   lt_location := io_workvar_rec.gtbl_phys_loc(ln_index);
   IF i_same_or_different_flag = pl_putaway_utilities.SAME THEN
       pl_log.ins_msg ('DEBUG', lv_fname,
                       'PO='||i_po_info_rec.v_erm_id
                       ||'Starting slot SAME, product assign loop for item='
                       ||i_product_id||',cpv='||i_cust_pref_vendor
                       ||'slot_type='||io_workvar_rec.v_slot_type
                       ||', starting loc='||lt_location,NULL,NULL);
   ELSIF i_same_or_different_flag = pl_putaway_utilities.DIFFERENT THEN
      pl_log.ins_msg ('DEBUG', lv_fname,
                      'PO='||i_po_info_rec.v_erm_id
                      ||'Starting slot DIFFERENT, product assign loop for item='
                      ||i_product_id||',cpv='||i_cust_pref_vendor
                      ||'slot_type='||io_workvar_rec.v_slot_type
                      ||', starting loc='||lt_location,NULL,NULL);
   END IF;

   IF i_same_or_different_flag = pl_putaway_utilities.SAME THEN
      SELECT COUNT(*) INTO ln_pallet_cnt
        FROM inv
       WHERE plogi_loc = lt_location;

   END IF;

  --continue untill all the slots are filled or entire quantity
  --is putaway or the product exceeds maximum number of slots allowed
  --for that product (if i_same_or_different_flag is different)

   WHILE ln_index <= io_workvar_rec.n_total_cnt
         AND io_workvar_rec.n_current_pallet < io_workvar_rec.n_num_pallets
         AND (i_item_info_rec.n_max_slot > io_workvar_rec.n_slot_cnt
              OR i_same_or_different_flag = pl_putaway_utilities.SAME )
   LOOP

      pl_log.ins_msg ('DEBUG', lv_fname,'PO='||i_po_info_rec.v_erm_id
                               ||'loc('||ln_index||')='
                               ||io_workvar_rec.gtbl_phys_loc(ln_index)
                               ||', slot_cnt='||io_workvar_rec.n_slot_cnt
                               ||', current_pallet='
                               ||(io_workvar_rec.n_current_pallet -1)
                               ||', pallet_cnt='||ln_pallet_cnt,NULL,NULL);
     --if available height of the current slot is more than the pallet height
      --then putaway
     IF (io_workvar_rec.gtbl_loc_height(ln_index)>=
             (((CEIL(io_workvar_rec.n_each_pallet_qty /i_item_info_rec.n_ti))
               * i_item_info_rec.n_case_height)
               + i_item_info_rec.n_skid_height))
         AND i_item_info_rec.n_pallet_stack > ln_pallet_cnt THEN
         pl_putaway_utilities.p_insert_table
                                    (i_product_id,
                                     i_cust_pref_vendor,
                                     io_workvar_rec.gtbl_phys_loc(ln_index),
                                     pl_putaway_utilities.ADD_RESERVE,
                                     --io_workvar_rec.b_first_home_assign,
                                     i_po_info_rec.v_erm_id,
                                     i_aging_days,
                                     i_syspar_var_rec.v_clam_bed_tracked_flag,
                                     i_item_info_rec,
                                     io_workvar_rec);
         --reset the global variable
         pl_log.g_program_name     := 'PL_GENERAL_RULE';
         io_workvar_rec.n_current_pallet := io_workvar_rec.n_current_pallet + 1;
         ln_pallet_cnt := ln_pallet_cnt + 1;
         --if slot being filled has change then increment the slot count
         IF lt_location = lt_old_loc THEN
           NULL;
         ELSE
            IF i_same_or_different_flag = pl_putaway_utilities.DIFFERENT THEN
               io_workvar_rec.n_slot_cnt := io_workvar_rec.n_slot_cnt + 1;
              lt_old_loc := lt_location;
            END IF;
         END IF;
         --if stackability index of the product is not zero then continue
         --putting away in the same slot else change the slot
         IF  io_workvar_rec.n_current_pallet < io_workvar_rec.n_num_pallets
            AND  i_item_info_rec.n_stackable > 0
         THEN

            io_workvar_rec.gtbl_loc_height(ln_index)
                                   :=io_workvar_rec.gtbl_loc_height(ln_index)
                                      - ((CEIL(io_workvar_rec.n_each_pallet_qty
                                               /i_item_info_rec.n_ti)
                                         * i_item_info_rec.n_case_height)
                                         + i_item_info_rec.n_skid_height);
            IF  io_workvar_rec.n_current_pallet =
              (io_workvar_rec.n_num_pallets - 1) THEN
               io_workvar_rec.n_each_pallet_qty :=
               io_workvar_rec.n_last_pallet_qty;
            END IF;
         ELSE
            ln_pallet_cnt := 0;
            ln_index := ln_index + 1;
            IF ln_index <= io_workvar_rec.n_total_cnt THEN
               lt_location := io_workvar_rec.gtbl_phys_loc(ln_index) ;
               IF i_same_or_different_flag = pl_putaway_utilities.SAME THEN
                  SELECT COUNT(*) INTO ln_pallet_cnt
                  FROM inv
                  WHERE plogi_loc = lt_location;
               END IF;
            END IF;--if ln_index <= io_workvar_rec.n_total_cnt
         END IF;--io_workvar_rec.n_current_pallet
                --< io_workvar_rec.n_num_pallets
                --AND  i_item_info_rec.n_stackable > 0
      ELSE
         ln_index := ln_index + 1;
         ln_pallet_cnt := 0;
         IF ln_index <= io_workvar_rec.n_total_cnt THEN
            lt_location := io_workvar_rec.gtbl_phys_loc(ln_index);
            pl_log.ins_msg ('DEBUG', lv_fname,
                             'PO='||i_po_info_rec.v_erm_id
                             ||'new location ='||lt_location,NULL,NULL);
            IF i_same_or_different_flag = pl_putaway_utilities.SAME THEN
               SELECT COUNT(*) INTO ln_pallet_cnt
               FROM inv
               WHERE plogi_loc = lt_location;
            END IF;
         END IF;--ln_index <= io_workvar_rec.n_total_cnt
      END IF;--end else
   END LOOP;
   IF io_workvar_rec.n_current_pallet >= io_workvar_rec.n_num_pallets  THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;

END f_avail_slot_assign_loop;

/*   ---------------------------------------------------------------------
-- Function:
--    f_two_d_three_d
--
-- Description:
-- Putaway to deep slots.
**      2-D and 3-D putaway logic:
**      1. Find available slot with the same slot type and prod id and
**         enough height and if syspar MIX_SAME_PROD_DEEP_SLOT is "N" then
**         the pallets in the slot must all have the same receive date.
**      2. Find open slot with the same slot type and there is not a pallet
**         in the slot.
**      3. Find available slot with the same slot type and different
**         prod id if the syspar MIXPROD_FLAG allows and their is enough height.
--
-- Parameters:
--      i_dest_loc             Logical dest. location of the item
--      i_zone                 Zone id for the product
--      i_erm_id               PO number
--      i_prod_id              product id
--      i_cust_pref_vendor     Cust pref vendor for the product
--      io_work_var_rec        Record type instance which has parameter like
--                             each pallet qty,last pallet qty etc set
--      i_item_info_rec        Record type instance which has item related info
--      io_syspar_var          Record type which has syspar flags set
-- Return Values:
--      lb_status
--      Returns TRUE if all the pallets for the item were assigned a putaway
         slot.
--      Returns FALSE if all the pallets for the item were NOT assigned a
         putaway slot.

--
-- Exceptions raised:
---------------------------------------------------------------------*/
   FUNCTION f_two_d_three_d
        (i_dest_loc         IN      loc.logi_loc%TYPE,
         i_zone             IN      zone.zone_id%TYPE,
         i_erm_id           IN      erm.erm_id%TYPE,
         i_prod_id          IN      pm.prod_id%TYPE,
         i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
         i_aging_days       IN      aging_items.aging_days%TYPE,
         io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
         io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
         io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)


   RETURN BOOLEAN
 IS
      lv_fname          VARCHAR2(50):= 'f_two_d_three_d';
      lv_msg_text       VARCHAR2(500);
      lv_temp           VARCHAR2(1);
      --will be used for clearing all the arrays
      l_work_var_rec    pl_putaway_utilities.t_work_var;

      lv_temp_height    NUMBER;
      ln_count          NUMBER := 0;

      li_counter        BINARY_INTEGER := 1;
      lb_status         BOOLEAN := FALSE;



      --1 Find available slot with the same slot type and prod id and
      --enough height and if syspar MIX_SAME_PROD_DEEP_SLOT is "N" then
      --the pallets in the slot must all have the same receive date.

      --slot type check is removed from this query for compatibility
      --with bulk rule
      CURSOR c_reserve_loc(i_temp_height number)
         IS
          SELECT    DISTINCT l.logi_loc logi_loc,
                   NVL(l.available_height,0) available_height,
                   l.put_aisle put_aisle,
                   l.put_slot put_slot,
                   l.put_level put_level,
                   l.put_path put_path
           FROM   slot_type s,
                  lzone lz,
                  loc l,
                  inv i
          WHERE    s.slot_type = l.slot_type
            AND    s.deep_ind = 'Y'
            AND    lz.logi_loc = l.logi_loc
            AND    lz.zone_id = i_zone
            AND    l.perm = 'N'
            AND    l.status = 'AVL'
            AND    l.available_height IS NOT NULL
            AND     NVL(l.available_height,0) >= i_temp_height
            AND     l.logi_loc = i.plogi_loc
            AND     i.cust_pref_vendor = i_cust_pref_vendor
            AND     i.prod_id = i_prod_id
            AND     TRUNC(i.rec_date) =
                    TRUNC(DECODE(io_syspar_var.v_g_mix_same_prod_deep_slot,
                                  'Y', i.rec_date,
                                   SYSDATE))
            AND NOT EXISTS           --logical location selected must have same
                                 --combination of cust pref vendor and prod id
                                 --as of the current product
                  (SELECT 'x'
                     FROM inv i3
                    WHERE i3.plogi_loc = i.plogi_loc
                      AND (i3.prod_id <> i_prod_id
                            OR i3.cust_pref_vendor <> i_cust_pref_vendor))
           AND NOT EXISTS(SELECT NULL 
                               FROM inv i4 
                               WHERE i4.plogi_loc = i.plogi_loc 
                               AND i4.dmg_ind = 'Y')
         ORDER BY (NVL(available_height,0) - i_temp_height),
              ABS(io_work_var_rec.n_put_aisle1 - l.put_aisle), l.put_aisle,
              ABS(io_work_var_rec.n_put_slot1 - l.put_slot), l.put_slot,
              ABS(io_work_var_rec.n_put_level1 - l.put_level), l.put_level ;

      --2 open slots with same slot type
      --slot type check is removed from this query for compatibility with
      --bulk rule
      CURSOR c_open_slots IS
      SELECT l.logi_loc logi_loc,
             NVL(l.available_height,0) available_height,
             l.put_slot put_slot,
             l.put_level put_level,
             l.put_path put_path
        FROM pallet_type p,
             slot_type s,
             loc l,
             lzone lz
       WHERE   p.pallet_type   = l.pallet_type
         AND   s.slot_type     = l.slot_type
         AND   s.deep_ind = 'Y'
         AND ( ( io_syspar_var.v_pallet_type_flag = 'Y'
                 AND (l.pallet_type = io_item_info_rec.v_pallet_type
                     OR(l.pallet_type IN
                        ( SELECT mixed_pallet
                            FROM pallet_type_mixed pmix
                           WHERE pmix.pallet_type = io_item_info_rec.
                                                    v_pallet_type))))
               OR (io_syspar_var.v_pallet_type_flag = 'N'
                   AND l.pallet_type = io_item_info_rec.v_pallet_type ))
         AND   l.perm          = 'N'
         AND   l.status        = 'AVL'
         AND   l.available_height IS NOT NULL
         AND   NVL(l.available_height,0) >= io_work_var_rec.n_std_pallet_height
         AND   l.logi_loc      = lz.logi_loc
         AND   lz.zone_id       = i_zone
         AND NOT EXISTS (SELECT 'x'
                           FROM inv
                          WHERE plogi_loc = l.logi_loc)
       ORDER BY  NVL(l.available_height,0),
           ABS(io_work_var_rec.n_put_aisle1 - l.put_aisle), l.put_aisle,
           ABS(io_work_var_rec.n_put_slot1  - l.put_slot), l.put_slot,
           ABS(io_work_var_rec.n_put_level1 - l.put_level), l.put_level ;

      --3 available slot with different products
      --slot type check is removed from this query for compatibility
      --with bulk rule
      CURSOR c_avail_slot(i_temp_height number)
      IS
      SELECT DISTINCT l.logi_loc logi_loc,
             NVL(l.available_height,0) available_height,
             l.put_aisle put_aisle,
             l.put_slot put_slot,
             l.put_level put_level,
             l.put_path put_path
        FROM pallet_type p,
             slot_type s,
             loc l,
             lzone lz,
             inv i
       WHERE  p.pallet_type     = l.pallet_type
         AND  s.slot_type       = l.slot_type
         AND ( ( io_syspar_var.v_pallet_type_flag = 'Y'
                 AND (l.pallet_type = io_item_info_rec.v_pallet_type
                     OR(l.pallet_type IN
                        ( SELECT mixed_pallet
                            FROM pallet_type_mixed pmix
                           WHERE pmix.pallet_type = io_item_info_rec.
                                                    v_pallet_type))))
               OR (io_syspar_var.v_pallet_type_flag = 'N'
                   AND l.pallet_type = io_item_info_rec.v_pallet_type ))
         AND  s.deep_ind        = 'Y'
         AND l.logi_loc         = lz.logi_loc
         AND l.perm             = 'N'
         AND l.status           = 'AVL'
         AND l.available_height IS NOT NULL
         AND NVL(l.available_height,0)>= i_temp_height
         AND lz.logi_loc = i.plogi_loc
         AND lz.zone_id = i_zone
         AND (i.prod_id <> i_prod_id
               OR i.cust_pref_vendor <> i_cust_pref_vendor)
         AND (io_syspar_var.v_g_mix_same_prod_deep_slot = 'Y'
               OR NOT EXISTS
                    (SELECT 'x'
                       FROM inv i3
                      WHERE  i3.plogi_loc        = i.plogi_loc
                        AND  i3.prod_id          = i_prod_id
                        AND  i3.cust_pref_vendor = i_cust_pref_vendor
                        AND TRUNC(i3.rec_date)   != TRUNC(SYSDATE)))
       AND NOT EXISTS(SELECT NULL 
                           FROM inv i4 
                           WHERE i4.plogi_loc = i.plogi_loc 
                           AND (i4.dmg_ind = 'Y'
                                /*D# 11309 MSKU changes*/
                                OR i4.parent_pallet_id IS NOT NULL
                                /*END D# 11309 MSKU changes*/))
      ORDER BY available_height,
            ABS(io_work_var_rec.n_put_aisle1 - l.put_aisle), l.put_aisle,
            ABS(io_work_var_rec.n_put_slot1  - l.put_slot), l.put_slot,
            ABS(io_work_var_rec.n_put_level1 - l.put_level), l.put_level ;
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_GENERAL_RULE';

   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;
   /*
   ** 1. Find available slot with the same slot type and prod id and
   **    enough height and if syspar MIX_SAME_PROD_DEEP_SLOT is "N" then
   **    the pallets in the slot must all have the same receive date.
   */


   --check to ensure that not just one partial pallet present
   If  NOT ((io_work_var_rec.n_current_pallet=
             io_work_var_rec.n_num_pallets-1) AND
       (io_work_var_rec.b_partial_pallet)) THEN
   --clear the array


      io_work_var_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
      io_work_var_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
      io_work_var_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
      io_work_var_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
      io_work_var_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
      io_work_var_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

      --Set the temp height to std pallet height
      lv_temp_height := io_work_var_rec.n_std_pallet_height;
      /*
      ** Fetch the records into host arrays.
      */


      BEGIN
         FOR v_reserve_loc in c_reserve_loc(lv_temp_height)
         LOOP
            --store everything in respective arrays

          io_work_var_rec.gtbl_phys_loc(li_counter)   := v_reserve_loc.
                                                         logi_loc;
          io_work_var_rec.gtbl_loc_height(li_counter) := v_reserve_loc.
                                                         available_height;
          io_work_var_rec.gtbl_put_aisle2(li_counter) := v_reserve_loc.
                                                         put_aisle;
          io_work_var_rec.gtbl_put_slot2(li_counter)  := v_reserve_loc.
                                                         put_slot;
          io_work_var_rec.gtbl_put_level2(li_counter) := v_reserve_loc.
                                                         put_level;
          io_work_var_rec.gtbl_put_path2(li_counter)  := v_reserve_loc.
                                                         put_path;
          --increment the array count
          li_counter:=li_counter+1;
          ln_count :=  c_reserve_loc % ROWCOUNT;

         END LOOP;

         IF ln_count > 0 THEN
             --store total no of locations obtained
            --for particular product in its primary zone
            io_work_var_rec.n_total_cnt := ln_count;


            --log the message

            lv_msg_text := 'PO =' ||i_erm_id || ' Remaining pallets = '
                          || io_work_var_rec.n_num_pallets
                          || ',Matching same item slots = '
                          || io_work_var_rec.n_total_cnt;
            pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

            /* Process the records selected into the host arrays. */

            lb_status  := f_deep_slot_assign_loop(pl_putaway_utilities.SAME,
                                                  i_erm_id,
                                                  i_zone,
                                                  i_prod_id,
                                                  i_aging_days,
                                                  i_cust_pref_vendor,
                                                  io_work_var_rec,
                                                  io_item_info_rec,
                                                  io_syspar_var);

         ELSIF ln_count = 0 THEN

            lv_msg_text := 'PO =' ||i_erm_id || ' TABLE = "LOC,INV" '||
            ',KEY = ' || i_prod_id || ',' ||
             i_cust_pref_vendor || ',' || io_work_var_rec.v_slot_type || ','
             ||i_zone || ' ,ACTION = "SELECT",'
             ||'MESSAGE = "ORACLE no matching'
             ||' available slots with same prod found in zone"';
            pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
         END IF;
      EXCEPTION
         WHEN OTHERS THEN

         lv_msg_text := 'PO =' ||i_erm_id || ' TABLE = "LOC,INV" '||
             ',KEY = ' || i_prod_id || ',' ||
             i_cust_pref_vendor || ',' || io_work_var_rec.v_slot_type || ','
             ||i_zone || ' ,ACTION = "SELECT",'
             ||'MESSAGE = "ORACLE no matching'
             ||' available slots with same prod found in zone"';
         pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
      END;
   END IF;

   --  2. Find open slot with the same slot type and there is not a pallet
   --     in the slot.
   --check to ensure that not just one partial pallet present
   If NOT ((io_work_var_rec.n_current_pallet= io_work_var_rec.n_num_pallets-1)
     AND(io_work_var_rec.b_partial_pallet)) and NOT lb_status THEN

      --reset the array count also
      li_counter := 1;
      --reset the cursor count also
      ln_count := 0;
      --clear the array

      io_work_var_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
      io_work_var_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
      io_work_var_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
      io_work_var_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
      io_work_var_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
      io_work_var_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

      --   Fetch the records into host arrays.

      BEGIN
         FOR v_open_slots IN c_open_slots
         LOOP
            --store everything in respective arrays

           io_work_var_rec.gtbl_phys_loc(li_counter)   := v_open_slots.
                                                          logi_loc;
           io_work_var_rec.gtbl_loc_height(li_counter) := v_open_slots.
                                                          available_height;
           io_work_var_rec.gtbl_put_slot2(li_counter)  := v_open_slots.
                                                          put_slot;
           io_work_var_rec.gtbl_put_level2(li_counter) := v_open_slots.
                                                          put_level;
           io_work_var_rec.gtbl_put_path2(li_counter)  := v_open_slots.
                                                          put_path;
           --increment the array count
           li_counter:=li_counter+1;
           ln_count :=  c_open_slots % ROWCOUNT;

         END LOOP;

         IF ln_count > 0 THEN
            --store total no of locations obtained
            --for particular product in its primary zone


            io_work_var_rec.n_total_cnt := ln_count;


            --log the message

            lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                          'PO =' ||i_erm_id
                          || '  ,Remaining pallets = '
                          || io_work_var_rec.n_num_pallets
                          || ',Matching same item slots = '
                          || io_work_var_rec.n_total_cnt;
            pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

            /* Process the records selected into the host arrays. */

            lb_status  := f_two_D_three_D_Open_slot(i_zone,
                                                    i_prod_id,
                                                    i_aging_days,
                                                    i_erm_id,
                                                    i_cust_pref_vendor,
                                                    io_work_var_rec,
                                                    io_item_info_rec,
                                                    io_syspar_var);

         ELSIF ln_count = 0 THEN

            lv_msg_text := 'PO =' ||i_erm_id || ' TABLE = "LOC,INV"
            ,KEY = ' || i_prod_id || ',' ||
            i_cust_pref_vendor || ',' || io_work_var_rec.v_slot_type || ',' ||
            i_zone || ' ,ACTION = "SELECT",'
             ||'MESSAGE = "ORACLE no open matching deep slots found in zone"';
            pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
         END IF;
      EXCEPTION
         WHEN OTHERS THEN

         lv_msg_text := 'PO =' ||i_erm_id || ' TABLE = "LOC,INV",KEY ='
          || i_prod_id || ',' || i_cust_pref_vendor || ','
          || io_work_var_rec.v_slot_type || ',' || i_zone
          || ' ,ACTION = "SELECT",MESSAGE = "ORACLE no open matching '
                ||'deep slots found in zone"';
         pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
      END;
   END IF;
   --check to ensure that not just one partial pallet present
   --3. Find available slot with different prod if 2d3d_mixprod_flag is on.
   IF io_work_var_rec.b_partial_pallet = TRUE THEN
      lv_temp := 'Y';
   ELSE
      lv_temp := 'N';
   END IF;

   lv_msg_text := 'PO =' ||i_erm_id || ' Remaining pallet = '
                || io_work_var_rec.n_current_pallet
                || ' of ' ||io_work_var_rec.n_num_pallets
                || ',partial = ' || lv_temp;
   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   lv_msg_text := 'PO =' ||i_erm_id || ' Full pallet height = '
                  || io_work_var_rec.n_std_pallet_height
                  || ' , partial pallet height '
                  ||io_work_var_rec.n_lst_pallet_height;
   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   IF io_syspar_var.v_mix_prod_2d3d_flag = 'Y' THEN

      If NOT ((io_work_var_rec.n_current_pallet=
               io_work_var_rec.n_num_pallets-1) AND
        (io_work_var_rec.b_partial_pallet)) and NOT lb_status THEN

         --std pallet height already assigned to temp height
         --reset the array count also
         li_counter := 1;
         --reset the cursor count also
         ln_count := 0;
         --clear the array


         io_work_var_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
         io_work_var_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
         io_work_var_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
         io_work_var_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
         io_work_var_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
         io_work_var_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;


         --   Fetch the records into host arrays.
         BEGIN
            FOR v_avail_slot IN c_avail_slot(lv_temp_height)
            LOOP
                 --store everything in respective arrays
               io_work_var_rec.gtbl_phys_loc(li_counter)   := v_avail_slot.
                                                              logi_loc;
               io_work_var_rec.gtbl_loc_height(li_counter) := v_avail_slot.
                                                              available_height;
               io_work_var_rec.gtbl_put_aisle2(li_counter) := v_avail_slot.
                                                              put_aisle;
               io_work_var_rec.gtbl_put_slot2(li_counter)  := v_avail_slot.
                                                              put_slot;
               io_work_var_rec.gtbl_put_level2(li_counter) := v_avail_slot.
                                                              put_level;
               io_work_var_rec.gtbl_put_path2(li_counter)  := v_avail_slot.
                                                              put_path;
               --increment the array count
               li_counter:=li_counter+1;
               ln_count :=  c_avail_slot % ROWCOUNT;

            END LOOP;

            IF ln_count > 0 THEN

               io_work_var_rec.n_total_cnt := ln_count;


               lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                            'PO =' ||i_erm_id || '  ,Remaining pallets = '
                            || io_work_var_rec.n_num_pallets
                            || ',matching different item  slots = '
                            || io_work_var_rec.n_total_cnt;
               pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
               lb_status := f_deep_slot_assign_loop
                               (pl_putaway_utilities.DIFFERENT,
                                i_erm_id,
                                i_zone,
                                i_prod_id,
                                i_aging_days,
                                i_cust_pref_vendor,
                                io_work_var_rec,
                                io_item_info_rec,
                                io_syspar_var);
            ELSIF ln_count =0 THEN

               lv_msg_text := 'PO =' ||i_erm_id || ' TABLE = "LOC,INV"
               ,KEY = ' || i_prod_id || ',' ||
               i_cust_pref_vendor || ',' || io_work_var_rec.v_slot_type
                      || ',' ||i_zone
                      || ' ,ACTION = "SELECT",MESSAGE = "ORACLE no matching'
                      ||'available slots with diff prod found in zone"';
               pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
            END IF;
         EXCEPTION
            WHEN OTHERS THEN

            lv_msg_text := 'PO =' ||i_erm_id || ' TABLE = "LOC,INV"
                       ,KEY = ' || i_prod_id || ',' ||
                       i_cust_pref_vendor || ',' || io_work_var_rec.v_slot_type
                       || ',' ||
                       i_zone || ' ,ACTION = "SELECT", ' ||
                       ' MESSAGE = "ORACLE no matching available slots'
                       ||' with diff prod found in zone"';
            pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
         END;
      END IF;--current pallet is not the partial pallet
   END IF;--mix_prod_2d3d flag set to y
   RETURN lb_status;

 EXCEPTION
   WHEN OTHERS THEN
   --ROLLBACK IN THE MAIN PACKAGE
   RAISE;
 END f_two_d_three_d;


/*---------------------------------------------------------------------
-- Function:
--    f_two_d_three_d_open_slot
--
-- Description:
-- Putaway to open slots.
**      Find open slot with the same slot type and such that there is
         not any pallet in the
**      Slot.

--
-- Parameters:

--      i_zone_id                Zone id for the product
--      i_erm_id                 PO number
--       i_prod_id                product id
--      i_aging_days             no.of aging days for the item
--      i_cust_pref_vendor       Cust pref vendor for the product
--      io_work_var_rec          Record type instance which has parameter like
                                 each pallet qty,last pallet qty etc set
--      io_item_info_rec         Record type instance which has item related
                                 info
--      io_syspar_var            Record type which has syspar flags set
-- Return Values:
--      lb_status
--      Returns TRUE if all the pallets for the item were assigned a
        putaway slot.
--      Returns FALSE if all the pallets for the item were NOT
        assigned a putaway slot.

--
-- Exceptions raised:
---------------------------------------------------------------------*/
FUNCTION f_two_d_three_d_open_slot
          (i_zone_id          IN      zone.zone_id%TYPE,
           i_prod_id          IN      pm.prod_id%TYPE,
           i_aging_days       IN      aging_items.aging_days%TYPE,
           i_erm_id           IN      erm.erm_id%TYPE,
           i_cust_pref_vendor IN      pm.cust_pref_vendor%TYPE,
           io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
           io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
           io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
RETURN BOOLEAN
IS
   lv_fname          VARCHAR2(50):= 'f_two_d_three_d_open_slot';
   lv_msg_text       VARCHAR2(500);
   lv_error_text     VARCHAR2(500);
   ln_num_positions  NUMBER;
   ln_index          NUMBER := 1;
   ln_inserted       NUMBER;
   ln_counter        NUMBER;


BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_GENERAL_RULE';

   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;
   lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                 'PO =' ||i_erm_id || '  ,Open deep slot for an item'
                 || i_prod_id
                 || ',cust pref vendor = '
                 ||i_cust_pref_vendor || ', with slot type = '
                 || io_work_var_rec.v_slot_type || ', starting pallet '
                 || io_work_var_rec.n_current_pallet || 'OF '
                 || io_work_var_rec.n_num_pallets;
   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   --set slot count to 0
   io_work_var_rec.n_slot_cnt := 0;

   IF io_item_info_rec.v_max_slot_flag='Z' THEN
      SELECT COUNT(DISTINCT i.plogi_loc)
        INTO    io_work_var_rec.n_slot_cnt
        FROM    lzone l, inv i
       WHERE    l.logi_loc         = i.plogi_loc
         AND    l.zone_id          = i_zone_id
         AND    i.cust_pref_vendor = i_cust_pref_vendor
         AND    i.prod_id          = i_prod_id;
   END IF;

   lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                 'PO =' ||i_erm_id || '  ,deep : max slots = '
                 || io_item_info_rec.n_max_slot || ',slot cnt = ' ||
   io_work_var_rec.n_slot_cnt;

   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   WHILE((io_item_info_rec.n_max_slot > io_work_var_rec.n_slot_cnt)
        AND (ln_index <= io_work_var_rec.n_total_cnt)
        AND(io_work_var_rec.n_current_pallet < io_work_var_rec.n_num_pallets))
        AND NOT ((io_work_var_rec.n_current_pallet=
                  io_work_var_rec.n_num_pallets-1)
                  AND (io_work_var_rec.b_partial_pallet))
   LOOP

      ln_inserted := 0;

      lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                    'PO =' ||i_erm_id || '  ,Deep : loc = '
                     || io_work_var_rec.gtbl_phys_loc(ln_index)
                     || ',height = ' ||io_work_var_rec.gtbl_loc_height(ln_index)
                     || ',' || ln_index || 'of '
                     ||io_work_var_rec.n_total_cnt || 'current pallet = '
                     ||io_work_var_rec.n_current_pallet || 'OF '
                     ||io_work_var_rec.n_num_pallets;
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
      /*
      **  Put a pallet in each position because
      **  location height is >= home slot height.
      */
      ln_counter := 0;

      --Has to be selected for that particular slot
      SELECT (NVL(s.deep_positions,1)*NVL(l.width_positions,1))
        INTO   ln_num_positions
        FROM   loc l,slot_type s
       WHERE   l.slot_type        = s.slot_type
         AND   l.logi_loc         = io_work_var_rec.gtbl_phys_loc(ln_index);


      WHILE (ln_counter < ln_num_positions)
          AND (io_work_var_rec.n_current_pallet
                   < io_work_var_rec.n_num_pallets)
          AND NOT ((io_work_var_rec.n_current_pallet=
                   io_work_var_rec.n_num_pallets-1)
                   AND (io_work_var_rec.b_partial_pallet))
      LOOP
         pl_putaway_utilities.p_insert_table
                                      (i_prod_id,
                                       i_cust_pref_vendor,
                                       io_work_var_rec.gtbl_phys_loc(ln_index),
                                       pl_putaway_utilities.ADD_RESERVE,
                                       --io_work_var_rec.b_first_home_assign,
                                       i_erm_id,
                                       i_aging_days,
                                       --io_item_info_rec.v_category,
                                       io_syspar_var.v_clam_bed_tracked_flag,
                                       io_item_info_rec,
                                       io_work_var_rec);
         --reset the global variable
         pl_log.g_program_name     := 'PL_GENERAL_RULE';
         io_work_var_rec.n_current_pallet := io_work_var_rec.n_current_pallet + 1;
         ln_inserted := ln_inserted + 1;
         ln_counter := ln_counter + 1;
      END LOOP;

      IF  ln_inserted > 0 THEN
         io_work_var_rec.n_slot_cnt := io_work_var_rec.n_slot_cnt + 1;
      END IF;
      ln_index := ln_index + 1;
   END LOOP;

   IF  (io_work_var_rec.n_current_pallet >= io_work_var_rec.n_num_pallets)
   THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
   --rollback in the main package
   --if no other error message is there in global variable
   --then only assign new mesage
   --otherwise raise the error with same message
   IF  pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.SUCCESS
   THEN
      lv_error_text := 'Error in 2d3d open slot' || sqlcode || sqlerrm;
      pl_putaway_utilities.gv_crt_message := lv_error_text;
   END IF;
   RAISE;

END f_two_d_three_d_open_slot;

------------------------------------------------------------------------------
/*****************************************************************************
Function
f_deep_slot_assign_loop

-  Description:
This function loops through available deep slot and check if space
is enough for a pallet.
If so, the pallet is assigned to that slot.

--
-- Parameters:
--      i_same_diff_flag         Flag which indicates deep slot assign loop
--is called for same or different items
--      i_erm_id               PO number
--      i_zone_id              Zone id for the product
--      i_prod_id              product id
--      i_aging_days           no.of aging days for the item
--      i_cust_pref_vendor     Cust pref vendor for the product

--      io_work_var_rec        Record type instance which has parameter like
--                             each pallet qty,last pallet qty etc set
--     io_item_info_rec        Record type instance which has item related info
--      io_syspar_var            Record type which has syspar flags set
-- Return Values:
--      lb_status
--      Returns TRUE if all the pallets for the item were assigned a putaway
        slot.
--      Returns FALSE if all the pallets for the item were NOT assigned a
        putaway slot.

--
-- Exceptions raised:
---------------------------------------------------------------------*/
FUNCTION f_deep_slot_assign_loop
          (i_same_diff_flag   IN      integer,
           i_erm_id           IN      erm.erm_id%type,
           i_zone_id          IN      zone.zone_id%type,
           i_prod_id          IN      pm.prod_id%type,
           i_aging_days       IN      aging_items.aging_days%type,
           i_cust_pref_vendor IN      pm.cust_pref_vendor%type,
           io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
           io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
           io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
RETURN BOOLEAN
IS

   TYPE t_exist_item_ht IS TABLE OF inv.pallet_height%TYPE
   INDEX BY BINARY_INTEGER;
   TYPE t_exist_item_flag IS TABLE OF varchar2(1) INDEX BY BINARY_INTEGER;

   lv_fname            VARCHAR2(50):= 'f_deep_slot_assign_loop';
   lv_msg_text         VARCHAR2(500);
   lv_same_diff_flag   VARCHAR2(15);
   lv_error_text       VARCHAR2(500);

   ln_num_positions    NUMBER;
   ln_pallet_cnt       NUMBER;

   li_index            INTEGER := 1;
   li_inv_cnt          INTEGER;
   li_inserted_record  INTEGER;
   li_counter          INTEGER;

   lt_put_factor2      loc.width_positions%TYPE;
   lt_location         loc.logi_loc%TYPE;
   lt_ht_occupied      inv.pallet_height%TYPE;
   lt_position_ht      loc.slot_height%TYPE;
   lt_position_used    inv.pallet_height%TYPE;

   ltbl_exist_item_ht  t_exist_item_ht;
   lv_exist_item_flag  t_exist_item_flag;

   ln_loop_cntr       BINARY_INTEGER := 1;

   lb_finish          BOOLEAN := FALSE;

   CURSOR c_pallet_ht(i_location loc.logi_loc%type)IS
   SELECT i.pallet_height pallet_height
     FROM   pm p, inv i
    WHERE  p.prod_id          = i.prod_id
      AND    p.cust_pref_vendor = i.cust_pref_vendor
      AND    i.plogi_loc        = i_location
    ORDER BY i.pallet_height DESC;
BEGIN
--reset the global variable
pl_log.g_program_name     := 'PL_GENERAL_RULE';
--This will be used in the Exception message in assign putaway
pl_putaway_utilities.gv_program_name := lv_fname;

IF    i_same_diff_flag  = pl_putaway_utilities.SAME THEN
   lv_same_diff_flag := 'same';
ELSIF i_same_diff_flag  = pl_putaway_utilities.DIFFERENT THEN
   lv_same_diff_flag := 'different';
END IF;

lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
              'PO =' ||i_erm_id || '  ,Starting deep slot '
              || lv_same_diff_flag
              || ',product assign loop for item '
              ||i_prod_id || ',' || i_cust_pref_vendor || ', with slot type '
              || io_work_var_rec.v_slot_type;
pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

--Set the slot count
--for same product it will be zero because alreay assigned
--globally in p_assign_putaway_slot proc of pl_putaway_utilties package

IF i_same_diff_flag = pl_putaway_utilities.DIFFERENT THEN

   SELECT COUNT(DISTINCT i.plogi_loc) INTO io_work_var_rec.n_slot_cnt
     FROM lzone l, inv i
    WHERE l.logi_loc       = i.plogi_loc
      AND l.zone_id          = i_zone_id
      AND i.cust_pref_vendor = i_cust_pref_vendor
      AND i.prod_id          = i_prod_id;

END IF;

--Main loop for assigning pallets to the locations

WHILE ((io_item_info_rec.n_max_slot > io_work_var_rec.n_slot_cnt)
        AND(li_index <= io_work_var_rec.n_total_cnt)
        AND(io_work_var_rec.n_current_pallet < io_work_var_rec.n_num_pallets))
        AND NOT ((io_work_var_rec.n_current_pallet=
                  io_work_var_rec.n_num_pallets-1)
                 AND (io_work_var_rec.b_partial_pallet))
LOOP

   ln_pallet_cnt := 0;
   --pick the location in the array one by one
   lt_location := io_work_var_rec.gtbl_phys_loc(li_index);

   SELECT (NVL(s.deep_positions,1)*NVL(l.width_positions,1))
     INTO   lt_put_factor2
     FROM   loc l,slot_type s
    WHERE   l.slot_type        = s.slot_type
      AND   l.logi_loc         = lt_location;


   --SET THE VALUE IN RECORD TYPE
   io_work_var_rec.n_put_deep_factor2 := lt_put_factor2;



   --get the no of pallets alreay present in the slot
   SELECT COUNT(*) INTO ln_pallet_cnt
   FROM inv
   WHERE plogi_loc = lt_location;


   /*Get the height occupied by each pallet in the slot
   ordering by the pallet with the tallest height */

   FOR r_pallet_ht IN c_pallet_ht(lt_location)
   LOOP
      ltbl_exist_item_ht(ln_loop_cntr) := r_pallet_ht.pallet_height;
      ln_loop_cntr := ln_loop_cntr + 1;
      --number of pallets in this location
      li_inv_cnt := c_pallet_ht%ROWCOUNT;
   END LOOP;

   --initialise the ht occupied to zero
   lt_ht_occupied := 0;

   --get the position height
   BEGIN
    SELECT l.slot_height INTO lt_position_ht
      FROM loc l
     WHERE l.logi_loc = lt_location ;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
      lt_position_ht := 0;
   END;
    --set flag to N for all items
   --this flag will be changed to Y as existing pallets
   --are rearranged in the location

   FOR ln_loop_cntr IN 1..li_inv_cnt
   LOOP
      lv_exist_item_flag(ln_loop_cntr) := 'N';
   END LOOP;

   /*This loop gives total height occupied by existing pallets
   in the slot*/

   --Set the flag For each iteration
    lb_finish := FALSE;

   WHILE ((lt_put_factor2 <> 0) and (NOT lb_finish) )
   LOOP

      lt_ht_occupied := 0;
      /*
      **  Load position with largest remaining pallet.
      */
      FOR ln_loop_cntr IN 1..li_inv_cnt
      LOOP
         IF lv_exist_item_flag(ln_loop_cntr) = 'N' THEN
            lt_ht_occupied := ltbl_exist_item_ht(ln_loop_cntr);
            lv_exist_item_flag(ln_loop_cntr) := 'Y';
            EXIT;
         END IF;
      END LOOP;
      /*
      **  Determine if can stack a smaller pallet on top.
      */

      FOR ln_loop_cntr IN 1..li_inv_cnt
      LOOP
         IF (lt_position_ht-lt_ht_occupied) >= ltbl_exist_item_ht(ln_loop_cntr)
         AND
            lv_exist_item_flag(ln_loop_cntr) = 'N' THEN

            lt_ht_occupied := lt_ht_occupied +  ltbl_exist_item_ht(ln_loop_cntr);
            lv_exist_item_flag(ln_loop_cntr) := 'Y';

         END IF;
      END LOOP;
      /*
      **  Determine if all pallets putaway.
      */
      FOR ln_loop_cntr IN 1..li_inv_cnt
      LOOP
         IF lv_exist_item_flag(ln_loop_cntr) = 'N' THEN
            lb_finish := FALSE;
            EXIT;
         ELSE
            lb_finish := TRUE;
         END IF;
      END LOOP;
      /*
      **  If more pallets, then get next position.
      */

      IF NOT lb_finish THEN
         lt_put_factor2 := lt_put_factor2 -1;
         io_work_var_rec.gtbl_loc_height(li_index)
         := io_work_var_rec.gtbl_loc_height(li_index) -lt_position_ht;
      END IF;

   END LOOP; --total height occupied


   lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                'PO =' ||i_erm_id ||
                '  ,Loc = ' || lt_location || ',pallet count =  '
                || ln_pallet_cnt || ',num of pos. = ' || ln_num_positions
                || ',start pos ' || lt_put_factor2;
   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   --NOW ASSIGN THE PALLETS

   li_inserted_record := 0;
   li_counter := lt_put_factor2;


   WHILE  li_counter > 0 and lb_finish = TRUE
   LOOP
      lt_position_used := lt_position_ht;
      lt_position_used := lt_position_used - lt_ht_occupied;

      WHILE(lt_position_used >= io_work_var_rec.n_std_pallet_height)
            AND NOT ((io_work_var_rec.n_current_pallet=
                      io_work_var_rec.n_num_pallets-1)
                      AND (io_work_var_rec.b_partial_pallet))
      LOOP
         lt_position_used := lt_position_used -
                            io_work_var_rec.n_std_pallet_height;
         pl_putaway_utilities.p_insert_table
                                   (i_prod_id,
                                    i_cust_pref_vendor,
                                    io_work_var_rec.gtbl_phys_loc(li_index),
                                    pl_putaway_utilities.ADD_RESERVE,
                                    --io_work_var_rec.b_first_home_assign,
                                    i_erm_id,
                                    i_aging_days,
                                    --io_item_info_rec.v_category,
                                    io_syspar_var.v_clam_bed_tracked_flag,
                                    io_item_info_rec,
                                    io_work_var_rec);
         --reset the global variable
         pl_log.g_program_name     := 'PL_GENERAL_RULE';
         li_inserted_record := li_inserted_record +1;
         io_work_var_rec.n_current_pallet := io_work_var_rec.n_current_pallet
                                             + 1;
         ln_pallet_cnt := ln_pallet_cnt + 1;
         IF (io_work_var_rec.n_current_pallet >= io_work_var_rec.n_num_pallets)
         THEN
            EXIT; /* No more pallets */
         End If;


      END LOOP;
      --reset the height occupied
      lt_ht_occupied := 0;

      IF (io_work_var_rec.n_current_pallet >= io_work_var_rec.n_num_pallets)
      THEN
         EXIT; /* No more pallets */
      END IF;

      --DECREMENT THE COUNTER
      li_counter := li_counter -1;

   END LOOP;/* for each available position */
   IF  ((i_same_diff_flag = pl_putaway_utilities.DIFFERENT)
       AND (li_inserted_record > 0))
   THEN
      io_work_var_rec.n_slot_cnt := io_work_var_rec.n_slot_cnt +1;
   END IF;

   li_index := li_index +1;

END LOOP; --end while index loop
IF  (io_work_var_rec.n_current_pallet >= io_work_var_rec.n_num_pallets) THEN
   RETURN TRUE;
ELSE
   RETURN FALSE;
END IF;

EXCEPTION
   WHEN OTHERS THEN
   --log the message
   --if no other error message is there in global variable then only assign
   --new mesage otherwise raise the error with same message
   IF  pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.SUCCESS
   THEN

      lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                    'PO =' ||i_erm_id || '  ,TABLE = "LOC",KEY = '
                    || io_work_var_rec.gtbl_phys_loc(li_index)
                    || ',ACTION = "SELECT" '
                    ||'"Deep: ORACLE unable to get height of location" ';
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
      lv_error_text := sqlcode || sqlerrm;

      pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
                                             || i_erm_id;
      pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to select from inv for plogi_loc '
               || io_work_var_rec.gtbl_phys_loc(li_index)
               ||' in Deep slot assign loop -sqlcode '
               ||lv_error_text;
   END IF;
   RAISE;
   --ROLLBACK IN THE MAIN

END f_deep_slot_assign_loop;

/*---------------------------------------------------------------------
-- Function:
--    f_check_open_slot
--
-- Description:
-- Find open slot of the same aisle as putaway slot
--
-- Parameters:
--      i_dest_loc               Logical dest. location of the item
--      i_zone                   Zone id for the product
--      i_erm_id                 PO number
--      i_prod_id                product id
--      i_cust_pref_vendor       Cust pref vendor for the product
--      io_work_var_rec          Record type instance which has parameter like
--                               each pallet qty,last pallet qty etc set
--      io_item_info_rec       Record type instance which has item related info
--      io_syspar_var            Record type which has syspar flags set
-- Return Values:
--      lb_status
--      Returns TRUE if all the pallets for the item were assigned a putaway
        slot.
--      Returns FALSE if all the pallets for the item were NOT assigned
        a putaway slot.

--
-- Exceptions raised:
---------------------------------------------------------------------*/
FUNCTION f_check_open_slot
          (i_dest_loc         IN      loc.logi_loc%type,
           i_zone             IN      zone.zone_id%type,
           i_erm_id           IN      erm.erm_id%type,
           i_prod_id          IN      pm.prod_id%type,
           i_cust_pref_vendor IN      pm.cust_pref_vendor%type,
           i_aging_days       IN      aging_items.aging_days%TYPE,
           io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
           io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
           io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
RETURN BOOLEAN
IS
   lv_fname                  VARCHAR2(20):= 'f_check_open_slot';
   lv_msg_text               VARCHAR2(500);
   lb_more_slot              BOOLEAN := TRUE;
   lb_status                 BOOLEAN := FALSE;
   ln_loop_cntr              BINARY_INTEGER := 1;
   ln_count                  NUMBER := 0;
   lt_put_aisle              loc.put_aisle%TYPE;
   lt_available_height       loc.available_height%TYPE;
   lt_temp_height            inv.pallet_height%TYPE;

   --will be used for clearing all the arrays

   l_work_var_rec   pl_putaway_utilities.t_work_var;


   CURSOR c_open_slot(i_temp_height inv.pallet_height%TYPE)
   IS
   SELECT l.logi_loc logi_loc,
          NVL(l.available_height,0) available_height,
          l.put_slot put_slot,
          l.put_level put_level,
          l.put_path put_path
    FROM  pallet_type p,
          slot_type s,
          loc l,
          lzone lz
  WHERE   s.slot_type = l.slot_type
     AND  s.deep_ind = 'N'
     AND  (((io_syspar_var.v_pallet_type_flag = 'Y')
             AND (l.pallet_type = io_item_info_rec.v_pallet_type OR
                  (l.pallet_type IN
                   (SELECT mixed_pallet
                    FROM pallet_type_mixed pmix
                    WHERE pmix.pallet_type = io_item_info_rec.v_pallet_type))))
           OR ((io_syspar_var.v_pallet_type_flag = 'N')
                AND(s.slot_type =io_work_var_rec.v_slot_type)))
    AND l.perm = 'N'
    AND l.status = 'AVL'
    AND l.available_height IS NOT NULL
    AND l.slot_height >= i_temp_height
    AND l.logi_loc = lz.logi_loc
    AND lz.zone_id = i_zone
    AND NOT EXISTS(SELECT 'x'
                     FROM inv i
                    WHERE i.plogi_loc = l.logi_loc)
  ORDER BY NVL(l.available_height,0),
        ABS(io_work_var_rec.n_put_aisle1 - l.put_aisle), l.put_aisle,
        ABS(io_work_var_rec.n_put_slot1 - l.put_slot), l.put_slot,
        ABS(io_work_var_rec.n_put_level1 - l.put_level), l.put_level;

   --------------------------------------------------------------------

   CURSOR c_each_aisle(i_temp_height inv.pallet_height%TYPE)
   IS
   SELECT DISTINCT l.put_aisle put_aisle,
          NVL(l.available_height,0) available_height
     FROM  pallet_type p, slot_type s, loc l, lzone lz
    WHERE p.pallet_type = l.pallet_type
      AND s.slot_type = l.slot_type
      AND s.deep_ind = 'N'
      AND (((io_syspar_var.v_pallet_type_flag = 'Y')
            AND (l.pallet_type = io_item_info_rec.v_pallet_type OR
                 (l.pallet_type IN
                   (SELECT mixed_pallet
                    FROM  pallet_type_mixed pmix
                    WHERE pmix.pallet_type = io_item_info_rec.v_pallet_type))))
          OR ((io_syspar_var.v_pallet_type_flag = 'N')
     AND (s.slot_type =io_work_var_rec.v_slot_type)))
     AND l.perm = 'N'
     AND l.status = 'AVL'
     AND l.available_height IS NOT NULL
    AND l.slot_height >= i_temp_height
    AND lz.logi_loc = l.logi_loc
    AND lz.zone_id = i_zone
  ORDER BY NVL(l.available_height,0),
        ABS(io_work_var_rec.n_put_aisle1 - l.put_aisle),
           l.put_aisle;

   -----------------------------------------------------------------------

   CURSOR c_aisle_open_slot(i_available_height loc.available_height%type,
                            i_put_aisle        loc.put_aisle%type)
   IS
   SELECT l.logi_loc logi_loc,
          NVL(l.available_height,0) available_height,
          l.put_aisle put_aisle,
          l.put_slot put_slot,
          l.put_level put_level,
          l.put_path put_path
     FROM pallet_type p,
          slot_type s,
          loc l,
          lzone lz
    WHERE p.pallet_type = l.pallet_type
      AND s.slot_type = l.slot_type
      AND s.deep_ind = 'N'
      AND l.perm = 'N'
      AND l.status = 'AVL'
      AND l.available_height IS NOT NULL
      AND NVL(l.available_height,0) = i_available_height
      AND l.put_aisle = i_put_aisle
      AND l.logi_loc = lz.logi_loc
      AND lz.zone_id = i_zone
      AND NOT EXISTS(SELECT 'x'
                       FROM inv i
                      WHERE i.plogi_loc = l.logi_loc)
    ORDER BY NVL(l.available_height,0),
           ABS(io_work_var_rec.n_put_slot1  - l.put_slot), l.put_slot,
           ABS(io_work_var_rec.n_put_level1 - l.put_level), l.put_level;


BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_GENERAL_RULE';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   /***************************************************************/
   /* Find open slot for standard pallet, the slot count for this */
   /* prod_id can not exceed max_slot in this zone. The open slots*/
   /* in this aisle are select into array order from nearest to   */
   /* farest.                                                     */
   /***************************************************************/

   --Set the temp height
   IF (io_work_var_rec.n_current_pallet=io_work_var_rec.n_num_pallets - 1)
       AND io_work_var_rec.b_partial_pallet THEN
       lt_temp_height := io_work_var_rec.n_lst_pallet_height;
   ELSE
       lt_temp_height := io_work_var_rec.n_std_pallet_height;
   END IF;

   IF io_item_info_rec.v_max_slot_flag = 'Z' THEN
      BEGIN
         SELECT COUNT(DISTINCT i.plogi_loc)
           INTO io_work_var_rec.n_slot_cnt
           FROM lzone l, inv i
          WHERE l.logi_loc          = i.plogi_loc
            AND l.zone_id           = i_zone
            AND i.cust_pref_vendor  = i_cust_pref_vendor
            AND i.prod_id           = i_prod_id;

         lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                      'PO =' ||i_erm_id || '  , Max slot = '
                      || io_item_info_rec.n_max_slot
                      || ',number of slots found in zone = '
                      || io_work_var_rec.n_slot_cnt;

         pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);

         IF io_item_info_rec.n_max_slot > io_work_var_rec.n_slot_cnt THEN
         --clear the array

            io_work_var_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
            io_work_var_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
            io_work_var_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
            io_work_var_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
            io_work_var_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;


            BEGIN
               FOR r_open_slot IN c_open_slot(lt_temp_height)
               LOOP
                  io_work_var_rec.gtbl_phys_loc(ln_loop_cntr)
                                      := r_open_slot.logi_loc;
                  io_work_var_rec.gtbl_loc_height(ln_loop_cntr)
                                      := r_open_slot.available_height;
                  io_work_var_rec.gtbl_put_slot2(ln_loop_cntr)
                                      := r_open_slot.put_slot;
                  io_work_var_rec.gtbl_put_level2(ln_loop_cntr)
                                      := r_open_slot.put_level;
                  io_work_var_rec.gtbl_put_path2(ln_loop_cntr)
                                      := r_open_slot.put_path;
                  --increment the array count
                  ln_loop_cntr:=ln_loop_cntr+1;
                  ln_count :=  c_open_slot % ROWCOUNT;
               END LOOP;
               IF ln_count > 0 THEN
                  io_work_var_rec.n_total_cnt := ln_count;


                  lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                                'PO =' ||i_erm_id
                                || '  ,number of open slots ' ||
                                ' found in zone = '
                               || io_work_var_rec.n_total_cnt;
                  pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

                  /*
                  ** Found an open slot
                  ** Assign qty to the slot
                  */

                  lb_status := f_open_slot_assign_loop(i_erm_id,
                                                       i_zone,
                                                       i_prod_id,
                                                       i_aging_days,
                                                       i_cust_pref_vendor,
                                                       io_work_var_rec,
                                                       io_item_info_rec,
                                                       io_syspar_var);
               ELSIF ln_count = 0 THEN

                  lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                   'PO =' ||i_erm_id
                   || '  ,TABLE = "PALLET_TYPE,SLOT_TYPE,LOC"
                  ,KEY = ' || i_prod_id || ',' ||
                  i_cust_pref_vendor || ','
                  || io_work_var_rec.n_home_slot_height
                  || ',' ||i_zone || ' ,ACTION = "SELECT",MESSAGE = '
                  ||'"ORACLE No open slots > than home height in zone."';
                  pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
               END IF;
            EXCEPTION
               WHEN OTHERS THEN

                  lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                  'PO =' ||i_erm_id
                  || '  ,TABLE = "PALLET_TYPE,SLOT_TYPE,LOC"'
                  ||',KEY = ' || i_prod_id || ',' || i_cust_pref_vendor || ','
                  || io_work_var_rec.n_home_slot_height || ',' ||
                  i_zone || ' ,ACTION = "SELECT",MESSAGE = ' ||
                  ' "ORACLE No open slots > than home height in zone."';
                  pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
            END;

         END IF; /* max slot > slot cnt */
      EXCEPTION
         WHEN OTHERS THEN

            lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                         'PO =' ||i_erm_id
                         || '  ,KEY = ' || i_prod_id || ','
                         || i_cust_pref_vendor|| ',' || i_zone
                         || ' ACTION ="SELECT",MESSAGE='
                         ||'"Unable to get count of slots ' ||
                         ' occupied by item in zone"';
            pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
      END;
   ELSE   /* max_slot_flag = 'A' */
     --Select all the aisles that match the required conditions of pallet type,
     --height slot,zone id and status

      FOR r_each_aisle IN c_each_aisle(lt_temp_height)
      LOOP
         lt_put_aisle        := r_each_aisle.put_aisle;
         lt_available_height := r_each_aisle.available_height;
         --for each aisle pick slot count
         SELECT COUNT(DISTINCT i.plogi_loc)
           INTO io_work_var_rec.n_slot_cnt
           FROM lzone lz, loc l, inv i
          WHERE   lz.logi_loc         = l.logi_loc
            AND   lz.zone_id          = i_zone
            AND   l.logi_loc          = i.plogi_loc
            AND   l.put_aisle         = lt_put_aisle
            AND   i.cust_pref_vendor  = i_cust_pref_vendor
            AND   i.prod_id           = i_prod_id;

         IF  (io_item_info_rec.n_max_slot > io_work_var_rec.n_slot_cnt) THEN

            lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                          'PO =' ||i_erm_id || '  ,item in  = ' ||
                          io_work_var_rec.n_slot_cnt ||
                          ' slots with max = ' || io_item_info_rec.n_max_slot
                          || ' on aisle ' || lt_put_aisle || ' in zone =  ' ||
                          i_zone || ' with location height = ' ||
                          lt_available_height ;
            pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

            --clear the array

            io_work_var_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
            io_work_var_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
            io_work_var_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
            io_work_var_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
            io_work_var_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
            io_work_var_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

            --reset the array count also
            ln_loop_cntr := 1;
            --reset the cursor count also
            ln_count := 0;
            BEGIN
               --fetch var in host arrays

               FOR r_aisle_open_slot IN c_aisle_open_slot(lt_available_height,
               lt_put_aisle)
               LOOP
                  --store everything in respective arrays
                  io_work_var_rec.gtbl_phys_loc(ln_loop_cntr)
                                       := r_aisle_open_slot.logi_loc;
                  io_work_var_rec.gtbl_loc_height(ln_loop_cntr)
                                       := r_aisle_open_slot.available_height;
                  io_work_var_rec.gtbl_put_aisle2(ln_loop_cntr)
                                       := r_aisle_open_slot.put_aisle;
                  io_work_var_rec.gtbl_put_slot2(ln_loop_cntr)
                                       := r_aisle_open_slot.put_slot;
                  io_work_var_rec.gtbl_put_level2(ln_loop_cntr)
                                       := r_aisle_open_slot.put_level;
                  io_work_var_rec.gtbl_put_path2(ln_loop_cntr)
                                       := r_aisle_open_slot.put_path;
                  --increment the array count
                  ln_loop_cntr := ln_loop_cntr+1;
                  --total no of rows retrieved
                  ln_count := c_aisle_open_slot%ROWCOUNT;
               END LOOP;
               IF    ln_count > 0 THEN
                  --this gives the no of slots
                  io_work_var_rec.n_total_cnt := ln_count;

                  lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                                'PO =' ||i_erm_id
                                || '  , number of open slots ' ||
                                ' found in aisle= '
                                || io_work_var_rec.n_total_cnt;

                  pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);


                  lb_status := f_open_slot_assign_loop(i_erm_id,
                                                       i_zone,
                                                       i_prod_id,
                                                       i_aging_days,
                                                       i_cust_pref_vendor,
                                                       io_work_var_rec,
                                                       io_item_info_rec,
                                                       io_syspar_var);

                  IF io_work_var_rec.b_revisit_open_slot THEN
                     lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                                   'PO =' ||i_erm_id
                                    || '  ,stop processing open slots on aisle='
                                    || lt_put_aisle
                                    || 'due to revisit_open_slot = Y ';
                     pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
                     RETURN FALSE;
                  END IF;
               ELSIF ln_count = 0 THEN
                  lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                                'PO =' ||i_erm_id
                                || '  ,TABLE = "inv,loc,lzone,slot_type,pm"
                                ,KEY = ' || i_prod_id || ',' ||
                                i_cust_pref_vendor || ',' || lt_put_aisle ||
                                ',' || i_zone || ' ,ACTION = "SELECT",MESSAGE = '
                                || ' "ORACLE No open slots in zone for aisle"';
                  pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
               END IF;
            EXCEPTION
               WHEN OTHERS THEN

                  lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                                'PO =' ||i_erm_id || '  ,TABLE = ' ||
                                ' "inv,loc,lzone,slot_type,pm"
                                ,KEY = ' || i_prod_id || ',' ||
                                i_cust_pref_vendor || ',' || lt_put_aisle ||
                                ',' || i_zone || ' ,ACTION = "SELECT", ' ||
                                ' MESSAGE = "ORACLE No open slots ' ||
                                ' in zone for aisle"';
                  pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
            END;
            IF lb_status THEN
               --ie all pallets has been putaway
               RETURN TRUE;
            END IF;
         END IF;/*Max slot > slot cnt */
      END LOOP; /* for each aisle*/
   END IF;     /* max slot flag*/
   RETURN lb_status;
EXCEPTION
   WHEN OTHERS THEN
      RAISE;
END f_check_open_slot;


   /*---------------------------------------------------------------------
   -- Function:
   --    Loop through all open slots and check if space is enough for a pallet
   --
   -- Description:
   -- Find open slot of the same aisle as putaway slot
   --
   -- Parameters:

   --      i_zone_id                one id for the product
   --      i_erm_id                 PO number
   --      i_prod_id                product id
   --      i_cust_pref_vendor       Cust pref vendor for the product
   --      i_aging_days             No of aging days for the product
   --      io_work_var_rec          Record type instance which has parameter
                                    like each pallet qty,last pallet qty etc
                                    set
   --      io_item_info_rec    Record type instance which has item related info
   --      io_syspar_var            Record type which has syspar flags set
   -- Return Values:
   --      lb_status
   --      Returns TRUE if all the pallets for the item were assigned
           a putaway slot.
   --      Returns FALSE if all the pallets for the item were NOT assigned
           a putaway slot.

   --
   -- Exceptions raised:
   ---------------------------------------------------------------------*/

   FUNCTION f_open_slot_assign_loop
           (i_erm_id           IN      erm.erm_id%type,
            i_zone_id          IN      zone.zone_id%type,
            i_prod_id          IN      pm.prod_id%type,
            i_aging_days       IN      aging_items.aging_days%type,
            i_cust_pref_vendor IN      pm.cust_pref_vendor%type,
            io_work_var_rec    IN OUT  pl_putaway_utilities.t_work_var,
            io_item_info_rec   IN      pl_putaway_utilities.t_item_related_info,
            io_syspar_var      IN      pl_putaway_utilities.t_syspar_var)
   RETURN BOOLEAN
   IS

   lv_fname          VARCHAR2(50):= 'f_open_slot_assign_loop';
   lv_msg_text       VARCHAR2(500);
   ln_index          NUMBER := 1;
   ln_pallet_count   NUMBER := 0;
   lt_location       loc.logi_loc%TYPE := ' ';
   BEGIN
      --reset the global variable
      pl_log.g_program_name     := 'PL_GENERAL_RULE';
      --This will be used in the Exception message in assign putaway
      pl_putaway_utilities.gv_program_name := lv_fname;

      WHILE ((io_item_info_rec.n_max_slot > io_work_var_rec.n_slot_cnt) AND
      (ln_index <= io_work_var_rec.n_total_cnt) AND
      (io_work_var_rec.n_current_pallet < io_work_var_rec.n_num_pallets))
      LOOP

         lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                      'PO =' ||i_erm_id || '  , Open Loop: loc= '
                      || io_work_var_rec.gtbl_phys_loc(ln_index)
                      || ',Slot Cnt = ' || io_work_var_rec.n_slot_cnt
                      || 'Current pallet = '
                      || io_work_var_rec.n_current_pallet || 'Pallet Cnt = '
                      || ln_pallet_count;

         pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

         IF  ((io_work_var_rec.gtbl_loc_height(ln_index)
                >= io_work_var_rec.n_home_slot_height)
            AND (io_item_info_rec.n_pallet_stack > ln_pallet_count))
         THEN

           /*lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                             'PO =' ||i_erm_id || '  , Open Loop: loc= '
                             || io_work_var_rec.gtbl_phys_loc(ln_index)
                             || ',Current pallet = ' || io_work_var_rec.n_current_pallet
                             || 'Number of pallets= '
                             || io_work_var_rec.n_num_pallets || 'Partial pallet flag = '
                      || io_work_var_rec.b_partial_pallet;
            lv_msg_text := lv_msg_text || 'Home slot flag= '
                           || io_work_var_rec.b_home_slot_flag || 'Temp loc is '
                           || lt_location || 'Dest loc is '
                           || io_work_var_rec.gtbl_phys_loc(ln_index);



            pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);*/

            IF ((io_work_var_rec.n_current_pallet =
                (io_work_var_rec.n_num_pallets - 1))
               AND io_work_var_rec.b_partial_pallet
               AND io_work_var_rec.b_home_slot_flag
               AND lt_location <> io_work_var_rec.gtbl_phys_loc(ln_index) ) THEN

               io_work_var_rec.b_revisit_open_slot := TRUE;
               --temp
               io_work_var_rec.n_each_pallet_qty := io_work_var_rec.
                                                    n_last_pallet_qty;

               RETURN FALSE;

            END IF;

            /*
            ** update tables
            */

            pl_putaway_utilities.p_insert_table
                                       (i_prod_id,
                                        i_cust_pref_vendor,
                                        io_work_var_rec.gtbl_phys_loc(ln_index),
                                        pl_putaway_utilities.ADD_RESERVE,
                                        i_erm_id,
                                        i_aging_days,
                                        io_syspar_var.v_clam_bed_tracked_flag,
                                        io_item_info_rec,
                                        io_work_var_rec);
            --reset the global variable
            pl_log.g_program_name     := 'PL_GENERAL_RULE';

            --copy the location
            --lt_location := io_work_var_rec.gtbl_loc_height(ln_index);
            lt_location := io_work_var_rec.gtbl_phys_loc(ln_index);


            --increment the current pallet
            io_work_var_rec.n_current_pallet := io_work_var_rec.n_current_pallet
                                                + 1;

            --check the current pallet is the last pallet or not
            IF io_work_var_rec.n_current_pallet = io_work_var_rec.n_num_pallets
                                                  -1
            THEN
               io_work_var_rec.n_each_pallet_qty := io_work_var_rec.
                                                    n_last_pallet_qty;
            END IF;
            --increment the pallet count
            ln_pallet_count := ln_pallet_count + 1;

            IF io_work_var_rec.n_current_pallet < io_work_var_rec.n_num_pallets
            THEN
               IF  (io_item_info_rec.n_stackable > 0) THEN
                  io_work_var_rec.gtbl_loc_height(ln_index) :=
                    io_work_var_rec.gtbl_loc_height(ln_index)
                     - io_work_var_rec.n_std_pallet_height;
               ELSE
                  io_work_var_rec.n_slot_cnt := io_work_var_rec.n_slot_cnt + 1;
                  ln_index := ln_index + 1;
                  ln_pallet_count := 0;
               END IF;
            END IF;
         ELSE
            io_work_var_rec.n_slot_cnt := io_work_var_rec.n_slot_cnt + 1;
            ln_index := ln_index + 1;
            ln_pallet_count := 0;
         END IF;
      END LOOP;/* WHILE INDEX<TOTAL CNT */

      IF io_work_var_rec.n_current_pallet >= io_work_var_rec.n_num_pallets THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
   WHEN OTHERS THEN
      RAISE;
      --ROLLBACK IN MAIN PACKAGE
   END f_open_slot_assign_loop;

   /* ************************************************************************
   -----------------------------------------------------------------------
   -- Function:
   --    f_Check_Home_Slot
   --
   -- Description:
   -- This method tries to find home slot as putaway slot.
   --
   -- Parameters:
   --
   --
   --  i_po_info_rec        Record type instance which has PO related info
   --  i_pm_category     category of product in product master
   --  i_prod_id            product id
   --  i_cust_pref_vendor   Cust pref vendor for the product
   --  i_aging_days         aging days needed for the item
   --  io_work_var_rec      Record type instance which has parameter like
   --                       each pallet qty,last pallet qty etc set
   --  io_item_info_rec     Record type instance which has item related info
   --  io_syspar_var        Record type which has syspar flags set
   --
   -- Return Values:
   --    Returns TRUE if all the pallets for
   --    the item were assigned a putaway slot.
   --    Returns FALSE if all the pallets for
   --    the item were NOT assigned a putaway slot.
   --
   --
   -- Exceptions raised:
   --
   --
   ---------------------------------------------------------------------
 **************************************************************************/

FUNCTION f_check_home_slot
      (i_po_info_rec               IN       pl_putaway_utilities.t_po_info,
       i_product_id                IN       pm.prod_id%type,
       i_pm_category               IN       pm.category%type,
       i_customer_preferred_vendor IN       pm.cust_pref_vendor%type,
       io_work_var_rec             IN OUT   pl_putaway_utilities.t_work_var,
       io_item_info_rec            IN       pl_putaway_utilities.
                                            t_item_related_info,
       i_aging_days                IN       aging_items.aging_days%TYPE,
       i_syspar_var_rec            IN       pl_putaway_utilities.t_syspar_var)

RETURN BOOLEAN
IS

lv_fname             VARCHAR2(20):= 'f_check_home_slot';
lv_msg_text          VARCHAR2(500);
lt_pallet_qty        io_work_var_rec.n_each_pallet_qty%TYPE;
lt_home_loc_height   loc.slot_height%TYPE;
lt_dest_loc          io_work_var_rec.v_dest_loc%TYPE;
ln_height_used       NUMBER := 0;
ln_qty_planned       NUMBER := 0;
ln_qoh               NUMBER := 0;
ln_fifo_item_qoh     NUMBER :=0;
ln_max_cases         NUMBER :=0;
ln_cur_num_cases     NUMBER :=0;
lb_status            BOOLEAN := FALSE;


BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_GENERAL_RULE';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;

   -- move Logical dest. location of the item to local variable
   lt_dest_loc:=io_work_var_rec.v_dest_loc;
   lt_home_loc_height:=io_work_var_rec.n_home_loc_height;

   BEGIN

      SELECT (CEIL(((qoh + qty_planned) / io_work_var_rec.v_no_splits)
                   /io_item_info_rec.n_ti) * io_item_info_rec.n_case_height),
      NVL(qty_planned, 0), NVL(qoh, 0)   -- Number of cases is total quantity
      INTO  ln_height_used, ln_qty_planned, ln_qoh  --  by number of splits.
      FROM  inv                       --   Multiplied by case height gives
      WHERE plogi_loc = lt_dest_loc;  --   height occupied by existing pallets

      --LOG THE SUCCESS MESSAGE
      lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id
                     || ' Home slot found';--if home slot found
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
   EXCEPTION
   WHEN OTHERS THEN
      lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id
                     || ' ORACLE unable to find home slot ' ||
                     ' inventory record for product.'
                     || i_product_id || 'and cpv '
                     || i_customer_preferred_vendor;
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
      BEGIN
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
                           exp_date)
                  VALUES ( i_product_id,
                           SYSDATE,
                           lt_dest_loc,
                           lt_dest_loc,
                           0, 0, 0, 0,
                           'AVL', 'A',
                           SYSDATE,
                           SYSDATE,
                           i_customer_preferred_vendor,
                           TRUNC(SYSDATE));

         lv_msg_text:= 'PO =' ||i_po_info_rec.v_erm_id
                       || ' ORACLE Inserted inv record for home slot for item.'
                       || i_product_id || 'and cpv '
                       || i_customer_preferred_vendor;
         pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
      EXCEPTION
      WHEN  OTHERS THEN
         lv_msg_text:= 'PO =' ||i_po_info_rec.v_erm_id
                       || ' Insertion into INVENTORY failed';
         pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
      END;/* Inventory insertion*/
   END;/* Home slot found*/



   -- process fifo tracked item
   IF  ((io_item_info_rec.v_fifo_trk = 'S') OR         -- If soft fifo
       (io_item_info_rec.v_fifo_trk = 'A')) THEN       -- or absolute fifo
      BEGIN
         ln_fifo_item_qoh := 0;
         SELECT NVL(SUM(i.qoh + i.qty_planned), 0)
           INTO ln_fifo_item_qoh
           FROM inv i
          WHERE i.cust_pref_vendor = i_customer_preferred_vendor
            AND i.prod_id = i_product_id;     -- Get fifo item quantity
         IF (ln_fifo_item_qoh > 0) THEN
            lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id ||
                         ' QOH exists for fifo item leaving home slot.';

            pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
            lb_status:=FALSE;
            RETURN lb_status;
         END IF;
     EXCEPTION
     WHEN OTHERS THEN
         lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id ||
                       ' ORACLE error on inv for fifo item leaving home slot.';

         pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
         lb_status:=FALSE;
         RETURN lb_status;
     END;
   END IF;
   IF  (((io_item_info_rec.v_lot_trk = 'Y') OR
       (io_item_info_rec.n_stackable = 0)) AND
       (ln_qoh + ln_qty_planned) > 0) THEN
      lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id
                     || ' QOH exists and either lot tracking or '
                     || ' non-stackable leaving home slot.';
      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
      lb_status := FALSE;
      RETURN lb_status;
   END IF;

   SELECT NVL(l.width_positions,1),NVL(s.deep_positions,1)
     INTO   io_work_var_rec.n_home_width_positions,
            io_work_var_rec.n_home_deep_positions
     FROM   loc l,slot_type s
    WHERE  l.slot_type        = s.slot_type
      AND  l.logi_loc         = lt_dest_loc;

   -- Add skid_height to height_used for home slot.
   -- Add skid_height per number of positions of home slot.

   IF  ((io_work_var_rec.v_deep_ind = 'Y')
       AND (io_work_var_rec.n_home_deep_positions >= 0)
       AND (io_work_var_rec.n_home_deep_positions <= 9)) THEN

       ln_height_used := ln_height_used + io_item_info_rec.n_skid_height
                                       * io_work_var_rec.n_home_deep_positions;
   ELSE
       ln_height_used := ln_height_used + io_item_info_rec.n_skid_height;
   END IF;


   IF  ((ln_qoh = 0) and (ln_qty_planned = 0)) THEN   /* home slot empty */

      io_work_var_rec.b_first_home_assign := TRUE;

      -- Check if full pallet and since home slot is empty
      -- put the pallet in - don't check the location height

      IF  (NOT io_work_var_rec.b_partial_pallet ) THEN

         -- Update qty_planned for this prod_id on inv */
         pl_putaway_utilities.p_Insert_table
                              (i_product_id,
                               i_customer_preferred_vendor,
                               io_work_var_rec.v_dest_loc,
                               pl_putaway_utilities.ADD_HOME,
                               i_po_info_rec.v_erm_id,
                               i_aging_days,
                               i_syspar_var_rec.v_clam_bed_tracked_flag,
                               io_item_info_rec ,
                               io_work_var_rec);
         --reset the global variable
         pl_log.g_program_name     := 'PL_GENERAL_RULE';

         io_work_var_rec.n_current_pallet:=io_work_var_rec.n_current_pallet+1;


         ln_height_used := ln_height_used+ (CEIL(io_work_var_rec.
                                                 n_each_pallet_qty
                                                 /io_item_info_rec.n_ti)
                                            * io_item_info_rec.n_case_height);
         --increment qty planned
         ln_qty_planned := ln_qty_planned + ((io_work_var_rec.n_each_pallet_qty)
                                              *(io_work_var_rec.v_no_splits));
         io_work_var_rec.b_first_home_assign := FALSE;
      END IF;
   ELSE
     io_work_var_rec.b_first_home_assign := FALSE;
   END IF;
   --log the values of the flags
   lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id
                  || ' FP flag value is : '
                  ||io_item_info_rec.v_fp_flag
                  ||'and PP flag value is: '||io_item_info_rec.v_pp_flag
                  ||'and THRESHOLD flag value is: '
                  ||io_item_info_rec.v_threshold_flag;

   pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
   --for full pallets
   --fp flag set then putaway should be based on minimum qty

   -- Calculate the maximum  no of cases that can go into home slot

   ln_max_cases := (FLOOR((lt_home_loc_height - io_item_info_rec.n_skid_height)
                      /io_item_info_rec.n_case_height) * io_item_info_rec.n_ti
                      * io_work_var_rec.n_home_width_positions
                      * io_work_var_rec.n_home_deep_positions) ;

   -- Calculate the current no of cases present in the home slot
   ln_cur_num_cases := (FLOOR(ln_qoh + ln_qty_planned)
                                   / io_work_var_rec.v_no_splits );


   -- Check if space is enough to hold the putaway qty
   -- Put partial pallet first

   IF  io_work_var_rec.b_partial_pallet THEN
      --check for max qty

      lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id
                        || ' qoh value is : '
                        ||ln_qoh
                        ||'and qty planned value is: '||ln_qty_planned
                        ||'and max_qty value in cases is: '
                        ||io_item_info_rec.n_max_qty
                        ||'and max_qty value in splits is: '
                        ||(io_item_info_rec.n_max_qty)
                                          *(io_work_var_rec.v_no_splits);

      pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);



      IF  io_item_info_rec.v_threshold_flag = 'Y' THEN
       IF (ln_qoh + ln_qty_planned) < ((io_item_info_rec.n_max_qty)
                                          *(io_work_var_rec.v_no_splits)) THEN

         lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id
                       || ' Partial Pallet sent to home slot.';
         pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

         io_work_var_rec.b_partial_pallet := FALSE;

         lt_pallet_qty := io_work_var_rec.n_each_pallet_qty;
         io_work_var_rec.n_each_pallet_qty := io_work_var_rec.n_last_pallet_qty;


         --increment the height used
         ln_height_used := ln_height_used+ (CEIL(io_work_var_rec.
                                                n_each_pallet_qty
                                                /io_item_info_rec.n_ti)
                                            * io_item_info_rec.n_case_height);
         --increment qty planned
         ln_qty_planned := ln_qty_planned +((io_work_var_rec.n_each_pallet_qty)
                                               *(io_work_var_rec.v_no_splits));
         pl_putaway_utilities.p_Insert_table
                               (i_product_id,
                                i_customer_preferred_vendor,
                                io_work_var_rec.v_dest_loc,
                                pl_putaway_utilities.ADD_HOME,
                                i_po_info_rec.v_erm_id,
                                i_aging_days,
                                i_syspar_var_rec.v_clam_bed_tracked_flag,
                                io_item_info_rec,io_work_var_rec);
         --reset the global variable
         pl_log.g_program_name     := 'PL_GENERAL_RULE';
         io_work_var_rec.n_current_pallet  :=io_work_var_rec.n_current_pallet+1;
         io_work_var_rec.n_each_pallet_qty := lt_pallet_qty;

         -- Reset last_pallet_qty because partial is no more.
         io_work_var_rec.n_last_pallet_qty := lt_pallet_qty;

        END IF;/*Max_qty check */

         --ELSE CHECK FOR THE HEIGHT
         --ELSIF ((lt_home_loc_height - ln_height_used) >=
         --      (CEIL(io_work_var_rec.n_last_pallet_qty/io_item_info_rec.n_ti)
         --            * io_item_info_rec.n_case_height)) THEN

      --ELSE CHECK FOR THE NUMBER OF CASES

      ELSIF ((ln_max_cases - ln_cur_num_cases)
                          >= io_work_var_rec.n_last_pallet_qty ) THEN
         lv_msg_text := 'PO =' ||i_po_info_rec.v_erm_id
                        || ' Partial pallet sent to home slot.';
         pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

         io_work_var_rec.b_partial_pallet := FALSE;
         lt_pallet_qty := io_work_var_rec.n_each_pallet_qty;
         io_work_var_rec.n_each_pallet_qty :=io_work_var_rec.n_last_pallet_qty;
         --increment qty planned
         ln_qty_planned :=ln_qty_planned +((io_work_var_rec.n_each_pallet_qty)
                                             *(io_work_var_rec.v_no_splits));

         --ln_height_used := ln_height_used
         --                          + (CEIL(io_work_var_rec.n_last_pallet_qty
         --                                      /io_item_info_rec.n_ti)
         --                                 * io_item_info_rec.n_case_height);

         pl_putaway_utilities.p_Insert_table
                              (i_product_id,
                               i_customer_preferred_vendor,
                               io_work_var_rec.v_dest_loc,
                               pl_putaway_utilities.ADD_HOME,
                               i_po_info_rec.v_erm_id,
                               i_aging_days,
                               i_syspar_var_rec.v_clam_bed_tracked_flag,
                               io_item_info_rec,io_work_var_rec);
         --reset the global variable
         pl_log.g_program_name     := 'PL_GENERAL_RULE';

         io_work_var_rec.n_current_pallet :=io_work_var_rec.n_current_pallet+1;
         io_work_var_rec.n_each_pallet_qty := lt_pallet_qty;

         -- Reset last_pallet_qty because partial is no more.
         io_work_var_rec.n_last_pallet_qty := lt_pallet_qty;

      END IF;
   END IF;/*partial pallet check*/

   -- Reclculating the height after partial pallet and min qty putaway
   ln_height_used := (CEIL(((ln_qoh + ln_qty_planned)
                                        / io_work_var_rec.v_no_splits)
                     /io_item_info_rec.n_ti) * io_item_info_rec.n_case_height);

   --for full pallets
   --fp flag set then putaway should be based on maximum qty
   IF NOT(io_work_var_rec.n_current_pallet=io_work_var_rec.n_num_pallets-1
   AND io_work_var_rec.b_partial_pallet) THEN

      -- Check If item is stackable - stack more product on top of the first
      -- pallet if there is height available.
      IF  (io_item_info_rec.n_stackable > 0) THEN

         IF io_item_info_rec.v_threshold_flag = 'Y' THEN

         --Perform the check for max quantity

            WHILE (ln_qoh + ln_qty_planned) < ((io_item_info_rec.n_max_qty)
                                               *(io_work_var_rec.v_no_splits))
            AND (io_work_var_rec.n_current_pallet < io_work_var_rec.n_num_pallets)
            LOOP

               --Update tables

               pl_putaway_utilities.p_Insert_table
                                   (i_product_id,
                                    i_customer_preferred_vendor,
                                    io_work_var_rec.v_dest_loc,
                                    pl_putaway_utilities.ADD_HOME,
                                    i_po_info_rec.v_erm_id,
                                    i_aging_days,
                                    i_syspar_var_rec.v_clam_bed_tracked_flag,
                                    io_item_info_rec,
                                    io_work_var_rec);
               --reset the global variable
               pl_log.g_program_name     := 'PL_GENERAL_RULE';

               io_work_var_rec.n_current_pallet:=io_work_var_rec.n_current_pallet
                                                 +1;

               ln_height_used := ln_height_used+ (CEIL(io_work_var_rec.
                                                       n_each_pallet_qty
                                                       /io_item_info_rec.n_ti)
                                                     * io_item_info_rec.
                                                     n_case_height);
               --increment planned qty
               ln_qty_planned := ln_qty_planned + ((io_work_var_rec.
                                                    n_each_pallet_qty)
                                                    *(io_work_var_rec.
                                                     v_no_splits));
            END LOOP;

         ELSE
         --DO THE HEIGHT CHECK
            WHILE (((lt_home_loc_height - ln_height_used)
                   >= (CEIL(io_work_var_rec.n_each_pallet_qty
                           /io_item_info_rec.n_ti)
                        * io_item_info_rec.n_case_height))
                 AND (io_work_var_rec.n_current_pallet
                      < io_work_var_rec.n_num_pallets))
            LOOP
               --  Update qty_planned for this prod_id on inv
               pl_putaway_utilities.p_Insert_table
                                    (i_product_id,
                                     i_customer_preferred_vendor,
                                     io_work_var_rec.v_dest_loc,
                                     pl_putaway_utilities.ADD_HOME,
                                     i_po_info_rec.v_erm_id,
                                     i_aging_days,
                                     i_syspar_var_rec.v_clam_bed_tracked_flag,
                                     io_item_info_rec,
                                     io_work_var_rec);
               --reset the global variable
               pl_log.g_program_name     := 'PL_GENERAL_RULE';
               io_work_var_rec.n_current_pallet:=io_work_var_rec.n_current_pallet
                                                 +1;
               ln_height_used := ln_height_used + (CEIL(io_work_var_rec.
                                                        n_each_pallet_qty
                                                        /io_item_info_rec.n_ti)
                                                   * io_item_info_rec.
                                                    n_case_height);
            END LOOP;
         END IF;/*FP FLAG AND THRESHOLD FLAG*/
      END IF;/*FP FLAG AND STACKABLE FLAG*/
   END IF;    /*FULL PALLET*/

   IF  (io_work_var_rec.n_current_pallet >= io_work_var_rec.n_num_pallets) THEN
   lb_status:=TRUE;
   ELSE
   lb_status:=FALSE;
   END IF;

   RETURN lb_status;

END f_check_home_slot;


BEGIN
  --this is used for initialising global variables once
  --global variables set for logging the errors in swms_log table

     pl_log.g_application_func := 'RECEIVING AND PUTAWAY';

END pl_general_rule;

/

