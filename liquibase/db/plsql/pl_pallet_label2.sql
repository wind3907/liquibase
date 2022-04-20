--PACKAGE SPEC
PROMPT Creating Package PL_PALLET_LABEL2 ...
CREATE OR REPLACE PACKAGE swms.pl_pallet_label2 IS

   --  sccs_id=@(#) src/schema/plsql/pl_pallet_label2.sql, swms, swms.9, 10.1.1 9/7/06 1.5

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_pallet_label2
   --
   -- Description:
   --    This will be the main package.
   --    It will consist of  procedures P_Assign_Putaway_Slot
   --     and P_Find_Putaway_Slot.
   --    It is called by subroutine One-Pallet_Label in the there.
   --    Pro*C program Pallet_Label2.pcones
   --    if the inches logic syspar is set.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/04/02          Initial Version
   --    07/23/03 acppzp   DN# 11349 Changes for OSD,SN Receipt
   --    08/23/03 acphxs   DN# 11309 Changes for MSKU
   --    08/24/04 prpbcb   Oracle 7 rs239a DN None
   --                      Oracle 8 rs239b swms8 DN None
   --                      Oracle 8 rs239b swms9 DN 11725
   --                      Modified to process a SN a line item at a time since
   --                      a SN line item is a pallet.  Before it worked
   --                      similar to a regular PO grouping by item which is
   --                      not the correct processing.  No logic was changed
   --                      changed for splits (erd.uom = 1) on a SN but a SN
   --                      should never have splits.
   --                      Objects modified:
   --                         - p_assign_putaway_slot procedure
   --
   --    07/27/15 prpbcb   Brian Bent
   --                      Symbotic project
   --                      Bug fix.  TFS work item 505
   --                      "pl_putaway_utilities.f_check_home_item" now passed
   --                      a record instead of individual fields.
   --                      Changed call to pl_putaway_utilities.f_check_home_item
   --                      in function "f_find_putaway_slot".
   --
   --                      Compiling complained about parameter "i_item_related_info_rec"
   --                      for function "f_find_putaway_slot".  Changed parameter
   --                      from IN to IN OUT.
   --
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
   -- Function/Procedure Declarations
   ---------------------------------------------------------------------------

PROCEDURE p_assign_putaway_slot(i_po_number   IN erm.erm_id%TYPE,
                                o_error       OUT BOOLEAN,
                                o_crt_message OUT VARCHAR2);


FUNCTION f_find_putaway_slot
    (i_po_info_rec               IN     pl_putaway_utilities.t_po_info,
     i_product_id                IN     pm.prod_id%TYPE,
     i_customer_preferred_vendor IN     pm.cust_pref_vendor%TYPE,
     i_aging_days                IN     aging_items.aging_days%TYPE,
     i_item_related_info_rec     IN OUT pl_putaway_utilities.t_item_related_info,
     io_workvar_rec              IN OUT pl_putaway_utilities.t_work_var,
     i_syspar_var_rec            IN     pl_putaway_utilities.t_syspar_var)
RETURN BOOLEAN;

FUNCTION f_find_damage_zone_locations
                ( i_prod_id                IN      pm.prod_id%TYPE,
                  i_cust_pref_vendor       IN      pm.cust_pref_vendor%TYPE,
                  i_erm_id                 IN      erm.erm_id%TYPE,
                  i_uom                    IN      erd.uom%TYPE,
                  i_aging_days             IN      aging_items.aging_days%TYPE,
                  i_clam_bed_flag          IN      sys_config.config_flag_val%TYPE,
                  io_item_related_info_rec IN OUT  pl_putaway_utilities.t_item_related_info,
                  io_workvar_rec           IN OUT  pl_putaway_utilities.t_work_var)

RETURN BOOLEAN;
PROCEDURE p_reprocess
                      (i_po_number        IN  erm.erm_id%TYPE,
                       i_prod_id          IN  pm.prod_id%type,
                       i_cust_pref_vendor IN  pm.cust_pref_vendor%type,
                       i_uom              IN  erd.uom%TYPE,
                       i_dmg_ind          IN  VARCHAR2,
                       o_error            OUT BOOLEAN,
                       i_total_qty        IN  erd.qty%TYPE,
                       o_pallet_id        OUT  pl_putaway_utilities.t_pallet_id,
                       o_crt_message      OUT VARCHAR2);

END pl_pallet_label2;

/
------------------------------------------------------------------------------

--PACKAGE BODY



CREATE OR REPLACE PACKAGE BODY swms.pl_pallet_label2
AS
   --  sccs_id=@(#) src/schema/plsql/pl_pallet_label2.sql, swms, swms.9, 10.1.1 9/7/06 1.5

   --------------------------------------------------------------------------
   -- Function:
   --    p_assign_putaway_slot
   --
   -- Description:
   -- This procedure involves processing of each product in sn/po one by one in
   -- a loop.  It retrieves all the necessary information and stores it in
   -- the respective record types declared in package spec PL_PUTAWAY_UTILITIES
   -- which will be used for further processing.
   --
   -- Apart from retrieval of information program also involves calculation
   -- of no of pallets, each pallet qty, last pallet qty, std pallet height etc.
   --
   -- Parameters:
   --    i_po_number   - Purchase order number/shipment number.
   --    o_error       - Boolean Flag
   --                  - TRUE:In case of error
   --                  - FALSE:No Error
   --    o_crt_message - Message for displaying on
   --                  - CRT screens.
   --
   -- Called From:
   --    one_pallet_label.pc
   --
   -- Exceptions Raised:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- --------------------------------------------------
   --    08/24/04 prpbcb   Modified to process a SN a line item at a time since
   --                      a SN line item is a pallet.  Before it worked
   --                      similar to a regular PO grouping by item.  No logic
   --                      was changed for splits (erd.uom = 1) on a SN but
   --                      a SN should never have splits.  Removed cursor
   --                      c_line_item and replaced with a ref cursor.
   --                      I did not especially want to use a ref cursor
   --                      but not doing so would have resulted in more
   --                      modifications.  Using the ref cursor allows most
   --                      of the original logic to remain with the major
   --                      change having separate select statements for
   --                      a PO and SN.  Before there was only one select
   --                      statement.  A local procedure was created
   --                      which will build the appropriate select statement.
   --                       
   --                      Note that a SN should never have splits and if
   --                      if does the results may not be what is desired.
   --------------------------------------------------------------------------


PROCEDURE p_assign_putaway_slot(i_po_number   IN  erm.erm_id%TYPE,
                                o_error       OUT BOOLEAN,
                                o_crt_message OUT VARCHAR2)
IS
   -- This type needs to batch the SN and PO data returned by the select
   -- statement.
   TYPE t_snpo_info_rec IS RECORD
        (prod_id            pm.prod_id%TYPE,
         cust_pref_vendor   pm.cust_pref_vendor%TYPE,
         category           pm.category%TYPE,
         erm_line_id        erd_lpn.ERM_LINE_ID%TYPE,
         total_qty          NUMBER);

   --
   TYPE line_item_curtype IS REF CURSOR RETURN t_snpo_info_rec;
   line_item_curvar           line_item_curtype;
   lr_split_item              t_snpo_info_rec;
   lr_case_item               t_snpo_info_rec;

   lt_erm_type                erm.erm_type%TYPE;
   lt_wh_id                   erm.warehouse_id%TYPE;
   lt_to_wh_id                erm.to_warehouse_id%TYPE;
   lt_aging_days              aging_items.aging_days%TYPE;
   lt_lst_pallet_height       inv.pallet_height%TYPE;
   lt_std_pallet_height       inv.pallet_height%TYPE;

   lb_no_splits               BOOLEAN;
   lb_partial_pallet          BOOLEAN;
   lb_done                    BOOLEAN:=FALSE;

   lv_result                  VARCHAR2(100);
   lv_msg_text                VARCHAR2(500);
   lv_pname                   VARCHAR2(50) := 'p_assign_putaway_slot';
   lv_ind                     VARCHAR2(1);
   ln_num_pallets             PLS_INTEGER;
   ln_podtl_count             PLS_INTEGER := 0;
   ln_uom                     PLS_INTEGER;      -- The uom to process.

   --assign these variables to work var rec
   ln_each_pallet_qty         NUMBER(10,4);
   ln_last_pallet_qty         NUMBER(10,4);
   ln_count                   NUMBER :=0;
   ln_cnt                     NUMBER :=0;
   -------------------------------------

   l_syspar_var_rec           pl_putaway_utilities.t_syspar_var;
   l_po_info_rec              pl_putaway_utilities.t_po_info;
   l_item_info_rec            pl_putaway_utilities.t_item_related_info;
   l_work_var_rec             pl_putaway_utilities.t_work_var;

   -- Cursor for picking up all the products in particular SN/PO

   CURSOR c_transfer_items (i_erm_id erm.erm_id%TYPE)
   IS
   SELECT prod_id, cust_pref_vendor, qty
     FROM erd
    WHERE erm_id = i_erm_id
    ORDER BY erm_line_id;


   ---------------------------------------------------------------------------
   -- Local Procedure:
   --    open_snpo_stream
   --
   -- Description:
   --    This procedure opens the appropriate data stream for a PO/SN.
   --    How the records are selected are different for a PO and SN.  For a
   --    PO the records are grouped by item.  For a SN each line is a pallet
   --    so the SN is processed by line by line.
   --
   -- Parameters:
   --    i_erm_type      - What is being processed.  Should be PO or SN.
   --    i_po_number     - The PO or SN number.
   --    i_uom           - UOM to process.  Splits could be received on a
   --                      PO but should not be for a SN.
   --    io_item_curvar  - Pointer to the select statement to process.
   --
   -- Exceptions Raised:
   --    pl_exc.e_database_error     - Any error.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    08/24/04 prpbcb   Created.
   ---------------------------------------------------------------------------
   PROCEDURE open_snpo_stream(i_erm_type     IN     erm.erm_type%TYPE,
                              i_po_number    IN     erm.erm_id%TYPE,
                              i_uom          IN     erd.uom%TYPE,
                              io_item_curvar IN OUT line_item_curtype)
   IS
      l_message        VARCHAR2(500);
      l_object_name    VARCHAR2(30) := 'open_snpo_stream';
   BEGIN
      IF (i_erm_type != 'SN') THEN
         --
         -- Have something other than a SN.
         --
         BEGIN                        -- Start a new block to trap errors.
            OPEN io_item_curvar FOR
               SELECT erd.prod_id          prod_id,
                      erd.cust_pref_vendor cust_pref_vendor,
                      pm.category          category,
                      0                    erm_line_id, -- Not needed for a PO
                                                     -- but is needed by a SN
                                                     -- so value is required.
                                                     -- All records need the
                                                     -- same value for the
                                                     -- grouping to be correct.
                      SUM(erd.qty)         total_qty
              FROM erm,
                   pm,
                   erd
             WHERE erd.prod_id          = pm.prod_id
               AND erd.cust_pref_vendor = pm.cust_pref_vendor
               AND erd.erm_id           = i_po_number
               AND erm.erm_id           = i_po_number
               AND erm.erm_type         ='PO'
               AND erd.uom              = i_uom
             GROUP BY erd.prod_id,
                      erd.cust_pref_vendor,
                      pm.brand,
                      pm.mfg_sku,
                      pm.category,
                      0
             ORDER BY erd.prod_id,
                      erd.cust_pref_vendor;
         EXCEPTION WHEN OTHERS THEN
            -- Log the eror.
            l_message := pl_putaway_utilities.program_code ||
                '  TABLE="ERM,PM,ERD"' ||
                '  KEY=[' || i_po_number || '][' || TO_CHAR(i_uom) || ']' ||
                '(i_po_number,i_uom)' ||
                '  ACTION = "OPEN"' ||
                '  MESSAGE = "Failed to open io_item_curvar for the PO"';

            pl_log.ins_msg('FATAL', l_object_name, l_message, SQLCODE, SQLERRM);

            RAISE;  -- Propagate the error
         END;
      ELSE
         --
         -- Processing a SN.
         --
         BEGIN                        -- Start a new block to trap errors.
            OPEN io_item_curvar FOR
               SELECT erd.prod_id          prod_id,
                      erd.cust_pref_vendor cust_pref_vendor,
                      pm.category          category,
                      erd_lpn.erm_line_id  erm_line_id,  -- Needed for a SN.
                      erd.qty              total_qty
                 FROM erm,
                      pm,
                      erd,
                      erd_lpn
                WHERE erd.erm_id               = i_po_number
                  AND erm.erm_id               = i_po_number
                  AND erm.erm_type             = 'SN'
                  AND erd_lpn.sn_no            = i_po_number
                  AND erd.uom                  = i_uom
                  AND erd.erm_line_id          = erd_lpn.erm_line_id
                  AND erd_lpn.parent_pallet_id IS NULL
                  AND pm.prod_id               = erd.prod_id
                  AND pm.cust_pref_vendor      = erd.cust_pref_vendor
                ORDER BY erd.prod_id,
                         erd.cust_pref_vendor,
                         NVL(TRUNC(erd_lpn.exp_date), TRUNC(SYSDATE)),
                         erd.qty,
                         pm.brand,
                         pm.mfg_sku,
                         pm.category;
         EXCEPTION WHEN OTHERS THEN
            -- Log the eror.
            l_message := pl_putaway_utilities.program_code ||
                '  TABLE="ERM,PM,ERD,ERD_LPN"' ||
                '  KEY=[' || i_po_number || '][' || TO_CHAR(i_uom) || ']' ||
                '(i_po_number,i_uom)' ||
                '  ACTION = "OPEN"' ||
                '  MESSAGE = "Failed to open io_item_curvar for the SN"';

            pl_log.ins_msg('FATAL', l_object_name, l_message, SQLCODE, SQLERRM);

            RAISE;  -- Propagate the error
         END;
      END IF;

   EXCEPTION WHEN OTHERS THEN
         -- Log the eror.
         l_message := pl_putaway_utilities.program_code ||
             '  TABLE="NONE"' ||
             '  [' || i_po_number || '][' || TO_CHAR(i_uom) || ']' ||
             '(i_po_number,i_uom)' ||
             '  ACTION = "OPEN"  MESSAGE = "Failed to open io_item_curvar"';

            pl_log.ins_msg('FATAL', l_object_name, l_message, SQLCODE, SQLERRM);
         RAISE;  -- Propagate the error
   END open_snpo_stream;   -- end the local procedure


   BEGIN
      --Setting the global variables
      pl_log.g_program_name     := 'PL_PALLET_LABEL2';
      --This will be used in the Exception message in assign putaway
      pl_putaway_utilities.gv_program_name := lv_pname;
      pl_putaway_utilities.gb_reprocess := FALSE;

      BEGIN

           SELECT erm_type, warehouse_id, to_warehouse_id
             INTO lt_erm_type, lt_wh_id, lt_to_wh_id
             FROM erm
            WHERE erm_id = i_po_number;
            --SET THE RECORD TYPE SN/PO INFO
            l_po_info_rec.v_erm_id   := i_po_number;
            l_po_info_rec.v_erm_type := lt_erm_type;
            l_po_info_rec.v_wh_id    := lt_wh_id;
            l_po_info_rec.v_to_wh_id := lt_to_wh_id;
       EXCEPTION
            WHEN NO_DATA_FOUND THEN
                --LOG THE MESSAGE
               lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                             ' ,Table = "ERM"'
                             ||' ,Key = "SN/PO :" '
                             ||i_po_number ||',ACTION = "SELECT" '
                             || ' Message = "Oracle failed to select SN/PO Info"';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
      END;

      /* DN:11309 Multi SKU related changes */
      DECLARE
      t_temp pl_msku.t_parent_pallet_id_arr;
      BEGIN
      o_error := FALSE;
      if lt_erm_type = 'SN' THEN
          pl_msku.p_assign_msku_putaway_slots(i_po_number,
                                              t_temp,
                                              o_error,
                                              o_crt_message);
      END IF;

      IF o_error = TRUE THEN
          pl_putaway_utilities.gv_crt_message := 'ERROR: Putaway cannot be processed ';
          pl_putaway_utilities.gv_crt_message := RPAD(pl_putaway_utilities.
                                                            gv_crt_message,80)
                                                       || 'REASON: ERROR IN : '
                                                       || pl_putaway_utilities.
                                                          gv_program_name
                                                       || ' ,MESSAGE : '||o_crt_message
                                                       || sqlcode || sqlerrm;
          o_crt_message := pl_putaway_utilities.gv_crt_message;
           ROLLBACK;
           RETURN;
      END IF;

      EXCEPTION
      WHEN OTHERS THEN
       o_error := TRUE;
       pl_putaway_utilities.gv_crt_message := 'ERROR: MSKU Putaway cannot be processed ';
       pl_putaway_utilities.gv_crt_message := RPAD(pl_putaway_utilities.
                                                         gv_crt_message,80)
                                                    || 'REASON: ERROR IN : '
                                                    || pl_putaway_utilities.
                                                       gv_program_name
                                                    || ' ,MESSAGE : '
                                                    || sqlcode || sqlerrm;

       o_crt_message := pl_putaway_utilities.gv_crt_message;
        ROLLBACK;
        RETURN;
      END;
      /* END  DN:11309 Multi SKU related changes*/

      BEGIN
         SELECT count(erm_id) into ln_podtl_count
           FROM erd
          WHERE erm_id = i_po_number;

      EXCEPTION
         WHEN OTHERS THEN
         --LOG THE MESSAGE

         lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
         ' ,Table = "ERD"'
         || ',Key = "SN/PO",ACTION = "SELECT",Message = '
         ||'"Oracle failed to select SN/PO Detail Info For SN/PO: "'
         ||i_po_number;

         pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
      END;

   IF ln_podtl_count > 0 THEN
      --process
      --set the global variable
      pl_putaway_utilities.gv_crt_message    := pl_putaway_utilities.SUCCESS;
      --reset the seq no
      l_work_var_rec.n_seq_no := 0;
      --Retrieve values of syspar flags

      pl_putaway_utilities.p_get_syspar(l_syspar_var_rec,
                                        i_po_number);
      --reset the global variable
      pl_log.g_program_name     := 'PL_PALLET_LABEL2';
      --check for ERM_TYPE
      IF substr(lt_erm_type,1,2) = 'TR' THEN  --ERM TYPE = TR
         -- For each product in that SN/PO
         -- create record in transaction table.
         FOR v_transfer_items in c_transfer_items(i_po_number)
         LOOP
            BEGIN
              INSERT INTO trans
                                (trans_id,
                                 trans_type,
                                 trans_date,
                                 rec_id,
                                 user_id,
                                 exp_date,
                                 qty,
                                 uom,
                                 prod_id,
                                 cust_pref_vendor,
                                 upload_time,
                                 new_status,
                                 warehouse_id)
                   VALUES (trans_id_seq.NEXTVAL,
                           'TPI',
                           SYSDATE,
                           i_po_number,
                           USER,
                           TRUNC(SYSDATE),
                           v_transfer_items.qty,
                           0,
                           v_transfer_items.prod_id,
                           v_transfer_items.cust_pref_vendor,
                           TO_DATE('01-JAN-1980', 'DD-MON-YYYY'),
                           'OUT',
                           lt_to_wh_id);
            EXCEPTION
               WHEN OTHERS THEN
               --LOG THE MESSAGE

               lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                ' ,Table = "TRANS",KEY = SN/PO"'
                || i_po_number || ',' || v_transfer_items.prod_id
                        || ',' || v_transfer_items.cust_pref_vendor || ' ",'
               ||' Action = "INSERT",Message= "Insertion of TPI into TRANS failed"';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
            END;
         END LOOP;
      END IF;                --END ERM TYPE=TR

      --
      -- Perform split processing for each line item on the PO/SN with
      -- a uom = 1. 
      -- NOTE:  A SN should not have a line item with uom = 1.
      --
      ln_uom := 1;
      open_snpo_stream(lt_erm_type, i_po_number, ln_uom, line_item_curvar);

      LOOP
         FETCH line_item_curvar INTO lr_split_item;
         EXIT WHEN line_item_curvar%NOTFOUND;

         -- Reset the global variable for each product
         pl_log.g_program_name     := 'PL_PALLET_LABEL2';

         -- Get all the data needed for the product from the pm table.
         -- Retrieves all item related info in record type.

         pl_putaway_utilities.p_get_item_info(lr_split_item.prod_id,
         lr_split_item.cust_pref_vendor,
         l_item_info_rec);

         -- Get aging days for item that needs to be aged.

         lt_aging_days :=
         pl_putaway_utilities.f_retrieve_aging_items
                               (lr_split_item.prod_id,
                                lr_split_item.cust_pref_vendor);

         --process putaway task for split item

         lb_done := pl_split_and_floating_putaway.f_split_find_putaway_slot
                                              (l_po_info_rec,
                                               lr_split_item.prod_id,
                                               lr_split_item.cust_pref_vendor,
                                               lt_aging_days,
                                               lr_split_item.total_qty,
                                               l_item_info_rec,
                                               l_work_var_rec,
                                               l_syspar_var_rec);

         IF lb_done THEN
             lv_result := 'Entire qty has been putaway';
         ELSE
             lv_result := 'Entire qty could not be putaway';
         END IF;
         --reset the global variable
         pl_log.g_program_name     := 'PL_PALLET_LABEL2';
         lv_msg_text := 'Returned from split  and floating putaway for item '
                       || lr_split_item.prod_id
                       ||'and cpv ' || lr_split_item.cust_pref_vendor
                       ||'in SN/PO : ' ||i_po_number
                       ||' and ' || lv_result;
         pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);
         ln_count := line_item_curvar%ROWCOUNT;
      END LOOP;  -- end split processing

      -- Reset ln_count
      ln_count := 0;

      --
      -- Perform case processing for each line item on the PO/SN with
      -- a uom = 0. 
      -- For a SN each line is processed since each line is a pallet.
      --
      ln_uom := 0;
      open_snpo_stream(lt_erm_type, i_po_number, ln_uom, line_item_curvar);

      LOOP
         FETCH line_item_curvar INTO lr_case_item;
         EXIT WHEN line_item_curvar%NOTFOUND;

            -- Reset the global variable for each product
            pl_log.g_program_name     := 'PL_PALLET_LABEL2';

            -- Get all the data needed for the product from the pm table.
            -- Retrieves all item related info in record type

            pl_putaway_utilities.p_get_item_info(lr_case_item.prod_id,
                                                 lr_case_item.cust_pref_vendor,
                                                 l_item_info_rec);

            pl_putaway_utilities.p_get_erm_info(i_po_number,lr_case_item.prod_id,
                                                 lr_case_item.cust_pref_vendor,
                                                 l_item_info_rec);

            lt_aging_days := pl_putaway_utilities.f_retrieve_aging_items
                                                    (lr_case_item.prod_id,
                                                     lr_case_item.cust_pref_vendor);


            -- Set the slot count to zero
            l_work_var_rec.n_slot_cnt := 0;

            -- Calculate number of pallets for the quantity
            ln_num_pallets := TRUNC((lr_case_item.total_qty/(l_item_info_rec.n_spc))
                                    /(l_item_info_rec.n_ti*l_item_info_rec.n_hi));

            -- Check for partial pallet, add one to num_pallets
            -- and set flag appropriately.
            IF MOD((lr_case_item.total_qty/(l_item_info_rec.n_spc)),
                    (l_item_info_rec.n_ti*l_item_info_rec.n_hi)) <> 0 THEN

               ln_num_pallets    := ln_num_pallets + 1;
               lb_partial_pallet := true;
               lv_ind := 'Y';
            ELSE
               lb_partial_pallet := false;
               lv_ind := 'N';
            END IF;

            IF ln_num_pallets = 1 THEN
               ln_each_pallet_qty := (lr_case_item.total_qty/
                                           (l_item_info_rec.n_spc));
               ln_last_pallet_qty := ln_each_pallet_qty;
               -- A partial pallet will have the height rounded up
               -- to the nearest ti.
               lt_lst_pallet_height:= (CEIL(ln_last_pallet_qty /l_item_info_rec.n_ti)
                                         * l_item_info_rec.n_case_height)
                                           + l_item_info_rec.n_skid_height;
               lt_std_pallet_height := lt_lst_pallet_height;
            ELSE
               -- Number of pallets more than one.
               ln_each_pallet_qty := l_item_info_rec.n_ti* l_item_info_rec.n_hi;

               IF lb_partial_pallet THEN

                  ln_last_pallet_qty := (lr_case_item.total_qty
                                    - ((ln_num_pallets-1)* ln_each_pallet_qty
                                    * l_item_info_rec.n_spc))
                                     /l_item_info_rec.n_spc;
               ELSE
                  ln_last_pallet_qty := ln_each_pallet_qty;
               END IF;

               /* A partial pallet will have the height rounded up
               to the nearest ti. */
               lt_lst_pallet_height := (CEIL(ln_last_pallet_qty
                                             /l_item_info_rec.n_ti)
                                           * l_item_info_rec.n_case_height)
                                           + l_item_info_rec.n_skid_height;

               lt_std_pallet_height :=  (l_item_info_rec.n_case_height
                                        * l_item_info_rec.n_hi)
                                       + l_item_info_rec.n_skid_height;
            END IF;

            --Reset the current pallet count
            l_work_var_rec.n_current_pallet:= 0;

            --set the other values in work var record
            l_work_var_rec.n_total_qty        := lr_case_item.total_qty;
            l_work_var_rec.n_each_pallet_qty  := ln_each_pallet_qty;
            l_work_var_rec.n_last_pallet_qty  := ln_last_pallet_qty;
            l_work_var_rec.n_std_pallet_height:= lt_std_pallet_height;
            l_work_var_rec.n_lst_pallet_height:= lt_lst_pallet_height;
            l_work_var_rec.n_num_pallets      := ln_num_pallets;
            l_work_var_rec.v_no_splits        := l_item_info_rec.n_spc;
            l_work_var_rec.b_partial_pallet   := lb_partial_pallet;

            --reset the global variable
            pl_log.g_program_name     := 'PL_PALLET_LABEL2';

            --log item information
            lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||'SN/PO = '
            || i_po_number || ' ,prod id = '
                          || lr_case_item.prod_id || ',cust_pref_vendor = '
                          || lr_case_item.cust_pref_vendor
            || ',spc = ' || l_item_info_rec.n_spc || ',ti = '
            || l_item_info_rec.n_ti || ',hi = ' || l_item_info_rec.n_hi
            || ',case height = ' || l_item_info_rec.n_case_height;

            pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

            lv_msg_text := pl_putaway_utilities.PROGRAM_CODE || ' ,Num of pallets = '
                          || ln_num_pallets || ',partial pallet = ' || lv_ind;
            pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

            lv_msg_text := pl_putaway_utilities.PROGRAM_CODE || ' ,Each pallet qty = '
                          || ln_each_pallet_qty || ',last pallet qty = '
                          || ln_last_pallet_qty;
            pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

            lv_msg_text := pl_putaway_utilities.PROGRAM_CODE || ' ,Std pallet height = '
                         || lt_std_pallet_height || ',each pallet height = '
                         || lt_lst_pallet_height || 'skid height'
                         || l_item_info_rec.n_skid_height;
            pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

            --For each line item find a putaway slot
            lb_done := f_find_putaway_slot (l_po_info_rec,
                                            lr_case_item.prod_id,
                                            lr_case_item.cust_pref_vendor,
                                            lt_aging_days,
                                            l_item_info_rec,
                                            l_work_var_rec,
                                            l_syspar_var_rec);

            IF lb_done THEN
               lv_result := 'Entire qty has been putaway';
            ELSE
               lv_result := 'Entire qty could not be putaway';
            END IF;

            --reset the global variable
            pl_log.g_program_name     := 'PL_PALLET_LABEL2';
            lv_msg_text := 'Returned from find putaway for item '
                          || lr_case_item.prod_id
                          ||'and cpv ' || lr_case_item.cust_pref_vendor
                          ||'in SN/PO: ' ||i_po_number
                          ||' and ' || lv_result;
            pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);
            ln_count := line_item_curvar%ROWCOUNT;
         END LOOP;              -- End processing case line items
     -- END IF;

      IF ln_count = 0 THEN
         --LOG THE MESSAGE

         lv_msg_text := pl_putaway_utilities.PROGRAM_CODE
         ||',Table = "ERD,PM",Key = SN/PO: '|| i_po_number
         ||',Action = "FETCH",Message = '
         ||'"ORACLE failed to select quantity from case line items of SN/PO"';
         pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);
      END IF;
      --Commit the changes for entire SN/PO
      --COMMIT;
   ELSE
      --count =0
      --that means no details for that sn/po in erd table
      pl_putaway_utilities.gv_crt_message    := pl_putaway_utilities.FAILURE;
      --LOG THE MESSAGE
      lv_msg_text := pl_putaway_utilities.PROGRAM_CODE ||
                    ' ,Table = "ERD" ' ||
                    ' ,Key = SN/PO '||i_po_number
                    ||',Action = "SELECT", ' ||
                    ' Message = "SN/PO Detail is not available."';
      pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
   END IF;

        IF pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.SUCCESS
        THEN
           --Indicates no error in the processing
           o_error := FALSE;
           pl_putaway_utilities.gv_crt_message := 'Putaway Processed'
                                                  || ' Successfully';
           o_crt_message := pl_putaway_utilities.gv_crt_message;

        ELSIF pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.FAILURE
        THEN
           --Indicates  error in the processing
           o_error := TRUE;
           pl_putaway_utilities.gv_crt_message :='ERROR:Putaway cannot be '
                                                 || ' processed. ';
           pl_putaway_utilities.gv_crt_message := RPAD(pl_putaway_utilities.
                                                  gv_crt_message,80) ||
                                                  'REASON:-SN/PO details not ' ||
                                                 ' found in erd table for SN/PO: '
                                                 ||i_po_number;
           --acppzp testing
              pl_log.ins_msg('INFO',lv_pname,pl_putaway_utilities.gv_crt_message, NULL,sqlerrm);
           --acppzp testing
           o_crt_message := pl_putaway_utilities.gv_crt_message;
        END IF;


