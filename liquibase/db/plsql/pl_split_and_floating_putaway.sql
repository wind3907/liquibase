--PACKAGE SPEC
PROMPT Creating package PL_SPLIT_AND_FLOATING_PUTAWAY ..
CREATE OR REPLACE PACKAGE swms.pl_split_and_floating_putaway
AS
/*   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_split_and_floating_putaway
   --
   -- Description:
   --    This package will be used to putaway items that arrive in splits
   --    and items that are floating items.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/04/02          Initial Version
   ---------------------------------------------------------------------------*/


        FUNCTION f_split_find_putaway_slot
                (i_po_info_rec        IN     pl_putaway_utilities.t_po_info,
                 i_prod_id            IN     pm.prod_id%TYPE,
                 i_cust_pref_vendor   IN     pm.cust_pref_vendor%TYPE,
                 i_aging_days         IN     aging_items.aging_days%TYPE,
                 i_total_qty          IN     erd.qty%TYPE,
                 i_item_info_rec      IN pl_putaway_utilities.t_item_related_info,
                 io_workvar_rec       IN OUT pl_putaway_utilities.t_work_var,
                 i_syspar_var_rec     IN     pl_putaway_utilities.t_syspar_var)
        RETURN BOOLEAN;

        FUNCTION f_split_check_float_item
              (i_aging_days       IN  aging_items.aging_days%TYPE,
               i_prod_id          IN  pm.prod_id%TYPE,
               i_cust_pref_vendor IN  pm.cust_pref_vendor%TYPE,
               i_item_info_rec    IN  pl_putaway_utilities.t_item_related_info)

        RETURN  BOOLEAN;

        FUNCTION f_split_putaway
             (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
              i_prod_id                   IN     pm.prod_id%TYPE,
              i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
              i_aging_days                IN     NUMBER,
              i_total_qty                 IN     erd.qty%TYPE,
              i_item_info_rec             IN     pl_putaway_utilities.
                                                 t_item_related_info,
              io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
              i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)
       RETURN BOOLEAN;

       PROCEDURE p_split_insert_table
            (i_prod_id            IN      pm.prod_id%TYPE,
             i_cust_pref_vendor   IN      pm.cust_pref_vendor%TYPE,
             i_total_qty          IN      erd.qty%TYPE,
             i_dest_loc           IN      loc.logi_loc%TYPE,
             i_home               IN      INTEGER,
             i_erm_id             IN      erm.erm_id%TYPE,
             i_aging_days         IN      aging_items.aging_days%TYPE,
             i_clam_bed_flag      IN      sys_config.config_flag_val%TYPE,
             i_item_info_rec      IN  pl_putaway_utilities.t_item_related_info,
             io_workvar_rec       IN OUT  pl_putaway_utilities.t_work_var);

       FUNCTION f_split_floating_rule
           (i_po_info_rec      IN     pl_putaway_utilities.T_PO_INFO,
            i_prod_id          IN     pm.prod_id%TYPE,
            i_cust_pref_vendor IN     pm.cust_pref_vendor%TYPE,
            i_zone_id          IN     zone.zone_id%TYPE,
            i_aging_days       IN     aging_items.aging_days%TYPE,
            i_total_qty        IN     erd.qty%TYPE,
            i_item_info_rec    IN     pl_putaway_utilities.t_item_related_info,
            io_workvar_rec     IN OUT pl_putaway_utilities.t_work_var,
            i_syspar_var_rec   IN     pl_putaway_utilities.t_syspar_var)
      RETURN  BOOLEAN;

      FUNCTION f_split_floating_open_assign
          (i_po_info_rec      IN     pl_putaway_utilities.t_po_info,
           i_prod_id          IN     pm.prod_id%TYPE,
           i_cust_pref_vendor IN     pm.cust_pref_vendor%TYPE,
           i_zone_id          IN     zone.zone_id%TYPE,
           i_aging_days       IN     aging_items.aging_days%TYPE,
           i_total_qty        IN     erd.qty%TYPE,
           i_item_info_rec    IN     pl_putaway_utilities.t_item_related_info,
           io_workvar_rec     IN OUT pl_putaway_utilities.t_work_var,
           i_syspar_var_rec   IN     pl_putaway_utilities.t_syspar_var)
      RETURN  BOOLEAN;

FUNCTION f_floating_item_putaway
  (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
   i_product_id                IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
   i_zone_id                   IN     zone.zone_id%TYPE)
RETURN BOOLEAN;

FUNCTION f_floating_item_open_assign
  (i_po_info_rec               IN     pl_putaway_utilities.T_PO_INFO,
   i_product_id                IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var,
   i_zone_id                   IN     zone.zone_id%TYPE)
RETURN BOOLEAN;

END pl_split_and_floating_putaway;
/
--------------------------------------------------------------------------------------------
--PACKAGE BODY

CREATE OR REPLACE PACKAGE BODY swms.pl_split_and_floating_putaway
IS

FUNCTION f_split_find_putaway_slot
  (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
   i_prod_id                   IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_total_qty                 IN     erd.qty%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)
RETURN BOOLEAN
IS

/*-----------------------------------------------------------------------
-- Function:
--    f_split_find_putaway_slot
--
-- Description:
-- This method finds putaway slot for one split item in the PO
-- Parameters:
--    i_po_info_rec               - relevant details of PO are passed thru this
                                    record
--    i_prod   _id                - product id of the item for which details
                                    are fetched
--    i_cust_pref_vendor          - customer preferred vendor for the selected
                                    product
--    i_aging_days                - aging days for the item, -1 if no aging
                                    required
--    i_item_info_rec             - all information pertaining to the product
                                    type is passed using this record
--    io_workvar_rec              - all global variables,global array used
                                    for processing are stored in this record.
--    i_syspar_var_rec            - all the system parameters are passed
                                    using this record

--  Return Values:
      --TRUE  - All the pallets for the item were assigned a putaway slot.
      --FALSE - All the pallets for the item were not assigned a putaway slot.
---------------------------------------------------------------------*/


   lv_msg_text          VARCHAR2(500);
   lv_fname             VARCHAR2(50) := 'f_split_find_putaway_slot';
   lv_result            VARCHAR2(100);

   lt_pallet_id        putawaylst.pallet_id%TYPE;

   ln_rule_id          zone.rule_id%TYPE;

   lb_done             BOOLEAN:=FALSE;
   


   CURSOR c_split_each_zone
   IS
   SELECT next_zone_id
     FROM next_zones
    WHERE zone_id = i_item_info_rec.v_zone_id
    ORDER BY sort;


BEGIN
  --reset the global variable
  pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
  
  --This will be used in the Exception message in assign putaway
  pl_putaway_utilities.gv_program_name := lv_fname;

   /* Check and see if this is float item */

  IF f_split_check_float_item(i_aging_days,
                              i_prod_id,
                              i_cust_pref_vendor,
                              i_item_info_rec) THEN


    --  call f_split_floating_rule
    --This function assigns slots to floating split items.
    lb_done := f_split_floating_rule(i_po_info_rec,
                                     i_prod_id,
                                     i_cust_pref_vendor,
                                     i_item_info_rec.v_zone_id,
                                     i_aging_days,
                                     i_total_qty,
                                     i_item_info_rec,
                                     io_workvar_rec,
                                     i_syspar_var_rec);
    --log the message
       IF lb_done THEN
          lv_result := 'All  splits  have been putaway';
       ELSE
          lv_result := 'All  splits could not be putaway';
       END IF;

       lv_msg_text :='PO: ' || i_po_info_rec.v_erm_id
                     ||'Returned from split floating rule for item '
                     ||i_prod_id ||',cpv ' || i_cust_pref_vendor
                     ||' and ' || lv_result;

       pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

       IF NOT lb_done THEN
          /*If all the pallets have not yet been putaway,
          find next zone to putaway*/
          FOR r_split_each_zone  IN c_split_each_zone
          LOOP
              lv_msg_text := 'NEXT ZONE ' || r_split_each_zone.next_zone_id;

              pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
              --pick the rule id for this zone
             BEGIN
              SELECT rule_id INTO ln_rule_id
              FROM zone
              WHERE zone_id = r_split_each_zone.next_zone_id;
             EXCEPTION
              WHEN NO_DATA_FOUND THEN
                 ln_rule_id := NULL;
             END;
             IF ln_rule_id = 1 OR i_aging_days > 0  THEN
                 -- Use floating rule 
                 lv_msg_text := 'Floating rule second time.';
                 pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
                --call floating rule and pass the zone id obtained .
                 lb_done := f_split_floating_rule(i_po_info_rec,
                                                  i_prod_id,
                                                  i_cust_pref_vendor,
                                                 r_split_each_zone.next_zone_id,
                                                  i_aging_days,
                                                  i_total_qty,
                                                  i_item_info_rec,
                                                  io_workvar_rec,
                                                  i_syspar_var_rec);

                 IF lb_done THEN
                    lv_result := 'All  splits  have been putaway';
                 ELSE
                    lv_result := 'All  splits could not be putaway';
                 END IF;

                lv_msg_text := 'PO: ' || i_po_info_rec.v_erm_id
                               ||'Returned from split floating rule for item '
                               ||i_prod_id ||',cpv ' || i_cust_pref_vendor
                               ||' and ' || lv_result;
                pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

              END IF;--rule id = 1
              EXIT WHEN lb_done;
          END LOOP;
       END IF;--lb_done=FALSE



       --     ** There is no floating slot for the product,
       --     ** set the dest_loc = "*".

       IF NOT lb_done THEN
         --call split insert table
         --and create putawaylst record with dest loc as '*'
         p_split_insert_table (i_prod_id,
                               i_cust_pref_vendor,
                               i_total_qty,
                               '*',
                               pl_putaway_utilities.ADD_NO_INV,
                               i_po_info_rec.v_erm_id,
                               i_aging_days,
                               i_syspar_var_rec.v_clam_bed_tracked_flag,
                               i_item_info_rec,
                               io_workvar_rec);
       END IF;--NOT DONE
   ELSE   -- item is not a floating item

         lb_done := f_split_putaway(i_po_info_rec,
                                    i_prod_id,
                                    i_cust_pref_vendor,
                                    i_aging_days,
                                    i_total_qty,
                                    i_item_info_rec,
                                    io_workvar_rec,
                                    i_syspar_var_rec);
         IF lb_done THEN
            lv_result := 'All  splits  have been putaway';
         ELSE
            lv_result := 'All  splits could not be putaway';
         END IF;

         lv_msg_text := 'PO: ' || i_po_info_rec.v_erm_id
                     ||'Returned from split putaway for item '
                     ||i_prod_id ||',cpv ' || i_cust_pref_vendor
                     ||' and ' || lv_result;

         pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

   END IF;/* item is floating/non-floating item*/

    RETURN lb_done;
EXCEPTION
   WHEN OTHERS THEN
       IF pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.SUCCESS THEN
        pl_putaway_utilities.gv_crt_message := 'ERROR:';
        pl_putaway_utilities.gv_crt_message := RPAD(pl_putaway_utilities.
                                                    gv_crt_message,80)
                                               || 'REASON: ERROR IN : '
                                               || pl_putaway_utilities.
                                                  gv_program_name 
                                               || ' ,MESSAGE : '
                                               || sqlcode || sqlerrm;
    END IF;
       RAISE;
END f_split_find_putaway_slot;


-------------------------------------------------------------------------------
FUNCTION f_split_check_float_item
         (i_aging_days        IN  aging_items.aging_days%TYPE,
          i_prod_id           IN  pm.prod_id%TYPE,
          i_cust_pref_vendor  IN  pm.cust_pref_vendor%TYPE,
          i_item_info_rec     IN  pl_putaway_utilities.t_item_related_info)

RETURN  BOOLEAN
IS

/*****************************************************************************
**  FUNCTION:
**      f_split_check_float_item
**  DESCRIPTION:
**      This function determines if a split item on the PO is a floating item.
**  PARAMETERS:
**      i_aging_days - No of item aging days
**  RETURN VALUES:
**      TRUE  - The item is a floating item.  It has no split home and the
**              rule id is 1.
**            - For aging item, don't put into home slot.
**      FALSE - The item is not a floating item.
*****************************************************************************/

lb_float_item   BOOLEAN:=FALSE;
lt_logi_loc     loc.logi_loc%TYPE;
ln_rule_id      zone.rule_id%TYPE;
lv_fname        VARCHAR2(50):='f_split_check_float_item';
BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
    --This will be used in the Exception message in assign putaway
    pl_putaway_utilities.gv_program_name := lv_fname;
   
    /* Check if the item has a split home. */

    BEGIN
       SELECT l.logi_loc INTO lt_logi_loc
         FROM loc l
        WHERE l.uom IN (0, 1)
          AND l.perm='Y'
          AND l.rank=1
          AND l.cust_pref_vendor = i_cust_pref_vendor
          AND l.prod_id = i_prod_id ;

    EXCEPTION
     WHEN NO_DATA_FOUND THEN
       lt_logi_loc := NULL;
    END;

    IF i_aging_days > 0 THEN
       lb_float_item := TRUE;
    ELSIF SQL%FOUND THEN
       /*Item has no aging days and has split home slot, so it is not a
        floating item.*/
       lb_float_item := FALSE;
    ELSIF SQL%NOTFOUND THEN
       /*The item does not have a split home.  It the item has a zone
       and a last ship slot then get the rule id for this combination.
       If the item has only a zone,get the rule id for the zone.*/

       IF i_item_info_rec.v_zone_id IS NOT NULL THEN
          IF i_item_info_rec.v_last_ship_slot IS NOT NULL THEN
             --Get the rule id for the zone and the last ship slot combination.
            BEGIN
               SELECT rule_id INTO ln_rule_id
                 FROM zone z, lzone lz
                WHERE z.zone_id = lz.zone_id
                  AND lz.zone_id  = i_item_info_rec.v_zone_id
                  AND lz.logi_loc = i_item_info_rec.v_last_ship_slot;
            EXCEPTION
             WHEN NO_DATA_FOUND THEN
              ln_rule_id := NULL;
            END;
          ELSE
            --The item had no last ship slot, get the rule id for the zone.
            BEGIN
             SELECT rule_id INTO ln_rule_id
               FROM zone
              WHERE zone_id = i_item_info_rec.v_zone_id;
            EXCEPTION
             WHEN NO_DATA_FOUND THEN
              ln_rule_id := NULL;
            END;
          END IF;
       END IF;/*ZONE ID IS NOT NULL*/

        --Determine if the item is a floating item.
        IF  (ln_rule_id = 1) AND (SQL%FOUND) THEN
            lb_float_item := TRUE;
        ELSE
            lb_float_item := FALSE;
        END IF;

    END IF;/* AGING DAYS*/

    RETURN lb_float_item;
EXCEPTION
   WHEN OTHERS THEN
       pl_putaway_utilities.gv_crt_message := 'ERROR:Failed to check '
                                             ||'whether item is floating'
                                             ||'or not ';
       pl_putaway_utilities.gv_crt_message :=
                RPAD(pl_putaway_utilities.gv_crt_message,80)
                || 'REASON: ERROR IN : '
                || pl_putaway_utilities.gv_program_name 
                || ' ,MESSAGE : ' || sqlcode || sqlerrm;
      RAISE;
      --ROLLBACK IN THE MAIN PACKAGE
END f_split_check_float_item;
-------------------------------------------------------------------------------------------