EXCEPTION
   WHEN OTHERS THEN
   o_error := true;
   IF pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.SUCCESS THEN
      pl_putaway_utilities.gv_crt_message := 'ERROR:- Putaway cannot be processed ';
      pl_putaway_utilities.gv_crt_message := RPAD(pl_putaway_utilities.
                                                  gv_crt_message,80)
                                             || 'REASON: ERROR IN : '
                                             || pl_putaway_utilities.
                                                gv_program_name
                                             || ' ,MESSAGE : '
                                             || sqlcode || sqlerrm;

   END IF;
   o_crt_message := pl_putaway_utilities.gv_crt_message;

   ROLLBACK;
END p_assign_putaway_slot;


/*-----------------------------------------------------------------------------
-- Function:
--    f_find_putaway_slot
--
-- Description:
-- This method finds putaway slot for one item in the SN/PO
-- Parameters:
--    i_po_info_rec               - relevnt details of SN/PO are passed thru this
                                    record
--    i_product_id                - product id of the item for which details
                                    are fetched
--    i_customer_preferred_vendor - customer preferred vendor for the selected
                                    product
--    i_aging_days                - aging days for the item, -1 if no aging
                                    required
--    i_item_related_info_rec     - all information pertaining to the product
                                    type is passed using this record
--    i_workvar_rec               - all info related to processing by the
                                    function not included in
                                    i_item_related_info_rec,
--                                  i_po_info_rec and spar_var_rec is
                                    included in this record
--    i_syspar_var_rec            - all the system parameters are passed
                                    using this record
-------------------------------------------------------------------------------*/
FUNCTION f_find_putaway_slot
  (i_po_info_rec               IN     PL_PUTAWAY_UTILITIES.T_PO_INFO,
   i_product_id                IN     pm.prod_id%TYPE,
   i_customer_preferred_vendor IN     pm.cust_pref_vendor%TYPE,
   i_aging_days                IN     aging_items.aging_days%TYPE,
   i_item_related_info_rec     IN OUT PL_PUTAWAY_UTILITIES.T_ITEM_RELATED_INFO,
   io_workvar_rec              IN OUT PL_PUTAWAY_UTILITIES.T_WORK_VAR,
   i_syspar_var_rec            IN     PL_PUTAWAY_UTILITIES.T_SYSPAR_VAR)