PROCEDURE p_split_insert_table
        (i_prod_id            IN      pm.prod_id%TYPE,
         i_cust_pref_vendor   IN      pm.cust_pref_vendor%TYPE,
         i_total_qty          IN      erd.qty%TYPE,
         i_dest_loc           IN      loc.logi_loc%TYPE,
         i_home               IN      INTEGER,
         i_erm_id             IN      erm.erm_id%TYPE,
         i_aging_days         IN      aging_items.aging_days%TYPE,
         i_clam_bed_flag      IN      sys_config.config_flag_val%TYPE,
         i_item_info_rec      IN      pl_putaway_utilities.t_item_related_info,
         io_workvar_rec       IN OUT  pl_putaway_utilities.t_work_var)

IS
   lt_pallet_id     putawaylst.pallet_id%TYPE;
   ln_status        NUMBER;
   lv_clam_bed_trk   VARCHAR2(1);
   lv_msg_text       VARCHAR2(500);
   lv_pname          VARCHAR2(50)  := 'p_split_insert_table';
   lv_tmp_check      VARCHAR2(1);


   e_pallet_id      EXCEPTION;
   e_inv_update     EXCEPTION;
   lv_error_text     VARCHAR2(500);
   lv_flag           VARCHAR2(1);

BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_pname;
   
   --call the procedure to get the unique pallet id

   pl_common.p_get_unique_lp(lt_pallet_id,
                             ln_status);


   IF ln_status = 0 AND lt_pallet_id IS NOT NULL THEN

      --increment the sequence

     io_workvar_rec.n_seq_no := io_workvar_rec.n_seq_no + 1;


      IF i_home = pl_putaway_utilities.ADD_HOME THEN

        BEGIN

           UPDATE inv
              SET qty_planned = qty_planned + i_total_qty,
                  cube        = NVL(cube, 0) + (i_total_qty
                                             / i_item_info_rec.n_spc)
                                            * i_item_info_rec.n_case_cube
            WHERE cust_pref_vendor = i_cust_pref_vendor
              AND prod_id            = i_prod_id
              AND plogi_loc          = i_dest_loc;

           IF SQL%FOUND THEN
              --LOG THE SUCCESS MESSAGE
              lv_msg_text := 'ORACLE inventory updated for PO: '
                            || i_erm_id || 'Product Id is '
                            || i_prod_id;

              pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);
           ELSE
              --LOG THE ERROR MESSAGE
              lv_msg_text := 'ORACLE unable to update inventory record for PO: '
                            || i_erm_id || 'Product Id is '
                            || i_prod_id;

              pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

              RAISE e_inv_update;
           END IF;
        EXCEPTION
         WHEN e_inv_update THEN
           lv_error_text := sqlcode || sqlerrm;

           pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
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

           lv_msg_text := 'PO Number: ' || i_erm_id
                         ||'UPDATE OF INVENTORY DEST LOC '
                         || i_dest_loc || ', PROD ID '
                         ||i_prod_id || ', CPV ' || i_cust_pref_vendor
                         || ' FAILED. ';

           pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

           lv_error_text := sqlcode || sqlerrm;

           pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
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

      ELSIF i_home = pl_putaway_utilities.ADD_RESERVE THEN
      --insert record into reserve inventory
         BEGIN

            INSERT INTO inv (plogi_loc,
                             logi_loc,
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
                             exp_date)
                      VALUES(i_dest_loc,
                             lt_pallet_id,
                             i_prod_id,
                             i_erm_id,
                             i_total_qty,
                             0,0,0, SYSDATE,SYSDATE,
                             i_item_info_rec.v_abc,
                             DECODE(i_aging_days, -1, 'AVL', 'HLD'),
                             SYSDATE,
                             DECODE(SIGN(99999.99
                                         -(i_total_qty
                                           + i_item_info_rec.n_skid_cube)),
                                    -1, 99999.99,
                                    (i_total_qty + i_item_info_rec.n_skid_cube)),
                             SYSDATE,
                             i_cust_pref_vendor,
                             trunc(SYSDATE));


         lv_msg_text:='ORACLE inventory created for PO : ' || i_erm_id
                      || ',Prod Id : ' || i_prod_id
                      ||' And Location identified is : ' || i_dest_loc;

         pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

      EXCEPTION
      WHEN OTHERS THEN


         lv_msg_text := 'PO Number: ' || i_erm_id
                      ||'INSERT OF INVENTORY DEST LOC ' || i_dest_loc
                      || ', PROD ID ' ||i_prod_id || ', CPV '
                      || i_cust_pref_vendor || ' FAILED. ';

         pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

         lv_error_text := sqlcode || sqlerrm;

         pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
                                                || i_erm_id;
         pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to insert into inventory for pallet_id  '
               || lt_pallet_id || ' and prod id '
               || i_prod_id ||' cpv '
               || i_cust_pref_vendor ||
               ' - sqlcode= ' ||
               lv_error_text;
         RAISE;

      END;

   END IF;  /*ADD HOME*/

  --Create Putawaylst record.

      IF pl_putaway_utilities.f_is_clam_bed_tracked_item
         (i_item_info_rec.v_category,i_clam_bed_flag) THEN
         lv_clam_bed_trk := 'Y';
      ELSE
         lv_clam_bed_trk := 'N';
      END IF;

      --insert record in putawaylst table
      BEGIN
         INSERT INTO putawaylst(rec_id,
                                prod_id,
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
                                cust_pref_vendor,
                                exp_date,
                                clam_bed_trk)
                        VALUES (i_erm_id,
                                i_prod_id,
                                i_dest_loc,
                                i_total_qty,
                                1,'NEW',
                                DECODE(i_aging_days, -1, 'AVL', 'HLD'),
                                lt_pallet_id,
                                i_total_qty,
                                i_total_qty,
                                i_item_info_rec.v_temp_trk,
                                i_item_info_rec.v_catch_wt_trk,
                                i_item_info_rec.v_lot_trk,
                                i_item_info_rec.v_exp_date_trk,
                                i_item_info_rec.v_date_code,
                                ' ',' ',
                                io_workvar_rec.n_seq_no,
                                'N',
                                i_cust_pref_vendor,
                                TRUNC(SYSDATE),
                                lv_clam_bed_trk);

         lv_msg_text:=pl_putaway_utilities.PROGRAM_CODE ||
                ' Insert into Putawaylst PO Number :' || i_erm_id
                || ' Product Id : ' || i_prod_id
                || ' CPV : ' || i_cust_pref_vendor
                || ' Location : ' || i_dest_loc
                || ' Quantity in Cases : '
                || io_workvar_rec.n_each_pallet_qty
                || ' Pallet Id : ' || lt_pallet_id;

         pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm); 
      
      EXCEPTION
       WHEN OTHERS THEN
          lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||' PO Number: '||i_erm_id||
                      ' TABLE=PUTAWAYLST,KEY= ' || lt_pallet_id ||
                      ',' || i_erm_id || ',' || i_prod_id ||
                      ',' || i_cust_pref_vendor || ' ACTION = INSERT, ' ||
                      ' ORACLE unable to create putaway record for pallet';
          pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

          lv_error_text := sqlcode || sqlerrm;

          pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
                                                 || i_erm_id;
          pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to insert into putawaylst for pallet_id  '
               || lt_pallet_id
               ||' - sqlcode= ' ||
               lv_error_text;
          RAISE;
      END;

      --for catch weight

      IF i_item_info_rec.v_catch_wt_trk = 'Y' THEN
         BEGIN
            SELECT 'X' into lv_tmp_check
              FROM  tmp_weight
             WHERE erm_id             = i_erm_id
               AND   prod_id            = i_prod_id
               AND   cust_pref_vendor   = i_cust_pref_vendor;
         EXCEPTION
          WHEN NO_DATA_FOUND THEN
            --LOG THE ERROR
            lv_msg_text:='Selection of tmp_weight failed for PO: '
                        || i_erm_id || ' Prod Id: '
                        || i_prod_id;

            pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

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
                                      0,0,0);

            EXCEPTION
             WHEN OTHERS THEN
                --LOG THE MESSAGE
               lv_msg_text:= 'Insertion into tmp_weight failed for PO: '
                            || i_erm_id || ' Prod Id: '
                            || i_prod_id;

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);


            END;
          END;
      END IF;/*catch wt trk */

      --REPROCESS processing
      IF pl_putaway_utilities.gb_reprocess = TRUE THEN

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
                             'DLP',
                             i_erm_id,
                             SYSDATE,
                             USER,
                             lt_pallet_id,
                             i_total_qty,
                             i_prod_id,
                             i_cust_pref_vendor,
                             1,
                             TRUNC(SYSDATE));

       --store new pallet ids in array
       --These array values will be used for printing pallet labels by
       --pro*c code.
       --array will start from 1
       pl_putaway_utilities.gtbl_pallet_id(io_workvar_rec.n_seq_no)
                                                          :=lt_pallet_id;

       EXCEPTION
        WHEN OTHERS THEN
            lv_msg_text:= 'PO number: ' || i_erm_id
                       ||'TABLE= trans KEY= ' || lt_pallet_id || ', '
                       || i_prod_id ||', ' || i_cust_pref_vendor
                       || ' ACTION= INSERT '
                       ||' MESSAGE = ORACLE unable to create DLP transaction.';

            pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

            lv_error_text := sqlcode || sqlerrm;
            pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
                                                   || i_erm_id;
            pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to insert into TRANS for pallet_id  '
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
           pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
                                                   || i_erm_id;
           pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to select the record with status OPEN '
               ||'from erm table'
               ||' - sqlcode= ' || lv_error_text;
           RAISE;
           --rollback in reprocess method
       END; /*END CHECK PO STATUS */


      END IF;/*reprocess*/


   ELSE /*PALLET ID NOT FOUND*/
      RAISE e_pallet_id;
   END IF;