RETURN BOOLEAN
IS
lb_done              BOOLEAN;
lv_fname             VARCHAR2(30);

lt_rule_id           ZONE.RULE_ID%TYPE;
ln_num_next_zones    NUMBER;
ln_count             NUMBER := 0;
CURSOR c_each_zone (zone ZONE.ZONE_ID%TYPE)IS
SELECT next_zone_id
  FROM next_zones
 WHERE zone_id = zone
 ORDER BY sort ASC;

BEGIN
--reset the global variable
pl_log.g_program_name     := 'PL_PALLET_LABEL2';
lb_done           := FALSE;
io_workvar_rec.b_home_slot_flag := FALSE;
lv_fname          := 'f_find_putaway_slot';
--This will be used in the Exception message in assign putaway
pl_putaway_utilities.gv_program_name := lv_fname;


/**************
***************
  07/27/2015  Brian Bent  pl_putaway_utilities.F_Check_Home_Item now
              passed a record instead of individual fields.
IF pl_putaway_utilities.F_Check_Home_Item
                     (i_product_id,
                      i_customer_preferred_vendor,
                      i_aging_days,
                      i_item_related_info_rec.v_zone_id,
                      i_item_related_info_rec.v_last_ship_slot)= TRUE
   AND  i_item_related_info_rec.n_case_height <> 0
   AND  i_item_related_info_rec.n_case_height  IS NOT NULL
***************
**************/

  -- 
  -- 07/27/2015  Brian Bent
  -- Need the aging days in the item info record.
  -- 
  i_item_related_info_rec.aging_days := i_aging_days;

IF (pl_putaway_utilities.f_check_home_item(i_item_related_info_rec) = TRUE
   AND  i_item_related_info_rec.n_case_height <> 0
   AND  i_item_related_info_rec.n_case_height  IS NOT NULL)
 THEN
   --The item has a home location or the item is a floating item.
   --reset the global variable
   pl_log.g_program_name     := 'PL_PALLET_LABEL2';
   BEGIN
      SELECT rule_id INTO lt_rule_id
        FROM zone
       WHERE zone_id = i_item_related_info_rec.v_zone_id;
      IF lt_rule_id = 0 or lt_rule_id = 2 THEN --call general rule or floating
                                               --rule according to rule id
         pl_log.ins_msg ('DEBUG', lv_fname,
                        'General rule first time' ,NULL, SQLERRM);

         lb_done := pl_general_rule.f_general_rule
                                      (i_po_info_rec,
                                       i_product_id,
                                       i_customer_preferred_vendor,
                                       i_aging_days,
                                       i_item_related_info_rec,
                                       io_workvar_rec,
                                       i_syspar_var_rec,
                                       pl_putaway_utilities.FIRST,
                                       i_item_related_info_rec.v_zone_id);
         --reset the global variable
         pl_log.g_program_name     := 'PL_PALLET_LABEL2';

         IF lb_done = TRUE THEN
            pl_log.ins_msg ('DEBUG', lv_fname,
                            'returned from general rule first time '
                             || ' and finished' ,
                             NULL, SQLERRM);
         ELSIF lb_done = FALSE THEN
            pl_log.ins_msg ('DEBUG', lv_fname,
                             'returned from general rule first time '
                             || ' and not done' ,
                             NULL, SQLERRM);
         END IF;
      ELSIF lt_rule_id = 1 THEN
         pl_log.ins_msg ('DEBUG', lv_fname,
                         'Hi Rise Rule first time' ,NULL, SQLERRM);

         lb_done := pl_split_and_floating_putaway.f_floating_item_putaway
                                        (i_po_info_rec,
                                         i_product_id,
                                         i_customer_preferred_vendor,
                                         i_aging_days,
                                         i_item_related_info_rec,
                                         io_workvar_rec,
                                         i_syspar_var_rec,
                                         i_item_related_info_rec.v_zone_id);
         --reset the global variable
         pl_log.g_program_name     := 'PL_PALLET_LABEL2';

         IF lb_done = TRUE THEN
            pl_log.ins_msg ('DEBUG', lv_fname,
                            'returned from Hi Rise Rule first time and finished'
                            ,NULL, SQLERRM);
         ELSIF lb_done = FALSE THEN
            pl_log.ins_msg ('DEBUG', lv_fname,
                           'returned from Hi Rise Rule first time and not done'
                           ,NULL, SQLERRM);
         END IF;
      END IF ;--end call general rule or hi rise rule according to rule id
   EXCEPTION
      WHEN NO_DATA_FOUND  THEN
      BEGIN
      --Failed to select the rule id of the items putaway zone.
      pl_log.ins_msg ('WARN', lv_fname, 'TABLE=zone  KEY='
                     || i_item_related_info_rec.v_zone_id
                     || ' ACTION=SELECT  MESSAGE=Unable to get rule_id'
                     || 'for zone id '
                     ||i_item_related_info_rec.v_zone_id  ,NULL, SQLERRM);

      END;
      WHEN OTHERS THEN

      --rollback in assign_putaway_slot
      RAISE;
   END;
   IF lb_done = TRUE THEN
      RETURN lb_done;
   END IF;
   IF lb_done = FALSE THEN
      --If we are not done yet, find next zone to putaway
      --Get a list of all the zones specified as next zones for the
      --items primary put zone.
      --Only iterate num_next_zones times as specified in the area
      --record matching the area of the item.
      BEGIN
         ln_num_next_zones := 0;
         FOR r_each_zone IN c_each_zone(i_item_related_info_rec.v_zone_id)LOOP

            IF lb_done = TRUE
               OR ln_num_next_zones = i_item_related_info_rec.n_num_next_zones
            THEN
               EXIT;
            END IF;
            BEGIN
               SELECT rule_id INTO lt_rule_id
                 FROM zone
                WHERE zone_id = r_each_zone.next_zone_id;

               IF  lt_rule_id = 0 or lt_rule_id = 2 THEN
                  pl_log.ins_msg ('DEBUG', lv_fname,
                                  'general rule second time' ,
                                  NULL, SQLERRM);
                   lb_done := pl_general_rule.f_general_rule
                                                 (i_po_info_rec,
                                                  i_product_id,
                                                  i_customer_preferred_vendor,
                                                  i_aging_days,
                                                  i_item_related_info_rec,
                                                  io_workvar_rec,
                                                  i_syspar_var_rec,
                                                  pl_putaway_utilities.SECOND,
                                                  r_each_zone.next_zone_id);
                  --reset the global variable
                  pl_log.g_program_name     := 'PL_PALLET_LABEL2';
                  IF lb_done = TRUE THEN
                     pl_log.ins_msg ('DEBUG', lv_fname,
                                     'returned from general rule and finished' ,
                                     NULL, SQLERRM);
                  ELSIF lb_done = FALSE THEN
                     pl_log.ins_msg ('DEBUG', lv_fname,
                                     'returned from general rule and not done' ,
                                     NULL, SQLERRM);
                  END IF;
               ELSIF lt_rule_id = 1 THEN
                  pl_log.ins_msg ('DEBUG', lv_fname,
                                  'Hi Rise Rule first time' ,NULL, SQLERRM);

                lb_done := pl_split_and_floating_putaway.f_floating_item_putaway
                                        (i_po_info_rec,
                                         i_product_id,
                                         i_customer_preferred_vendor,
                                         i_aging_days,
                                         i_item_related_info_rec,
                                         io_workvar_rec,
                                         i_syspar_var_rec,
                                         r_each_zone.next_zone_id);
                --reset the global variable
                pl_log.g_program_name     := 'PL_PALLET_LABEL2';

                  IF lb_done = TRUE THEN
                     pl_log.ins_msg ('DEBUG', lv_fname,
                                     'returned from Hi Rise Rule  and finished' ,
                                     NULL, SQLERRM);
                  ELSIF lb_done = FALSE THEN
                     pl_log.ins_msg ('DEBUG',lv_fname,
                                     'returned from Hi Rise Rule  and not done' ,
                                     NULL, SQLERRM);
                  END IF;
               END IF;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
               BEGIN
                  --Failed to select the rule id of the items putaway zone.
                  pl_log.ins_msg ('WARN', lv_fname, 'TABLE=zone  KEY='
                                  || r_each_zone.next_zone_id ||
                                  ' ACTION=SELECT'||
                                  '  MESSAGE=Unable to get rule_id for zone id'
                                  || r_each_zone.next_zone_id,NULL,SQLERRM);

               END;
               WHEN OTHERS THEN

                  --rollback in assign_putaway_slot
               RAISE;
            END;
            ln_num_next_zones := ln_num_next_zones + 1;
            ln_count := c_each_zone%ROWCOUNT;
         END LOOP;--for num_next_zones

         IF ln_count = 0 THEN
            pl_log.ins_msg ('WARN', lv_fname, 'TABLE=next_zones  KEY='
                            ||i_item_related_info_rec.v_zone_id||
                            'ACTION=fetch MESSAGE=ORACLE: No next zones for zone.'
                            || i_item_related_info_rec.v_zone_id,NULL, SQLERRM);
         END IF;

         IF lb_done = TRUE THEN
            RETURN lb_done;
         END IF;
      END;
      IF  ln_num_next_zones = i_item_related_info_rec.n_num_next_zones THEN
          pl_log.ins_msg ('WARN', lv_fname, 'TABLE=next_zones  KEY='
                          || i_item_related_info_rec.v_zone_id
                          || ' ACTION=VALIDATION '||
                          'MESSAGE=Maximum number of next zones reached.',
                          NULL, SQLERRM);

      END IF;
   END IF;-- if not done go to next zone