EXCEPTION
WHEN e_pallet_id THEN
   --LOG THE ERROR MESSAGE
   lv_msg_text := 'ORACLE unable to get next pallet_id sequence number';

   pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

   --ROLLBACK IN THE MAIN PACKAGE
   lv_error_text := sqlcode || sqlerrm;
   pl_putaway_utilities.gv_crt_message :='ERROR : Cannot open po= '
                                         || i_erm_id;
   pl_putaway_utilities.gv_crt_message :=
               RPAD(pl_putaway_utilities.gv_crt_message,80)
               ||'REASON: Unable to generate pallet_id seq no - sqlcode= '
               ||lv_error_text;
   RAISE;

WHEN OTHERS THEN
      --ROLLBACK IN THE MAIN PACKAGE
      RAISE;
END p_split_insert_table;
--------------------------------------------------------------------------------------------
FUNCTION f_split_putaway
  (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
   i_prod_id                   IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_aging_days                IN     NUMBER,
   i_total_qty                 IN     erd.qty%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)
RETURN BOOLEAN
IS

/*-----------------------------------------------------------------------
-- Function:
--    f_split_putaway
--
-- Description:
-- This method finds putaway slot for one split item in the PO
-- Parameters:
--    i_po_info_rec               - relevant details of PO are passed thru this
                                    record
--    i_prod   _id                - product id of the item for which details
                                    are fetched
--    i_cust_pref_vendor          - customer preferred vendor for the selected
                                    product
--    i_aging_days                - aging days for the item, -1 if no aging
                                    required
--    i_item_info_rec             - all information pertaining to the product
                                    type is passed using this record
--    io_workvar_rec              - all info related to processing by the
                                    function not included in
                                    i_item_related_info_rec,
--                                  i_po_info_rec and syspar_var_rec
                                   is included in this record
--    i_syspar_var_rec            - all the system parameters are passed
                                    using this record
--  Return Values:
      --TRUE  - All the pallets for the item were assigned a putaway slot.
      --FALSE - All the pallets for the item were not assigned a putaway slot.

---------------------------------------------------------------------*/
  ln_home  INTEGER;
  ln_fname VARCHAR2(50):='f_split_putaway';
BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
    --This will be used in the Exception message in assign putaway
    pl_putaway_utilities.gv_program_name := ln_fname;
   
   /*
    ** If this item is not in the floating zone then look for a home slot
    ** Splits should not go to the case home slot.
    */
    BEGIN
      SELECT l.logi_loc INTO io_workvar_rec.v_split_dest_loc
        FROM slot_type s, loc l
       WHERE s.slot_type = l.slot_type
         AND l.uom in (0, 1)
         AND l.perm = 'Y'
         AND l.rank = 1
         AND l.prod_id = i_prod_id
         AND l.cust_pref_vendor = i_cust_pref_vendor;

      ln_home := pl_putaway_utilities.ADD_HOME;

    EXCEPTION
     WHEN NO_DATA_FOUND THEN
      io_workvar_rec.v_split_dest_loc := '*';
      ln_home := pl_putaway_utilities.ADD_NO_INV;
    END;

    p_split_insert_table (i_prod_id,
                          i_cust_pref_vendor,
                          i_total_qty,
                          io_workvar_rec.v_split_dest_loc,
                          ln_home,
                          i_po_info_rec.v_erm_id,
                          i_aging_days,
                          i_syspar_var_rec.v_clam_bed_tracked_flag,
                          i_item_info_rec,
                          io_workvar_rec);
   IF io_workvar_rec.v_split_dest_loc <> '*' THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
EXCEPTION
 WHEN OTHERS THEN
  --ROLLBACK IN MAIN PACKAGE
  RAISE;
END f_split_putaway;
-------------------------------------------------------------------------------------------------
FUNCTION f_split_floating_open_assign
  (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
   i_prod_id                   IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_zone_id                   IN     zone.zone_id%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_total_qty                 IN     erd.qty%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)
RETURN  BOOLEAN
IS
   lv_msg_text          VARCHAR2(500);
   lv_fname             VARCHAR2(50) := 'f_split_floating_open_assign';
   lb_done             BOOLEAN := TRUE;
   li_index             INTEGER := 1;
/*-----------------------------------------------------------------------
-- Function:
--    f_split_floating_open_assign
--
-- Description:
--    This function assigns pallets to the open slots found in
      f_split_floating_rule
-- Parameters:
--    i_po_info_rec               - relevant details of PO are passed thru
                                    this record
--    i_prod_id                   - product id of the item for which details are
                                    fetched
--    i_cust_pref_vendor          - customer preferred vendor for the selected
                                    product
--    i_item_info_rec             - all information pertaining to the product
                                    type is passed using this record
--    io_workvar_rec              - all info related to processing by the
                                    function not included in
                                    i_item_related_info_rec,
--                                  i_po_info_rec and syspar_var_rec is
                                    included in this record
--    i_syspar_var_rec            - all the system parameters are passed using
                                    this record

--  Return Values:
      --TRUE  - All the pallets for the item were assigned a putaway slot.
      --FALSE - All the pallets for the item were not assigned a putaway slot.
---------------------------------------------------------------------*/


BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
    --This will be used in the Exception message in assign putaway
    pl_putaway_utilities.gv_program_name := lv_fname;
    lv_msg_text := 'Starting floating open assign for PO '
                   || i_po_info_rec.v_erm_id || ',prod id ' || i_prod_id
                   || ' ,cpv ' || i_cust_pref_vendor;

    pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

    /*
    ** Insert record into reserve inventory.
    */

    p_split_insert_table(i_prod_id,
                         i_cust_pref_vendor,
                         i_total_qty,
                         io_workvar_rec.gtbl_phys_loc(li_index),
                         pl_putaway_utilities.ADD_RESERVE,
                         i_po_info_rec.v_erm_id,
                         i_aging_days,
                         i_syspar_var_rec.v_clam_bed_tracked_flag,
                         i_item_info_rec,
                         io_workvar_rec);

    RETURN lb_done;

END f_split_floating_open_assign;


/*-----------------------------------------------------------------------
-- Function:
--    f_split_floating_rule
--
-- Description:
--    This function finds open slots for splits for items assigned
--    to a floating zone.  If an open slot is found then an inventory
--    record is created for the slot.
-- Parameters:
--    i_po_info_rec               - relevant details of PO are passed thru this
                                    record
--    i_prod_id                   - product id of the item for which details
                                    are fetched
--    i_cust_pref_vendor          - customer preferred vendor for the selected
                                    product
--    i_item_info_rec             - all information pertaining to the product
                                    type is passed using this record
--    io_workvar_rec              - all info related to processing by the
                                     function not included in
                                     i_item_related_info_rec,
--                                  i_po_info_rec and syspar_var_rec is
                                    included in this record
--    i_syspar_var_rec            - all the system parameters are passed
                                    using this record

--  Return Values:
      --TRUE  - All the pallets for the item were assigned a putaway slot.
      --FALSE - All the pallets for the item were not assigned a putaway slot.
---------------------------------------------------------------------*/
FUNCTION f_split_floating_rule
  (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
   i_prod_id                   IN     pm.prod_id%TYPE,
   i_cust_pref_vendor          IN     pm.cust_pref_vendor%TYPE,
   i_zone_id                   IN     zone.zone_id%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_total_qty                 IN     erd.qty%TYPE,
   i_item_info_rec             IN     pl_putaway_utilities.t_item_related_info,
   io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
   i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)
RETURN  BOOLEAN
IS
  lv_msg_text          VARCHAR2(500);
  lv_fname             VARCHAR2(50) := 'f_split_floating_rule';
  ln_count             NUMBER := 0;
  ln_inner_count       NUMBER := 0;
  --will be used for clearing all the arrays
  l_work_var_rec      pl_putaway_utilities.t_work_var;
  li_slot_cntr        BINARY_INTEGER := 1;
  lb_status           BOOLEAN := FALSE;

------------------------------------------------------------------------------
CURSOR c_oldest_exp_slot
IS
SELECT l.logi_loc logi_loc, l.put_aisle put_aisle, l.put_slot put_slot,
       l.put_level put_level, l.slot_type slot_type
  FROM slot_type s, loc l, lzone z, inv i
 WHERE s.slot_type      = l.slot_type
   AND l.logi_loc         = z.logi_loc
   AND z.logi_loc         = i.plogi_loc
   AND z.zone_id          = i_zone_id
   AND i.prod_id          = i_prod_id
   AND i.cust_pref_vendor = i_cust_pref_vendor
 ORDER BY i.exp_date, i.qoh, i.logi_loc;

------------------------------------------------------------
--Select the closest open slot to the pallet with the oldest expiration date.
CURSOR c_open_reserve_slot
IS
SELECT l.logi_loc logi_loc,
       l.available_height available_height,
       l.put_aisle put_aisle,
       l.put_slot put_slot,
       l.put_level put_level
  FROM slot_type s, loc l, lzone z
 WHERE s.slot_type      =  l.slot_type
   AND l.pallet_type    =  i_item_info_rec.v_pallet_type
   AND l.logi_loc       =  z.logi_loc
   AND l.perm           =  'N'
   AND l.status         =  'AVL'
   AND z.zone_id        = i_zone_id
   AND l.available_height IS NOT NULL
   AND l.slot_height    >= NVL(i_item_info_rec.n_case_height, 0)
   AND NOT EXISTS (SELECT 'x'
                     FROM inv i
                    WHERE i.plogi_loc = l.logi_loc)
 ORDER BY  l.available_height,
          ABS(io_workvar_rec.n_put_aisle1 - l.put_aisle),l.put_aisle,
          ABS(io_workvar_rec.n_put_slot1 - l.put_slot),l.put_slot,
          ABS(io_workvar_rec.n_put_level1 - l.put_level),l.put_level;

-----------------------------------------------------------------------
CURSOR c_reserve_last_ship_slot
IS
SELECT l.logi_loc logi_loc,
       l.available_height available_height,
       l.put_aisle put_aisle,
       l.put_slot put_slot,
       l.put_level put_level
  FROM slot_type s, loc l, lzone z
 WHERE l.pallet_type    = i_item_info_rec.v_pallet_type
   AND s.slot_type      = l.slot_type
   AND l.logi_loc       = z.logi_loc
   AND l.perm           = 'N'
   AND l.status         = 'AVL'
   AND l.available_height IS NOT NULL
   AND l.slot_height    >= NVL(i_item_info_rec.n_case_height, 0)
   AND z.zone_id        = i_zone_id
   AND NOT EXISTS(SELECT 'x'
                    FROM inv i
                   WHERE i.plogi_loc = l.logi_loc)
 ORDER BY  l.available_height,
          ABS(i_item_info_rec.n_last_put_aisle1 - l.put_aisle),l.put_aisle,
          ABS(i_item_info_rec.n_last_put_slot1  - l.put_slot),l.put_slot,
          ABS(i_item_info_rec.n_last_put_level1 - l.put_level),l.put_level;