ELSE
   pl_log.g_program_name     := 'PL_PALLET_LABEL2';
   IF i_item_related_info_rec.n_case_height = 0
      OR i_item_related_info_rec.n_case_height IS NULL
   THEN
      pl_log.ins_msg ('WARN', lv_fname, 'TABLE=PM  KEY=SN/PO '
                     || i_po_info_rec.v_erm_id
                     || ' ACTION=VALIDATION MESSAGE= '
                     ||'Item Location will be <*> '
                     ||'Missing case dimensions for prodid: '
                     ||i_product_id,
                     NULL, 'Could not put away item');
   END IF;
END IF; --if no home slot
--If we can not find putaway slot using above searching logic
--then generate blank pallet label

IF  lb_done = FALSE THEN
   pl_log.ins_msg ('WARN', lv_fname, 'TABLE=PM  KEY=SN/PO '
                     || i_po_info_rec.v_erm_id
                     || ',Prod id '
                      || i_product_id || ',cpv '|| i_customer_preferred_vendor
                      || ' ACTION=VALIDATION MESSAGE=Item loc will be <*> ',
                      NULL, 'Could not put away item');

   FOR counter IN io_workvar_rec.n_current_pallet..(io_workvar_rec.n_num_pallets - 1)
   LOOP
      IF counter = (io_workvar_rec.n_num_pallets  - 1)
         AND io_workvar_rec.b_partial_pallet =TRUE THEN
         io_workvar_rec.n_each_pallet_qty := io_workvar_rec.n_last_pallet_qty;
      END IF;
      pl_putaway_utilities.p_insert_table(i_product_id,
                              i_customer_preferred_vendor,
                              '*',
                              pl_putaway_utilities.ADD_NO_INV,
                              i_po_info_rec.v_erm_id ,
                              i_aging_days,
                              i_syspar_var_rec.v_clam_bed_tracked_flag,
                              i_item_related_info_rec ,
                              io_workvar_rec);
   END LOOP;