-----------------------------------------------------------------------
BEGIN
    --reset the global variable
    pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
    --This will be used in the Exception message in assign putaway
    pl_putaway_utilities.gv_program_name := lv_fname;
    lv_msg_text := 'Starting Floating Rule for PO '
                  || i_po_info_rec.v_erm_id
                  ||',prod id '|| i_prod_id || ',cpv '
                  || i_cust_pref_vendor ||',zone ' || i_zone_id;
    pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

    lv_msg_text := 'LAST SHIP SLOT: put_aisle= '
                  || i_item_info_rec.n_last_put_aisle1 || ',put slot= '
                  || i_item_info_rec.n_last_put_slot1
                  ||',put level= ' || i_item_info_rec.n_last_put_level1;
    pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

    /*
    ** Select the slot from the floating zone the item is in with the
    ** oldest expiration date.  If a slot is found then we will look
    ** for the closest open slot to place the item.
    ** If the item is not found in inventory in the floating zone then
    ** look for open slots by the last ship slot for the item in the
    ** floating zone.
    */
    FOR r_oldest_exp_slot IN c_oldest_exp_slot
    LOOP
    --store the details for the slot having oldest expiry date
       io_workvar_rec.v_split_dest_loc := r_oldest_exp_slot.logi_loc;
       io_workvar_rec.n_put_aisle1     := r_oldest_exp_slot.put_aisle;
       io_workvar_rec.n_put_slot1      := r_oldest_exp_slot.put_slot;
       io_workvar_rec.n_put_level1     := r_oldest_exp_slot.put_level;
       io_workvar_rec.v_slot_type      := r_oldest_exp_slot.slot_type;

       ln_count :=  c_oldest_exp_slot % ROWCOUNT;
       --Record with oldest expiry date .i.e.the one which will expire
       --earliest
       --will be picked(First record from the recordset) and exit from the
       --cursor.
       EXIT;


    END LOOP;
    IF ln_count >0 THEN
       /*
        ** Found the item in the floating zone.  Find the closest open slot
        ** to the pallet with the oldest expiration date.  The slot must
        ** have the same pallet type as the item.
        */

        lv_msg_text := 'STARTING FROM LOC CLOSEST TO FIFO ITEM IN ZONE';
        pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

        lv_msg_text := 'FIFO : ' || ' put_aisle= '
                      || io_workvar_rec.n_put_aisle1 || ',put_slot= '
                      || io_workvar_rec.n_put_slot1
                      ||',put_level= ' || io_workvar_rec.n_put_level1;
        pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

        --clear the arrays

        io_workvar_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
        io_workvar_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
        io_workvar_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
        io_workvar_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
        io_workvar_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
        io_workvar_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

        /* fetch into host arrays */


       BEGIN
         FOR r_open_reserve_slot IN c_open_reserve_slot
         LOOP
            io_workvar_rec.gtbl_phys_loc(li_slot_cntr)  
                                       := r_open_reserve_slot.logi_loc;
            io_workvar_rec.gtbl_loc_height(li_slot_cntr) 
                                       := r_open_reserve_slot.available_height;
            io_workvar_rec.gtbl_put_aisle2(li_slot_cntr) 
                                       := r_open_reserve_slot.put_aisle;
            io_workvar_rec.gtbl_put_slot2(li_slot_cntr) 
                                       := r_open_reserve_slot.put_slot;
            io_workvar_rec.gtbl_put_level2(li_slot_cntr) 
                                       := r_open_reserve_slot.put_level;

            --increment the array count
            li_slot_cntr:=li_slot_cntr + 1;
            ln_inner_count :=  c_open_reserve_slot % ROWCOUNT;
         END LOOP;

         IF ln_inner_count > 0 THEN
            --store the number of locations
            io_workvar_rec.n_total_cnt := ln_inner_count;
            --log the message


            lv_msg_text := 'Number of closest locations to item with oldest '
                          || ' expiry in floating rule:  ' || ln_inner_count;
            pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);
            /* Process the records selected into the host arrays. */

            lb_status:= f_split_floating_open_assign(i_po_info_rec,
                                                     i_prod_id,
                                                     i_cust_pref_vendor,
                                                     i_zone_id,
                                                     i_aging_days,
                                                     i_total_qty,
                                                     i_item_info_rec,
                                                     io_workvar_rec,
                                                     i_syspar_var_rec);

         ELSIF ln_inner_count = 0 THEN /*no records fetched by cursor */


            lv_msg_text :='PO: '|| i_po_info_rec.v_erm_id
                          ||'TABLE=pallet_type,slot_type,loc,lzone KEY= '
                          || i_prod_id || ',' || i_cust_pref_vendor || ','
                          ||i_item_info_rec.v_zone_id || ','
                          || i_item_info_rec.v_pallet_type ||
                           ' ACTION=SELECT MESSAGE= ORACLE no slots ' ||
                           ' by existing inv having enough height and same '||
                           ' pallet_type in zone ';
            pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);


         END IF;/*cursor fetching open reserve slots*/
       EXCEPTION WHEN OTHERS THEN

            lv_msg_text := 'PO: '|| i_po_info_rec.v_erm_id
                           ||'TABLE=pallet_type,slot_type,loc,lzone KEY= '
                           || i_prod_id || ',' || i_cust_pref_vendor || ','
                           || i_item_info_rec.v_zone_id || ','
                           || i_item_info_rec.v_pallet_type
                           || 'ACTION=SELECT MESSAGE= ORACLE no slots '
                           || ' by existing inv having enough avl height '
                           || 'and pallet_type in zone ';
            pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);

       END;

    ELSIF ln_count = 0 THEN

        /*
        ** Did not find the item in inventory in the floating zone.
        ** See if there are open slots in the floating zone near the
        ** last ship slot for the item.
        */

        lv_msg_text := 'TABLE=inv KEY=PO ' || i_po_info_rec.v_erm_id
                      ||',prod id '|| i_prod_id || ',cpv'
                      || i_cust_pref_vendor || ','
                      || i_item_info_rec.v_zone_id
                      || ' ACTION=SELECT MESSAGE= ORACLE no '
                      || 'inventory for floating item in zone';
        pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

        --reset the array count also
        li_slot_cntr := 1;
        --reset the cursor count also
         ln_inner_count := 0;

        --clear the arrays
        io_workvar_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
        io_workvar_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
        io_workvar_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
        io_workvar_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
        io_workvar_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
        io_workvar_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

        /*
        ** Find the closest open slots to the last ship slot.
        ** Select into host arrays.
        */


        --  Fetch the records into host arrays.
       BEGIN
        FOR r_reserve_last_ship_slot IN c_reserve_last_ship_slot
        LOOP

            io_workvar_rec.gtbl_phys_loc(li_slot_cntr)
                                  := r_reserve_last_ship_slot.logi_loc;
            io_workvar_rec.gtbl_loc_height(li_slot_cntr)
                                  := r_reserve_last_ship_slot.available_height;
            io_workvar_rec.gtbl_put_aisle2(li_slot_cntr)
                                  := r_reserve_last_ship_slot.put_aisle;
            io_workvar_rec.gtbl_put_slot2(li_slot_cntr)
                                  := r_reserve_last_ship_slot.put_slot;
            io_workvar_rec.gtbl_put_level2(li_slot_cntr)
                                  := r_reserve_last_ship_slot.put_level;

            --increment the array count
            li_slot_cntr:=li_slot_cntr + 1;
            ln_inner_count :=  c_reserve_last_ship_slot % ROWCOUNT;

        END LOOP;
        IF ln_inner_count > 0 THEN
            --store the number of locations
            io_workvar_rec.n_total_cnt := ln_inner_count;
            --log the message

            lv_msg_text := 'Number of closest locations to last ship slot'
                          ||' in floating rule:  ' || io_workvar_rec.n_total_cnt;
            pl_log.ins_msg('INFO',lv_fname,lv_msg_text,NULL,sqlerrm);

            /* Process the records selected into the host arrays. */

            lb_status:= f_split_floating_open_assign(i_po_info_rec,
                                                     i_prod_id,
                                                     i_cust_pref_vendor,
                                                     i_zone_id,
                                                     i_aging_days,
                                                     i_total_qty,
                                                     i_item_info_rec,
                                                     io_workvar_rec,
                                                     i_syspar_var_rec);

         ELSIF ln_inner_count = 0 THEN /*no records fetched by cursor */

            lv_msg_text := 'PO: '|| i_po_info_rec.v_erm_id
                           ||'TABLE=pallet_type,slot_type,loc,lzone KEY= '
                           || i_prod_id || ',' || i_cust_pref_vendor || ','
                           || i_zone_id || ','
                           || i_item_info_rec.v_pallet_type 
                           || ' ACTION=SELECT MESSAGE= ORACLE no slots '
                           || 'by last ship slot having  enough avl height'
                           || ' and same pallet_type in zone';
            pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);

         END IF;/*cursor fetching open reserve slots based on last ship slot*/
       EXCEPTION
        WHEN OTHERS THEN

           lv_msg_text := 'PO: '|| i_po_info_rec.v_erm_id
                         ||'TABLE=pallet_type,slot_type,loc,lzone KEY= '
                         || i_prod_id || ',' || i_cust_pref_vendor || ','
                         ||i_zone_id || ',' || i_item_info_rec.v_pallet_type
                         ||' ACTION=SELECT MESSAGE= ORACLE no slots by last'
                         ||' ship slot having having  enough avl height'
                         || ' and same pallet_type in zone';
           pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
       END;

    END IF; /* select the slot with the old expiration date */
    lv_msg_text := 'Ending Floating rule for item ' || i_prod_id || ','
                  || i_cust_pref_vendor || ', zone ' ||
                           i_item_info_rec.v_zone_id;
    pl_log.ins_msg('WARN',lv_fname,lv_msg_text,NULL,sqlerrm);
    RETURN lb_status;
EXCEPTION
   WHEN OTHERS THEN
       --ROLLBACK IN THE MAIN PACKAGE

       RAISE;