END IF;--if not done

RETURN lb_done;

END f_find_putaway_slot;
/*-----------------------------------------------------------------------
   -- Procedure:
   --   f_find_damage_zone_location
   --
   -- Description:
   --    This method finds a reserve slot in the default damage zone
   --    for the damaged items pallet.
   --
   -- Parameters:
   --    i_po_number              - Purchase order number.
   --    i_prod_id                - product id of the item for which details
                                  - are fetched
   --    i_cust_pref_vendor       - customer preferred vendor for the selected
   --                             - product
   --    i_uom                    - Unit of measurement
   --                             - (0 for Cases,1 for splits)
   --    i_aging_days             - Aging days forthe product
   --    i_clam_bed_flag          - Flag for clam_bed tracked items
   --    i_item_related_info_rec  - all information pertaining to the product
                                    type is passed using this record
   --    i_workvar_rec            - all info related to processing by the
                                    function not included in
                                    i_item_related_info_rec,
   --
   -- Called From
   --    p_reprocess
   -- Exceptions raised:
   --
---------------------------------------------------------------------*/
FUNCTION f_find_damage_zone_locations
                ( i_prod_id                IN      pm.prod_id%TYPE,
                  i_cust_pref_vendor       IN      pm.cust_pref_vendor%TYPE,
                  i_erm_id                 IN      erm.erm_id%TYPE,
                  i_uom                    IN      erd.uom%TYPE,
                  i_aging_days             IN      aging_items.aging_days%TYPE,
                  i_clam_bed_flag          IN      sys_config.config_flag_val%TYPE,
                  io_item_related_info_rec IN OUT  pl_putaway_utilities.t_item_related_info,
                  io_workvar_rec           IN OUT  pl_putaway_utilities.t_work_var)

RETURN BOOLEAN
IS
lb_done              BOOLEAN := FALSE;
lt_pallet_id         putawaylst.pallet_id%TYPE :='';
lt_dest_loc          putawaylst.dest_loc%TYPE  :='';
lt_avl_height        loc.available_height%TYPE := 0;
lv_msg_text                VARCHAR2(500);
lv_pname                   VARCHAR2(50) := 'f_find_damage_zone_locations';
BEGIN
   IF i_uom = 1 THEN

         BEGIN
            SELECT logi_loc
            INTO lt_dest_loc
            FROM
            (SELECT l.logi_loc
            FROM loc l,pm m,swms_areas s ,lzone z,zone e
            WHERE m.prod_id = i_prod_id
            AND   s.area_code = m.area
            AND   z.zone_id = s.def_dmg_zone
            AND   e.zone_id = z.zone_id
            AND   e.zone_type = 'PUT'
            AND   l.logi_loc = z.logi_loc
            AND   l.status = 'AVL'
            AND   l.perm = 'N'
            AND   l.pallet_type = io_item_related_info_rec.v_pallet_type
            ORDER BY l.available_height)
            WHERE rownum = 1;
           lb_done := TRUE;
          EXCEPTION
            WHEN OTHERS THEN
               lb_done := FALSE;
               lv_msg_text:='Selection of destination location in damage zone for prod_id '
               ||i_prod_id||' failed';
               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
         END;

   ELSE
         BEGIN
            SELECT logi_loc
            INTO lt_dest_loc
            FROM
            (SELECT l.logi_loc
            FROM loc l,pm m,swms_areas s ,lzone z,zone e
            WHERE m.prod_id = i_prod_id
            AND   s.area_code = m.area
            AND   z.zone_id = s.def_dmg_zone
            AND   e.zone_id = z.zone_id
            AND   e.zone_type = 'PUT'
            AND   l.logi_loc = z.logi_loc
            AND   l.status = 'AVL'
            AND   l.perm = 'N'
            AND   l.pallet_type = io_item_related_info_rec.v_pallet_type
            AND   l.available_height >= io_workvar_rec.n_std_pallet_height
            ORDER BY l.available_height)
            WHERE rownum = 1;
            lb_done := TRUE;
         EXCEPTION
            WHEN OTHERS THEN
               lb_done := FALSE;
               lv_msg_text:='Selection of destination location in damage zone for prod_id '
               ||i_prod_id||' failed';

               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
         END;
   END IF;
               pl_putaway_utilities.p_insert_table(i_prod_id,
                                    i_cust_pref_vendor,
                                    lt_dest_loc,
                                    pl_putaway_utilities.ADD_RESERVE,
                                    i_erm_id ,
                                    i_aging_days,
                                    i_clam_bed_flag,
                                    io_item_related_info_rec ,
                                    io_workvar_rec);

RETURN lb_done;
EXCEPTION
   WHEN OTHERS THEN
      lb_done := FALSE;
      lv_msg_text:='Retrieval of damaged pallet from putawaylst for SN/PO: '
                        || i_erm_id||' prod_id '||i_prod_id||'failed';

      pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);



RETURN lb_done;

END f_find_damage_zone_locations;

/*-----------------------------------------------------------------------
   -- Procedure:
   --    p_reprocess
   --
   -- Description:
   --    This method reprocesses the putaway for extended SN/POS
   --
   -- Parameters:
   --    i_po_number              - Purchase order number/shipment number.
   --    i_prod_id                - product id of the item for which details
                                  - are fetched
   --    i_cust_pref_vendor       - customer preferred vendor for the selected
   --                             - product
   --    i_uom                    - Unit of measurement
   --                             - (0 for Cases,1 for splits)
   --    i_total_qty              - Qty of Product
   --    o_pallet_id              - Array of pallet ids,which will
                                  - be used by pro*c program for printing
                                  - the pallet labels.
   --    o_error                  - Boolean Flag
   --                             - TRUE:In case of error
   --                             - FALSE:No Error
   --    o_crt_message            - Message for displaying on
   --                             - CRT screens.
   --
   -- Called From
   --    one_pallet_label.pc
   -- Exceptions raised:
   --
---------------------------------------------------------------------*/
PROCEDURE p_reprocess(i_po_number        IN  erm.erm_id%TYPE,
                       i_prod_id          IN  pm.prod_id%TYPE,
                       i_cust_pref_vendor IN  pm.cust_pref_vendor%TYPE,
                       i_uom              IN  erd.uom%TYPE,
                       i_dmg_ind          IN  VARCHAR2,
                       o_error            OUT BOOLEAN,
                       i_total_qty        IN  erd.qty%TYPE,
                       o_pallet_id        OUT pl_putaway_utilities.t_pallet_id,
                       o_crt_message      OUT VARCHAR2)
IS

   lb_partial_pallet          BOOLEAN;
   lb_done                    BOOLEAN := FALSE;


   lv_msg_text                VARCHAR2(500);
   lv_pname                   VARCHAR2(50) := 'p_reprocess';

   ln_num_pallets             NUMBER;
   lv_location                putawaylst.dest_loc%TYPE :='';

   --assign these variables to work var rec
   ln_each_pallet_qty         NUMBER(10,4);
   ln_last_pallet_qty         NUMBER(10,4);

   lt_def_dmg_zone            zone.zone_id%TYPE :='';
   ln_lst_pallet_height       inv.pallet_height%TYPE;
   ln_std_pallet_height       inv.pallet_height%TYPE;
   lt_aging_days              aging_items.aging_days%TYPE;
   lt_erm_type                erm.erm_type%TYPE;
   lt_wh_id                   erm.warehouse_id%TYPE;
   lt_to_wh_id                erm.to_warehouse_id%TYPE;

   l_syspar_var_rec           pl_putaway_utilities.t_syspar_var;
   l_po_info_rec              pl_putaway_utilities.t_po_info;
   l_item_info_rec            pl_putaway_utilities.t_item_related_info;
   l_work_var_rec             pl_putaway_utilities.t_work_var;


  BEGIN
       --Setting the global variables
      --reset the global variable
      pl_log.g_program_name     := 'PL_PALLET_LABEL2';
      --This will be used in the Exception message in assign putaway
      pl_putaway_utilities.gv_program_name := lv_pname;
      pl_putaway_utilities.gv_crt_message    := pl_putaway_utilities.SUCCESS;

        BEGIN
           SELECT  erm_type, warehouse_id, to_warehouse_id
             INTO   lt_erm_type, lt_wh_id, lt_to_wh_id
             FROM erm
            WHERE erm_id = i_po_number;
            --SET THE RECORD TYPE SN/PO INFO
            l_po_info_rec.v_erm_id   := i_po_number;
            l_po_info_rec.v_erm_type := lt_erm_type;
            l_po_info_rec.v_wh_id    := lt_wh_id;
            l_po_info_rec.v_to_wh_id := lt_to_wh_id;
       EXCEPTION
            WHEN NO_DATA_FOUND THEN
                --LOG THE MESSAGE
               lv_msg_text := pl_putaway_utilities.PROGRAM_CODE
                             ||' ,TABLE = "ERM"'
                             ||' ,KEY = SN/PO '|| i_po_number
                             ||',ACTION = "SELECT", '
                             ||'MESSAGE = "Oracle failed to select SN/PO Info"';
               pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
      END;

      pl_putaway_utilities.p_get_syspar(l_syspar_var_rec,
                                          i_po_number);

        --set the reprocess flag
        pl_putaway_utilities.gb_reprocess := TRUE;

        --Get all the data needed for the product from the pm table.
        --retrieves all item related info in record type

        pl_putaway_utilities.p_get_item_info(i_prod_id,
                                             i_cust_pref_vendor,
                                             l_item_info_rec);