END f_split_floating_rule;
-------------------------------------------------------------------------------
/*-----------------------------------------------------------------------------
--  FUNCTION:
--      f_floating_item_putaway
--  DESCRIPTION:

--  PARAMETERS:
--      i_po_info_rec          -   all relevant info pertaining to PO
--      i_product_id           -   product id of the item to be putaway
--      i_cust_pref_vendor     -   customer preferred vendor for the item to be
                                   putaway
--      i_aging_days           -   aging days for items that need aging,-1 for
                                   non aging items
--      i_item_info_rec        -   all relevant details pertaining to the item
                                   to be putaway
--      io_workvar_rec         -  all the variables shared across the
                                  functions reside in this record
--      i_syspar_var_rec       - all the system parameters
--      i_zone_id              - zone id of the zone for which this
                                 function is called
--  RETURN VALUES:
--      TRUE  - All the pallets for the item were assigned a putaway slot.
--      FALSE - All the pallets for the item were not assigned a putaway slot.
-------------------------------------------------------------------------------*/
FUNCTION f_floating_item_putaway
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
   lb_status               BOOLEAN;--holds the status of putaway,true if
                                   --putaway is complete
   lb_check_inv            BOOLEAN;
   ln_index                NUMBER;
   ln_count                NUMBER;
   lv_fname                VARCHAR2(30);
   lt_dest_loc             loc.logi_loc%TYPE;
   lt_aisle1               loc.put_aisle%TYPE;
   lt_slot1                loc.put_slot%TYPE;
   lt_level1               loc.put_level%TYPE;
   l_work_var_rec          pl_putaway_utilities.t_work_var;
-------------------------------------------------------------
--this cursor fetches open slots with matching pallet type
--in the order of there proximity to the location whose location
--details are passed as input parameters
CURSOR c_loc_exists
               (aisle1 loc.put_aisle%TYPE,
                slot1 loc.put_slot%TYPE,
                level1 loc.put_level%TYPE)
IS
SELECT l.logi_loc AS logi_loc,
       l.available_height AS available_height,
       l.put_aisle AS put_aisle,
       l.put_slot AS put_slot,
       l.put_level AS put_level
  FROM slot_type s,
       loc l,
       lzone z
 WHERE s.slot_type = l.slot_type
   AND l.pallet_type = i_item_info_rec.v_pallet_type
   AND l.logi_loc = z.logi_loc
   AND l.perm = 'N'
   AND l.status = 'AVL'
   AND l.available_height IS NOT NULL
   AND l.available_height >= io_workvar_rec.n_std_pallet_height
   AND z.zone_id = i_zone_id
   AND NOT EXISTS(SELECT 'x'
                    FROM inv i
                   WHERE i.plogi_loc = l.logi_loc)
 ORDER BY l.available_height,
       ABS(aisle1 - l.put_aisle), l.put_aisle,
       ABS(slot1  - l.put_slot), l.put_slot,
       ABS(level1 - l.put_level), l.put_level;
---------------------------------------------------------------
--this cursor fetches open slots with matching pallet type
--in the order of there proximity to the last shipment slot location
CURSOR c_last_ship IS
SELECT l.logi_loc AS logi_loc,
       l.available_height AS available_height,
       l.put_aisle AS put_aisle,
       l.put_slot AS put_slot,
       l.put_level AS put_level
  FROM slot_type s,
       loc l,
       lzone z
 WHERE l.pallet_type = i_item_info_rec.v_pallet_type
   AND s.slot_type = l.slot_type
   AND l.logi_loc = z.logi_loc
   AND l.perm = 'N'
   AND l.status = 'AVL'
   AND l.available_height IS NOT NULL
   AND l.available_height >=  io_workvar_rec.n_std_pallet_height
   AND z.zone_id = i_zone_id
   AND NOT EXISTS(SELECT 'x'
                    FROM inv i
                   WHERE i.plogi_loc = l.logi_loc)
ORDER BY l.available_height,
     ABS(i_item_info_rec.n_last_put_aisle1 - l.put_aisle), l.put_aisle,
     ABS(i_item_info_rec.n_last_put_slot1 - l.put_slot), l.put_slot,
     ABS(i_item_info_rec.n_last_put_level1 - l.put_level), l.put_level;
------------------------------------------------------------------------------
--this cursor fetches the details of the slot having inventory of the
--floating item,if any
CURSOR c_check_inv IS
      SELECT l.logi_loc logi_loc,
             l.put_aisle put_aisle,
             l.put_slot put_slot,
             l.put_level put_level,
             l.slot_type slot_type
        FROM slot_type s,
             loc l,
             lzone z,
             inv i
      WHERE s.slot_type = l.slot_type
        AND l.logi_loc = z.logi_loc
        AND z.logi_loc = i.plogi_loc
        AND z.zone_id = i_zone_id
        AND i.prod_id = i_product_id
        AND i.cust_pref_vendor = i_cust_pref_vendor
      ORDER BY i.exp_date,
               i.qoh,
               i.logi_loc;