---acppzp to retrieve Ti,Hi,pallet_type from erd_lpn if it is a SN
        pl_putaway_utilities.p_get_erm_info(i_po_number,i_prod_id,
                                             i_cust_pref_vendor,
                                             l_item_info_rec);

        --Get aging days for item that needs to be aged
        lt_aging_days := pl_putaway_utilities.f_retrieve_aging_items
                                               (i_prod_id,
                                                i_cust_pref_vendor);

        IF i_uom = 1 THEN
        --acppzp OSD changes
           IF i_dmg_ind = 'DMG' THEN
              l_work_var_rec.v_no_splits        := l_item_info_rec.n_spc;
              BEGIN
                    SELECT logi_loc
                    INTO lv_location
                    FROM
                    (SELECT c.logi_loc
                    FROM loc c,lzone l,zone e
                    WHERE c.true_slot_height = 999
                    AND c.pallet_type = l_item_info_rec.v_pallet_type
                    AND c.status = 'AVL'
                    AND l.logi_loc = c.logi_loc
                    AND e.zone_id = l.zone_id
                    AND e.zone_type = 'PUT'
                    ORDER BY c.available_height)
                    WHERE rownum = 1;
              EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       lv_location := '';

                    WHEN OTHERS THEN
                  --LOG THE ERROR
                       lv_msg_text:='Selection of reserve location for damaged pallet for SN/PO: '
                       ||i_po_number||' failed';
                       pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

                        RAISE;
              END;
                 l_work_var_rec.v_dmg_ind   :='DMG';
                 l_work_var_rec.n_each_pallet_qty := i_total_qty;
              IF lv_location IS NOT NULL THEN
                 pl_putaway_utilities.p_insert_table(i_prod_id,
                                  i_cust_pref_vendor,
                                  lv_location,
                                  pl_putaway_utilities.ADD_RESERVE,
                                  i_po_number,
                                  lt_aging_days,
                                  l_syspar_var_rec.v_clam_bed_tracked_flag,
                                  l_item_info_rec,
                                  l_work_var_rec);
              ELSIF lv_location IS  NULL THEN
                 BEGIN
                    SELECT def_dmg_zone
                    INTO   lt_def_dmg_zone
                    FROM swms_areas
                    WHERE area_code IN
                    (SELECT area
                     FROM pm
                     WHERE prod_id = i_prod_id);

                    l_work_var_rec.v_dmg_ind   :='DMG';
                    l_work_var_rec.n_each_pallet_qty := i_total_qty;
                    lb_done := f_find_damage_zone_locations(i_prod_id,
                                    i_cust_pref_vendor,
                                    i_po_number,
                                    i_uom,
                                    lt_aging_days,
                                    l_syspar_var_rec.v_clam_bed_tracked_flag,
                                    l_item_info_rec,
                                    l_work_var_rec);

                    IF lb_done =FALSE THEN
                         lv_msg_text:='Selection of location for damaged pallet for SN/PO: '
                              || i_po_number||' failed';
                         pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
                     END IF;
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;

                    WHEN OTHERS THEN
                   --LOG THE ERROR
                       lv_msg_text:='Selection of default zone for damaged pallet for SN/PO: '
                              || i_po_number||' failed';
                       pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
                       RAISE;
                 END;
              END IF;
           ELSE
              lb_done := pl_split_and_floating_putaway.f_split_find_putaway_slot
                                              (l_po_info_rec,
                                               i_prod_id,
                                               i_cust_pref_vendor,
                                               lt_aging_days,
                                               i_total_qty,
                                               l_item_info_rec,
                                               l_work_var_rec,
                                               l_syspar_var_rec);
           END IF;
        --acppzp OSD changes


           --reset the global variable
           pl_log.g_program_name     := 'PL_PALLET_LABEL2';
        ELSE
           BEGIN
              --reset the global variable
              pl_log.g_program_name     := 'PL_PALLET_LABEL2';
              SELECT MIN(p.catch_wt) INTO l_item_info_rec.v_catch_wt_trk
                FROM putawaylst p
               WHERE p.catch_wt IN ('Y','C')
                 AND p.prod_id = i_prod_id
                 AND p.cust_pref_vendor = i_cust_pref_vendor
                 AND p.rec_id = i_po_number;

           EXCEPTION
              WHEN NO_DATA_FOUND THEN
                --LOG THE ERROR
                lv_msg_text:='Selection of catch weight failed for SN/PO: '
                             || i_po_number;

                pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

           END;
                --Calculate number of pallets for the quantity
                ln_num_pallets := TRUNC((i_total_qty/(l_item_info_rec.n_spc))
                                       /(l_item_info_rec.n_ti
                                         *l_item_info_rec.n_hi));
                --Check for partial pallet, add one to num_pallets
                --and set flag appropriately

                IF MOD((i_total_qty/(l_item_info_rec.n_spc)),
                        (l_item_info_rec.n_ti*l_item_info_rec.n_hi)) <> 0 THEN
                    ln_num_pallets    := ln_num_pallets + 1;
                    lb_partial_pallet := TRUE;
                ELSE
                    lb_partial_pallet := FALSE;
                END IF;

                IF ln_num_pallets = 1 THEN

                    ln_each_pallet_qty := (i_total_qty
                                                /(l_item_info_rec.n_spc));
                    ln_last_pallet_qty := ln_each_pallet_qty;
                    /*A partial pallet will have the height rounded up
                    to the nearest ti.*/
                    ln_lst_pallet_height:= (CEIL(ln_last_pallet_qty
                                                /l_item_info_rec.n_ti)
                                           * l_item_info_rec.n_case_height)
                                          + l_item_info_rec.n_skid_height;
                    ln_std_pallet_height := ln_lst_pallet_height;
                ELSE
                    --no of pallets more than one

                    ln_each_pallet_qty := l_item_info_rec.n_ti
                                         * l_item_info_rec.n_hi;

                    IF lb_partial_pallet THEN
                       ln_last_pallet_qty := (i_total_qty -
                                             ((ln_num_pallets-1)
                                              * ln_each_pallet_qty
                                              * l_item_info_rec.n_spc))
                                             /l_item_info_rec.n_spc;
                    ELSE
                       ln_last_pallet_qty := ln_each_pallet_qty;
                    END IF;


                    ln_lst_pallet_height := (CEIL(ln_last_pallet_qty
                                                /l_item_info_rec.n_ti)
                                             * l_item_info_rec.n_case_height)
                                           + l_item_info_rec.n_skid_height;

                    ln_std_pallet_height :=  (l_item_info_rec.n_case_height
                                             * l_item_info_rec.n_hi)
                                            + l_item_info_rec.n_skid_height;
                END IF;

                  --Reset the current pallet count
                  l_work_var_rec.n_current_pallet:= 0;
                  --set the other values in work var record
                  l_work_var_rec.n_total_qty        := i_total_qty;
                  l_work_var_rec.n_each_pallet_qty  := ln_each_pallet_qty;
                  l_work_var_rec.n_last_pallet_qty  := ln_last_pallet_qty;
                  l_work_var_rec.n_std_pallet_height:= ln_std_pallet_height;
                  l_work_var_rec.n_lst_pallet_height:= ln_lst_pallet_height;
                  l_work_var_rec.n_num_pallets      := ln_num_pallets;
                  l_work_var_rec.v_no_splits        := l_item_info_rec.n_spc;
                  l_work_var_rec.b_partial_pallet   := lb_partial_pallet;
                  l_work_var_rec.n_seq_no := 0;

           --acppzp OSD changes
           IF i_dmg_ind = 'DMG' THEN
                  l_work_var_rec.n_each_pallet_qty := i_total_qty;
                   l_work_var_rec.v_dmg_ind   :='DMG';

              BEGIN
                    SELECT logi_loc
                    INTO lv_location
                    FROM
                    (SELECT c.logi_loc
                    FROM loc c,lzone l,zone e
                    WHERE c.true_slot_height = 999
                    AND c.pallet_type = l_item_info_rec.v_pallet_type
                    AND c.status = 'AVL'
                    AND l.logi_loc = c.logi_loc
                    AND e.zone_id = l.zone_id
                    AND e.zone_type = 'PUT'
                    ORDER BY c.available_height)
                    WHERE rownum = 1;
              EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                       lv_location := '';
                    WHEN OTHERS THEN
                  --LOG THE ERROR
                       lv_msg_text:='Selection of reserve location for damaged pallet for SN/PO: '
                                 || i_po_number||' failed';
                       pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);

                        RAISE;
              END;

              IF lv_location IS NOT NULL THEN

           pl_putaway_utilities.p_insert_table(i_prod_id,
                                    i_cust_pref_vendor,
                                    lv_location,
                                    pl_putaway_utilities.ADD_RESERVE,
                                    i_po_number,
                                    lt_aging_days,
                                    l_syspar_var_rec.v_clam_bed_tracked_flag,
                                    l_item_info_rec,
                                    l_work_var_rec);


              ELSIF lv_location IS NULL THEN
                BEGIN
                   SELECT def_dmg_zone
                   INTO   lt_def_dmg_zone
                   FROM swms_areas
                   WHERE area_code IN
                   (SELECT area
                    FROM pm
                    WHERE prod_id = i_prod_id);

                   IF lt_def_dmg_zone IS NOT NULL THEN

                      lb_done := f_find_damage_zone_locations(i_prod_id,
                                    i_cust_pref_vendor,
                                    i_po_number,
                                    i_uom,
                                    lt_aging_days,
                                    l_syspar_var_rec.v_clam_bed_tracked_flag,
                                    l_item_info_rec,
                                    l_work_var_rec);
                      IF lb_done = FALSE THEN
                         lv_msg_text:='Selection of location for damaged pallet for SN/PO: '
                              || i_po_number||' failed';
                         pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
                      END IF;
                  END IF;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN

                     lb_done:= f_find_putaway_slot (l_po_info_rec,
                                           i_prod_id,
                                           i_cust_pref_vendor,
                                           lt_aging_days,
                                           l_item_info_rec,
                                           l_work_var_rec,
                                           l_syspar_var_rec);

                  WHEN OTHERS THEN
                  --LOG THE ERROR
                     lv_msg_text:='Selection of default zone for damaged pallet for SN/PO: '
                               || i_po_number||' failed';
                     pl_log.ins_msg('WARN',lv_pname,lv_msg_text,NULL,sqlerrm);
                     RAISE;
                END;
              END IF;
           ELSE
            --acppzp OSD changes  end
               lb_done:= f_find_putaway_slot (l_po_info_rec,
                                           i_prod_id,
                                           i_cust_pref_vendor,
                                           lt_aging_days,
                                           l_item_info_rec,
                                           l_work_var_rec,
                                           l_syspar_var_rec);


                lv_msg_text:= pl_putaway_utilities.PROGRAM_CODE
                 ||' ,TABLE = "ERD,PM",KEY = SN/PO '||i_po_number
                 ||',ACTION = "FETCH",'
                 ||'MESSAGE = "ORACLE failed to select quantity from case'
                 ||' line items of SN/PO"';
                pl_log.ins_msg('INFO',lv_pname,lv_msg_text,NULL,sqlerrm);

           END IF;

        END IF;
         --Indicates no error in the processing
         o_error:= false;
         --store the pallet ids in the array which will be used
         --by proc*c program for printing pallet labels
         o_pallet_id := pl_putaway_utilities.gtbl_pallet_id;
         --Commit the processing
         pl_log.ins_msg('INFO',lv_pname,'desc loc committed',NULL,sqlerrm);
       --  COMMIT;

         IF pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.SUCCESS
         THEN
            pl_putaway_utilities.gv_crt_message := 'Reprocess processed '
                                                    || ' Successfully';
            o_crt_message := pl_putaway_utilities.gv_crt_message;
         END IF;
EXCEPTION
 WHEN OTHERS THEN
    o_error := true;
    IF pl_putaway_utilities.gv_crt_message = pl_putaway_utilities.SUCCESS THEN
       pl_putaway_utilities.gv_crt_message := 'ERROR:Reprocess '
                                              ||'cannot be processed ';
       pl_putaway_utilities.gv_crt_message := RPAD(pl_putaway_utilities.
                                                   gv_crt_message,80)
                                              || 'REASON: ERROR IN : '
                                              || pl_putaway_utilities.
                                                 gv_program_name
                                              || ' ,MESSAGE : '
                                              || sqlcode || sqlerrm;
    END IF;
   o_crt_message := pl_putaway_utilities.gv_crt_message;

   ROLLBACK;
END p_reprocess;


BEGIN
  --this is used for initialising global variables once
  --global variables set for logging the errors in swms_log table
     pl_log.g_application_func := 'RECEIVING AND PUTAWAY';

END pl_pallet_label2;
/