-------------------------------------------------------------------------------
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
   lv_fname := 'f_floating_item_putaway';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;
   pl_log.ins_msg ('DEBUG', lv_fname,
                'Starting f_floating_item_putaway for item '||i_product_id
                ||',cpv'||i_cust_pref_vendor||', zone '||i_zone_id ,NULL, NULL);
   pl_log.ins_msg ('DEBUG', lv_fname,
                 ' LAST SHIP SLOT:  put_aisle='
                 ||i_item_info_rec.n_last_put_aisle1||', put_slot='
                 ||i_item_info_rec.n_last_put_slot1||', put_level='
                 ||i_item_info_rec.n_last_put_level1,NULL, NULL);
   BEGIN
      lb_check_inv := FALSE;
      lb_status    := FALSE;
      --check if inventory exists
      FOR r_check_inv IN c_check_inv LOOP
         lt_dest_loc := r_check_inv.logi_loc;
         lt_aisle1 := r_check_inv.put_aisle;
         lt_slot1 := r_check_inv.put_slot;
         lt_level1 := r_check_inv.put_level;
         io_workvar_rec.v_slot_type := r_check_inv.slot_type;
         lb_check_inv := TRUE;
         --only one will be picked
         --(First record from the recordset) and then exit from the
         --cursor.
         EXIT;
      END LOOP;
      --if it exists get a list of slots in the order of proximity
      --to the slot containing the item
      IF lb_check_inv = TRUE THEN
         pl_log.ins_msg ('DEBUG',lv_fname,
                         'Starting from loc closest to FEFO item in zone',
                         NULL, NULL);

         --clearing the pl/sql tables
         io_workvar_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
         io_workvar_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
         io_workvar_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
         io_workvar_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
         io_workvar_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;

         ln_count := 0;
         FOR r_loc_exists IN c_loc_exists(lt_aisle1,lt_slot1,lt_level1)
         LOOP
            ln_count := ln_count + 1;
            io_workvar_rec.gtbl_phys_loc(ln_count) :=r_loc_exists.logi_loc ;
            io_workvar_rec.gtbl_loc_height(ln_count)
                                        := r_loc_exists.available_height;
            io_workvar_rec.gtbl_put_aisle2(ln_count) :=r_loc_exists.put_aisle ;
            io_workvar_rec.gtbl_put_slot2(ln_count) := r_loc_exists.put_slot;
            io_workvar_rec.gtbl_put_level2(ln_count):= r_loc_exists.put_level;
         END LOOP;
         --if open slots exist then
         IF ln_count <> 0 THEN
            io_workvar_rec.n_total_cnt := ln_count;
            pl_log.ins_msg ('DEBUG', lv_fname,
                         'Floating slots closest to item in zone:  total_cnt:'
                         || io_workvar_rec.n_total_cnt,NULL, NULL);
             lb_status := f_floating_item_open_assign(i_po_info_rec,
                                                      i_product_id,
                                                      i_cust_pref_vendor,
                                                      i_aging_days,
                                                      i_item_info_rec,
                                                      io_workvar_rec,
                                                      i_syspar_var_rec,
                                                      i_zone_id);
         ELSE
            pl_log.ins_msg ('WARN', lv_fname,
                         'TABLE=pallet_type,slot_type,loc,lzone  KEY=PO '
                         ||i_po_info_rec.v_erm_id || ',prod id '
                         ||i_product_id||',cpv '||i_cust_pref_vendor||','
                         ||i_zone_id
                         ||','||i_item_info_rec.v_pallet_type
                         ||'  ACTION= SELECT  MESSAGE='
                         ||'FLOATING RULE: ORACLE no slots near'
                         ||' floating pick slot having same'
                         ||' pallet_type and avl height > std pallet'
                         ||' height in zone ',
                           NULL, NULL);
         END IF;
      ELSE
         --The item does not exist in the floating zone.
         pl_log.ins_msg ('WARN', lv_fname,
                         'TABLE=inv  KEY=PO '
                         || i_po_info_rec.v_erm_id||',prod id '
                         ||i_product_id||',cpv '
                         ||i_cust_pref_vendor||','||i_zone_id
                         ||'  ACTION= SELECT  MESSAGE= '
                         ||'FLOATING RULE:: ORACLE no inventory '
                         ||'for floating item'
                         ||' in zone  ',
                         NULL, SQLERRM);
         --clearing the pl/sql tables
         io_workvar_rec.gtbl_phys_loc   := l_work_var_rec.gtbl_phys_loc;
         io_workvar_rec.gtbl_loc_height := l_work_var_rec.gtbl_loc_height;
         io_workvar_rec.gtbl_put_aisle2 := l_work_var_rec.gtbl_put_aisle2;
         io_workvar_rec.gtbl_put_slot2  := l_work_var_rec.gtbl_put_slot2;
         io_workvar_rec.gtbl_put_level2 := l_work_var_rec.gtbl_put_level2;
         io_workvar_rec.gtbl_put_path2  := l_work_var_rec.gtbl_put_path2;

         --Find closest open slot to last ship slot

         ln_count := 0;
         FOR r_last_ship IN c_last_ship LOOP
            ln_count := ln_count + 1;
            io_workvar_rec.gtbl_phys_loc(ln_count):= r_last_ship.logi_loc ;
            io_workvar_rec.gtbl_loc_height(ln_count)
                                              := r_last_ship.available_height;
            io_workvar_rec.gtbl_put_aisle2(ln_count) :=r_last_ship.put_aisle ;
            io_workvar_rec.gtbl_put_slot2(ln_count) := r_last_ship.put_slot;
            io_workvar_rec.gtbl_put_level2(ln_count):= r_last_ship.put_level;
         END LOOP;
          --if open slots exist in the zone then
         IF ln_count <> 0 THEN
            io_workvar_rec.n_total_cnt := ln_count;
            lb_status := f_floating_item_open_assign(i_po_info_rec,
                                                     i_product_id,
                                                     i_cust_pref_vendor,
                                                     i_aging_days,
                                                     i_item_info_rec,
                                                     io_workvar_rec,
                                                     i_syspar_var_rec,
                                                     i_zone_id);
         ELSE
            pl_log.ins_msg ('WARN', lv_fname,
                         'TABLE=pallet_type,slot_type,loc,lzone  KEY=PO '
                         || i_po_info_rec.v_erm_id ||',prod id '
                         ||i_product_id||',cpv '||i_cust_pref_vendor||','
                         ||i_zone_id||',' ||i_item_info_rec.v_pallet_type
                         ||',' ||i_item_info_rec.n_pallet_cube
                         ||'  ACTION= SELECT  MESSAGE='
                         ||' FLOATING RULE:: ORACLE no slots near last '
                         ||'ship slot having same pallet_type  > last_pik_cube'
                         ||' in zone',
                         NULL, NULL);
         END IF;
      END IF;
   EXCEPTION
   WHEN OTHERS THEN
    RAISE;
   END;
   pl_log.ins_msg ('DEBUG', lv_fname,
                   'Ending f_floating_item_putaway for item '||i_product_id
                   ||' cpv'||i_cust_pref_vendor||' zone '||i_zone_id,
                   NULL, SQLERRM);
   RETURN lb_status;
END f_floating_item_putaway;

/*-------------------------------------------------------------------------------
--  FUNCTION:
--      f_floating_item_open_assign
--  DESCRIPTION:

--  PARAMETERS:
--       i_po_info_rec          -   all relevant info pertaining to PO
--       i_product_id           -   product id of the item to be putaway
--       i_cust_pref_vendor     -   customer preferred vendor for the item to
                                    be  putaway
--       i_aging_days           -   aging days for items that need aging,-1
                                    for non aging items
--       i_item_info_rec        -   all relevant details pertaining to the
                                    item to be putaway
--       io_workvar_rec
--       i_syspar_var_rec
--       i_first_or_second_flag
--       i_zone_id
--  RETURN VALUES:
--      TRUE  - All the pallets for the item were assigned a putaway slot.
--      FALSE - All the pallets for the item were not assigned a putaway slot.
--------------------------------------------------------------------------------*/
FUNCTION f_floating_item_open_assign
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
   ln_index NUMBER := 1;
   lv_fname VARCHAR2(30);
BEGIN
   --reset the global variable
   pl_log.g_program_name     := 'PL_SPLIT_AND_FLOATING_PUTAWAY';
   lv_fname := 'f_floating_item_open_assign';
   --This will be used in the Exception message in assign putaway
   pl_putaway_utilities.gv_program_name := lv_fname;
   pl_log.ins_msg ('DEBUG',lv_fname ,
                    'Starting f_floating_item_open_assign for item '
                    ||i_product_id||',cpv'||i_cust_pref_vendor||', zone '
                    ||i_zone_id ,NULL, NULL);
    --continue untill all the slots are filled or entire quantity
   --is putaway

   WHILE ln_index <= io_workvar_rec.n_total_cnt
         AND io_workvar_rec.n_current_pallet < io_workvar_rec.n_num_pallets
   LOOP
      --if enough height is available then putaway the pallet
      --else move on to next slot
      IF  io_workvar_rec.gtbl_loc_height(ln_index) >=
          ((ceil(io_workvar_rec.n_each_pallet_qty /i_item_info_rec.n_ti)
            * i_item_info_rec.n_case_height) + i_item_info_rec.n_skid_height)
      THEN
         pl_putaway_utilities.p_insert_table
                                      (i_product_id,
                                       i_cust_pref_vendor,
                                       io_workvar_rec.gtbl_phys_loc(ln_index),
                                       pl_putaway_utilities.ADD_RESERVE,
                                       i_po_info_rec.v_erm_id,
                                       i_aging_days,
                                       i_syspar_var_rec.v_clam_bed_tracked_flag,
                                       i_item_info_rec ,
                                       io_workvar_rec);
         io_workvar_rec.n_current_pallet := io_workvar_rec.n_current_pallet + 1;
         ln_index := ln_index + 1;
         IF io_workvar_rec.n_current_pallet =(io_workvar_rec.n_num_pallets - 1)
         THEN
           io_workvar_rec.n_each_pallet_qty :=io_workvar_rec.n_last_pallet_qty;
         END IF;
      ELSE
         ln_index := ln_index + 1;
      END IF;
   END LOOP;
   pl_log.ins_msg ('DEBUG', lv_fname,
                    'Ending f_floating_item_open_assign for item '
                    ||i_product_id
                    ||' cpv'||i_cust_pref_vendor||' zone '||i_zone_id,
                    NULL, SQLERRM);
   IF  io_workvar_rec.n_current_pallet >= io_workvar_rec.n_num_pallets THEN
      RETURN(TRUE);
   ELSE
      RETURN(FALSE);
   END IF;
END f_floating_item_open_assign;
-------------------------------------------------------------------------------
BEGIN
   --this is used for initialising global variables once
  --global variables set for logging the errors in swms_log table

     pl_log.g_application_func := 'RECEIVING AND PUTAWAY';
     
END pl_split_and_floating_putaway; -- Package Body
/

