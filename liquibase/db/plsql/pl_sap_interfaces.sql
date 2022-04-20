CREATE OR REPLACE PACKAGE swms.pl_sap_interfaces
AS
   -- sccs_id=@(#) src/schema/plsql/pl_sap_interfaces.sql,
   -----------------------------------------------------------------------------
   -- Package Name:
   --   pl_sap_interfaces
   --
   -- Description:
   --    Processing of Stored procedures and table functions for SAP OPCO using staging tables.
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- -----------------------------------------------------
   --    12/25/09 ctnxa000 Created.
   --    02/08/12 sray0453 CRQ32214- SCI014 performance improvement.
   --                      Removed SWMS_OR_SP as Direct insert would be done by PI.
   --                      The logic for frz_special,dry_special,clr_special are 
   --                      moved to swmsororacle.pc program. 
   --    03/12/12 issxt179 Add in_load_no to SWMS_PO_SCH_STATUS_CHG for Food Safety project
   --    06/20/12 sray0453 CRQ37911 - PI will do direct insert into staging tables
   --                      for all inbound interfaces. Stored procedures are removed
   --                      from this package.  
   --   05/09/13 mdev3739 CRQ45458 Added erm_type variable for returning in the swms_pw_func.      
   -----------------------------------------------------------------------------
   -- Table Function for SCI003-C and SCI006-C
    FUNCTION swms_ia_func(in_bypass_flag IN Varchar2) RETURN SAP_IA_OBJECT_TABLE;

   -- Table Function for SCI004-C
    FUNCTION swms_rt_func RETURN SAP_RT_OBJECT_TABLE;

       -- Table Function for SCI016-C
    FUNCTION swms_ow_func RETURN SAP_OW_OBJECT_TABLE;

    FUNCTION swms_cr_func RETURN SAP_CR_OBJECT_TABLE;

    -- Table  Function for SCI025-C
    FUNCTION swms_wh_func RETURN SAP_WH_OBJECT_TABLE;

    -- Table  Function for SCI069-C
    FUNCTION swms_lm_func(in_bypass_flag IN varchar2) RETURN SAP_LM_OBJECT_TABLE;

    -- Table  Function for SCI098-C
    FUNCTION swms_container_func RETURN SAP_CONTAINER_OBJECT_TABLE;

    -- Table  Function for SCI087-C
    FUNCTION swms_equip_func RETURN SAP_EQUIP_OBJECT_TABLE;
    
    -- Table  Function for PRI055-C
    FUNCTION swms_pw_func RETURN SAP_PW_OBJECT_TABLE;

END pl_sap_interfaces;
/

--*************************************************************************
--Package Body

--*************************************************************************

CREATE OR REPLACE PACKAGE BODY swms.pl_sap_interfaces
AS

---------------------------------------------------------------------------
-- Private Modules
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_ia_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_IA_OUT
--     and sends the resultset data for Goods receipts interface(SCI003) to
--     SAP through PI middleware.
--
-- Parameters:
--      None
--
-- Return Values:
--    SAP_IA_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/28/10 ykri0358 Created.
--    10/21/10 sray0453 CR4054 - Batch_id included to handle reprocessing.
----------------------------------------------------------------------------

    FUNCTION swms_ia_func(in_bypass_flag IN varchar2) RETURN SAP_IA_OBJECT_TABLE
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        l_sap_ia_object_table SAP_IA_OBJECT_TABLE := SAP_IA_OBJECT_TABLE();
        message VARCHAR2(70);
        lv_batch_id Number(8);
        batch_id_resend number(8);
        lv_loop Number;
      BEGIN
            IF in_bypass_flag = 'N' THEN
            update SAP_IA_OUT set record_status='N' where record_status = 'Q';
            COMMIT;
            END IF;

            select min(batch_id) into batch_id_resend from SAP_IA_OUT where record_status = 'N' and batch_id is not null order by sequence_number;

            IF batch_id_resend is not null  THEN
                lv_batch_id := batch_id_resend;


                FOR i_index IN (SELECT batch_id, sequence_number, trans_type, erm_id, prod_id, cust_pref_vendor ,reason_code,
                            item_seq, uom,  qty_expected_sign,  qty_expected,
                            qty_sign,  qty,  weight_sign,  weight, order_id,  new_status,
                            warehouse_id,  mfg_date,  mfg_date_trk,  exp_date, exp_date_trk,
                            pallet_id, trans_id, trailer_temp, item_temp, rdc_no,
                            sn_no,  rec_date,  erm_type, erm_line_id, user_id,home_reserve_flag
                            FROM SAP_IA_OUT
                            WHERE bypass_flag = in_bypass_flag and record_status = 'N' and batch_id = batch_id_resend
                            ORDER BY sequence_number)
               LOOP
                    update SAP_IA_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                    COMMIT;

                    message := 'SAP_IA_OUT:ERROR:PO#'||i_index.erm_id ||':ITEM:'||i_index.prod_id  ||':SEQ NO:'||i_index.sequence_number;
                    l_sap_ia_object_table.extend;
                    l_sap_ia_object_table(l_sap_ia_object_table.COUNT) := SAP_IA_OBJECT(lv_batch_id, in_bypass_flag, i_index.trans_type, i_index.erm_id, i_index.prod_id,
                                                                  i_index.cust_pref_vendor, i_index.reason_code, i_index.item_seq, i_index.uom,
                                                                  i_index.qty_expected_sign, i_index.qty_expected, i_index.qty_sign, i_index.qty,
                                                                  i_index.weight_sign, i_index.weight, i_index.order_id, i_index.new_status,
                                                                  i_index.warehouse_id, i_index.mfg_date, i_index.mfg_date_trk, i_index.exp_date,
                                                                  i_index.exp_date_trk, i_index.pallet_id,  i_index.trans_id, i_index.trailer_temp,
                                                                  i_index.item_temp, i_index.rdc_no, i_index.sn_no,
                                                                  i_index.rec_date, i_index.erm_type, i_index.erm_line_id, replace(i_index.user_id,'OPS$',NULL),
                                                                  i_index.home_reserve_flag);
               END LOOP;


            ELSE

               lv_loop := 0;
               FOR i_index IN (SELECT batch_id, sequence_number, trans_type, erm_id, prod_id, cust_pref_vendor ,reason_code,
                            item_seq, uom,  qty_expected_sign,  qty_expected,
                            qty_sign,  qty,  weight_sign,  weight, order_id,  new_status,
                            warehouse_id,  mfg_date,  mfg_date_trk,  exp_date, exp_date_trk,
                            pallet_id, trans_id, trailer_temp, item_temp, rdc_no,
                            sn_no,  rec_date,  erm_type, erm_line_id, user_id,home_reserve_flag
                            FROM SAP_IA_OUT
                            WHERE bypass_flag = in_bypass_flag and record_status = 'N' and batch_id is null
                            ORDER BY sequence_number)

                LOOP

                  IF lv_loop = 0 THEN

                     SELECT max(batch_id) into lv_batch_id from SAP_IA_OUT;

                      IF lv_batch_id is NULL THEN
                            lv_batch_id := 1;
                      ELSE
                            lv_batch_id := lv_batch_id + 1;
                      END IF;
                      lv_loop := 1;
                   END IF;


                  update  SAP_IA_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                  and batch_id is null;
                  COMMIT;

                  message := 'SAP_IA_OUT:ERROR:PO#'||i_index.erm_id ||':ITEM:'||i_index.prod_id  ||':SEQ NO:'||i_index.sequence_number;

                  l_sap_ia_object_table.extend;
                  l_sap_ia_object_table(l_sap_ia_object_table.COUNT) := SAP_IA_OBJECT(lv_batch_id, in_bypass_flag, i_index.trans_type, i_index.erm_id, i_index.prod_id,
                                                                  i_index.cust_pref_vendor, i_index.reason_code, i_index.item_seq, i_index.uom,
                                                                  i_index.qty_expected_sign, i_index.qty_expected, i_index.qty_sign, i_index.qty,
                                                                  i_index.weight_sign, i_index.weight, i_index.order_id, i_index.new_status,
                                                                  i_index.warehouse_id, i_index.mfg_date, i_index.mfg_date_trk, i_index.exp_date,
                                                                  i_index.exp_date_trk, i_index.pallet_id,  i_index.trans_id, i_index.trailer_temp,
                                                                  i_index.item_temp, i_index.rdc_no, i_index.sn_no,
                                                                  i_index.rec_date, i_index.erm_type, i_index.erm_line_id, replace(i_index.user_id,'OPS$',NULL),
                                                                  i_index.home_reserve_flag);
               END LOOP;
            END IF;

            RETURN l_sap_ia_object_table;

    EXCEPTION

    WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', 'SWMS_IA_FUNC', message, SQLCODE, SQLERRM,'RECEIVING','PL_SAP_INTERFACES','Y');
END swms_ia_func;

-- Table Function for SCI004-C
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_rt_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_RT_OUT
--     and sends the resultset data for Manifest return Interface(SCI004-C)
--     SAP through PI middleware.
--
-- Parameters:
--    None
--
-- Return Values:
--    SAP_RT_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/28/10 kraj0359 Created.
----------------------------------------------------------------------------

    FUNCTION swms_rt_func RETURN SAP_RT_OBJECT_TABLE
    AS

      PRAGMA AUTONOMOUS_TRANSACTION;
              l_RT_tab SAP_RT_OBJECT_TABLE := SAP_RT_Object_table();
              message VARCHAR2(2000);
              lv_batch_id Number(8);
              batch_id_resend number(8);
              lv_loop Number;
      BEGIN
          update SAP_RT_OUT set record_status='N' where record_status = 'Q';
          COMMIT;

          select min(batch_id) into batch_id_resend from SAP_RT_OUT where record_status = 'N' and batch_id is not null order by sequence_number;

          IF batch_id_resend is not null THEN

                lv_batch_id := batch_id_resend;

                FOR i_index IN (SELECT sequence_number,Trans_type, Item, Cpv, Trans_date, Stop_no,
                    Route_no, Order_id, Reason_code, New_status, Adj_flag, Order_type, Split_ind,
                    Qty, Weight, Returned_item, Manifest_no FROM SAP_RT_OUT
                    WHERE record_status='N' and batch_id = batch_id_resend ORDER BY sequence_number)

                LOOP
                    update SAP_RT_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                    COMMIT;

                    message := 'SAP_RT_OUT:ERROR:TRANS_TYPE:' || i_index.Trans_type || ':ITEM:' || i_index.Item || ':STOP#:'|| i_index.Stop_no|| ':ROUTE#:' ||i_index.Route_no|| ':SEQUENCE#:'|| i_index.sequence_number;

                    l_RT_tab.extend;
                    l_RT_tab(l_RT_tab.COUNT) := SAP_RT_OBJECT(lv_batch_id, i_index.Trans_type, i_index.Item, i_index.Cpv, i_index.Trans_date, i_index.Stop_no,
                                            i_index.Route_no, i_index.Order_id, i_index.Reason_code, i_index.New_status, i_index.Adj_flag, i_index.Order_type, i_index.Split_ind,
                                            i_index.Qty, i_index.Weight, i_index.Returned_item, i_index.Manifest_no);

                END LOOP;
            ELSE
                lv_loop :=0;

                FOR i_index IN (SELECT sequence_number,Trans_type, Item, Cpv, Trans_date, Stop_no,
                    Route_no, Order_id, Reason_code, New_status, Adj_flag, Order_type, Split_ind,
                    Qty, Weight, Returned_item, Manifest_no FROM SAP_RT_OUT
                    WHERE record_status='N' and batch_id is null ORDER BY sequence_number)
                LOOP
                    IF lv_loop = 0  THEN
                        select max(batch_id) into lv_batch_id from SAP_RT_OUT;
                        IF lv_batch_id is NULL THEN
                            lv_batch_id := 1;
                        ELSE
                            lv_batch_id := lv_batch_id + 1;
                        END IF;

                        lv_loop := 1;
                    END IF;

                    update  SAP_RT_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                    and batch_id is null;
                    COMMIT;

                    message := 'SAP_RT_OUT :ITEM:' || i_index.Item || ':STOP#:'|| i_index.Stop_no|| ':ROUTE#:' ||i_index.Route_no|| ':SEQUENCE#:'|| i_index.sequence_number;

                    l_RT_tab.extend;
                    l_RT_tab(l_RT_tab.COUNT) := SAP_RT_OBJECT(lv_batch_id, i_index.Trans_type, i_index.Item, i_index.Cpv, i_index.Trans_date, i_index.Stop_no,
                                            i_index.Route_no, i_index.Order_id, i_index.Reason_code, i_index.New_status, i_index.Adj_flag, i_index.Order_type, i_index.Split_ind,
                                            i_index.Qty, i_index.Weight, i_index.Returned_item, i_index.Manifest_no);

               END LOOP;
               END IF;
               RETURN l_RT_tab;
      EXCEPTION
         WHEN OTHERS THEN
            pl_log.ins_msg('FATAL','swms_rt_func',message, SQLCODE, SQLERRM,'DRIVER CHECKIN','PL_SAP_INTERFACES','Y');
    END swms_rt_func;


-- Table Function for SCI016-C
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_ow_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_OW_OUT
--     and sends the resultset data for pick adjustments and order processing
--     transaction information (SCI016-C) to SAP through PI middleware.
--
-- Parameters:
--    None
--
-- Return Values:
--    SAP_OW_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/05/10 sray0453 Created.
--    10/21/10 sray0453 CR4054 - Batch_id included to handle reprocessing.
--    10/21/11 ykri0358 CR6645 - Bypass flag parameter removed.
----------------------------------------------------------------------------
FUNCTION swms_ow_func RETURN SAP_OW_OBJECT_TABLE
AS

PRAGMA AUTONOMOUS_TRANSACTION;
l_OW_tab SAP_OW_OBJECT_TABLE := SAP_OW_OBJECT_TABLE();
message VARCHAR2(100);
lv_batch_id number(8);

BEGIN

    -- Changes for sending multiple routes with batch_id assigned in a single PI call
    -- 01/24/2011 -  ykri0358

        FOR i_index IN (SELECT DISTINCT route_no, sequence_number
            FROM SAP_OW_OUT
            WHERE record_status='N' 
            AND batch_id IS NULL
            ORDER BY sequence_number)

        LOOP

            SELECT max(batch_id) into lv_batch_id from SAP_OW_OUT
            WHERE  batch_id is not null;

            IF lv_batch_id IS NULL THEN
                lv_batch_id := 1;
            ELSE
                lv_batch_id := lv_batch_id + 1;
            END IF;

            update  SAP_OW_OUT set batch_id = lv_batch_id
            where route_no = i_index.route_no 
            and record_status = 'N' and batch_id is null;

            COMMIT;

        END LOOP;


        FOR i_index IN (SELECT batch_id,bypass_flag,sequence_number,
        trans_type,trans_date,order_id,order_line_id,prod_id,cust_pref_vendor,
        route_no,truck_no,stop_no,reason_code,new_status,sys_order_id,sys_order_line_id,
        uom,qty_expected,qty,weight,clam_bed_no,user_id,harvest_date,wild_farm_desc,
        country_of_origin,sys_order_id_ext FROM SAP_OW_OUT where record_status = 'N'
        and batch_id is not null ORDER BY sequence_number)

        LOOP

            update  SAP_OW_OUT set record_status = 'Q'
            where  record_status = 'N' and sequence_number = i_index.sequence_number;
            commit;

            message := 'SAP_OW_OUT:ERROR:TRANS_TYPE:' || i_index.trans_type || ':ORDER_ID:' || i_index.order_id
                        || ':SEQUENCE#:' || i_index.sequence_number;

            l_OW_tab.extend;
            l_OW_tab(l_OW_tab.COUNT) := SAP_OW_OBJECT(i_index.batch_id, i_index.bypass_flag, i_index.trans_type,i_index.trans_date,
            i_index.order_id,i_index.order_line_id,i_index.prod_id,i_index.cust_pref_vendor,
            i_index.route_no,i_index.truck_no,i_index.stop_no,i_index.reason_code,
            i_index.new_status,i_index.sys_order_id,i_index.sys_order_line_id,
            i_index.uom,i_index.qty_expected,i_index.qty,i_index.weight,i_index.clam_bed_no,
            i_index.user_id,i_index.harvest_date,i_index.wild_farm_desc,
            i_index.country_of_origin,i_index.sys_order_id_ext);

        END LOOP;


    RETURN l_OW_tab;

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        NULL;

    WHEN OTHERS THEN
            pl_log.ins_msg('FATAL','swms_ow_func',message, SQLCODE, SQLERRM,'PICK ADJUSTMENT','PL_SAP_INTERFACES','Y');
END swms_ow_func;

-- Table Function for SCI015-C
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_cr_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_CR_OUT
--     and sends the resultset data about cash returns to SAP through PI middleware.
--
-- Parameters:
--    None
--
-- Return Values:
--    SAP_CR_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/10/10 kraj0359 Created.
----------------------------------------------------------------------------
FUNCTION  swms_cr_func
return SAP_CR_OBJECT_TABLE
IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  l_SAP_CR_OBJECT_TABLE SAP_CR_OBJECT_TABLE := SAP_CR_OBJECT_TABLE();
  message varchar2(2000);
  lv_batch_id Number(8);
  batch_id_resend number(8);
  lv_loop Number;
BEGIN
    update SAP_CR_OUT set record_status='N' where record_status = 'Q';
    COMMIT;

    select min(batch_id) into batch_id_resend from SAP_CR_OUT where record_status = 'N' and batch_id is not null order by sequence_number;

    IF batch_id_resend is not null THEN

        lv_batch_id := batch_id_resend;

            FOR i_index in (select sequence_number,Batch_no,Batch_type,Item_seq,
                Cust_id,Amount,Invoice_num,Invoice_date,Check_num,Manifest_no
                from SAP_CR_OUT where record_status='N' and batch_id = batch_id_resend  order by sequence_number)

            LOOP
                update SAP_CR_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                COMMIT;

                Message := 'SAP_CR_OUT:ERROR:BATCH_NO:' || i_index.Batch_no|| ':BATCH_TYPE:' || i_index.Batch_type||':SEQ NO:'||i_index.sequence_number;

                l_SAP_CR_OBJECT_TABLE.extend;
                l_SAP_CR_OBJECT_TABLE(l_SAP_CR_OBJECT_TABLE.count) := SAP_CR_OBJECT(lv_batch_id, i_index.Batch_no, i_index.Batch_type,
                i_index.Item_seq, i_index.Cust_id, i_index.Amount, i_index.Invoice_num, i_index.Invoice_date, i_index.Check_num, i_index.Manifest_no);
            END LOOP;
    ELSE
        lv_loop :=0;
            FOR i_index in (select sequence_number,Batch_no,Batch_type,Item_seq,
                Cust_id,Amount,Invoice_num,Invoice_date,Check_num,Manifest_no
                from SAP_CR_OUT where record_status='N' and batch_id is null order by sequence_number)
            LOOP
                IF lv_loop = 0 THEN
                   select max(batch_id) into lv_batch_id from SAP_CR_OUT;

                       IF lv_batch_id is NULL THEN
                           lv_batch_id := 1;
                       ELSE
                            lv_batch_id := lv_batch_id + 1;
                       END IF;

                   lv_loop := 1;

                  END IF;

                update  SAP_CR_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                and batch_id is null;
                COMMIT;


                Message := 'SAP_CR_OUT:ERROR:BATCH_NO:' || i_index.Batch_no|| ':BATCH_TYPE:' || i_index.Batch_type||':SEQ NO:'||i_index.sequence_number;

                l_SAP_CR_OBJECT_TABLE.extend;
                l_SAP_CR_OBJECT_TABLE(l_SAP_CR_OBJECT_TABLE.count) := SAP_CR_OBJECT(lv_batch_id, i_index.Batch_no, i_index.Batch_type,
                i_index.Item_seq, i_index.Cust_id, i_index.Amount, i_index.Invoice_num, i_index.Invoice_date, i_index.Check_num, i_index.Manifest_no);


            END LOOP;
      END IF;

      RETURN l_SAP_CR_OBJECT_TABLE;

EXCEPTION
     when others then
	pl_log.ins_msg ('FATAL', 'swms_cr_func',message, SQLCODE, SQLERRM,'ORDER PROCESS','PL_SAP_INTERFACES','Y');
END swms_cr_func;

-- Table Function for SCI025-C
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_wh_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_wh_OUT
--     and sends the item reconciliation data to SAP through PI middleware.
--
-- Parameters:
--    None
--
-- Return Values:
--    SAP_WH_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/26/10 kraj0359 Created.
----------------------------------------------------------------------------
Function swms_wh_func
return SAP_WH_OBJECT_TABLE
IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  l_SAP_WH_OBJECT_TABLE SAP_WH_OBJECT_TABLE := SAP_WH_OBJECT_TABLE();
  message varchar2(2000);
        lv_batch_id Number(8);
        batch_id_resend number(8);
        lv_loop Number;
BEGIN

            update SAP_WH_OUT set record_status='N' where record_status = 'Q';
            COMMIT;

            select min(batch_id) into batch_id_resend from SAP_WH_OUT where record_status = 'N' and batch_id is not null order by sequence_number;

            IF batch_id_resend is not null THEN

                lv_batch_id := batch_id_resend;

                FOR i_index in (select sequence_number,rec_type,prod_id,case_on_hand,split_on_hand,
                case_on_hold,split_on_hold,brand,pack,prod_size,descrip,buyer,cust_pref_vendor,
                upc from SAP_WH_OUT where record_status='N'  and batch_id = batch_id_resend order by sequence_number)

                LOOP
                    update SAP_WH_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                    COMMIT;

                    message := 'SAP_WH_OUT:ERROR:RECTYPE:'||i_index.rec_type||':PROD#:'||i_index.prod_id ||':SEQ NO:'||i_index.sequence_number;


                    l_SAP_wH_OBJECT_TABLE.extend;
                    l_SAP_WH_OBJECT_TABLE(l_SAP_WH_OBJECT_TABLE.count) := SAP_WH_OBJECT( lv_batch_id,i_index.rec_type,i_index.prod_id, i_index.case_on_hand,
                    i_index.split_on_hand,i_index.case_on_hold, i_index.split_on_hold, i_index.brand, i_index.pack,
                    i_index.prod_size, i_index.descrip, i_index.buyer, i_index.cust_pref_vendor , i_index.upc);

                END LOOP;
            ELSE
               lv_loop :=0;

               FOR i_index in (select sequence_number,rec_type,prod_id,case_on_hand,split_on_hand,
               case_on_hold,split_on_hold,brand,pack,prod_size,descrip,buyer,cust_pref_vendor,
               upc from SAP_WH_OUT where record_status='N' and batch_id is null order by sequence_number)

               LOOP
                  IF lv_loop = 0 THEN
                      select max(batch_id) into lv_batch_id from SAP_WH_OUT;

                      IF lv_batch_id is NULL THEN
                         lv_batch_id := 1;
                      ELSE
                         lv_batch_id := lv_batch_id + 1;
                      END IF;

                      lv_loop := 1;

                  END IF;

                 update  SAP_WH_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                 and batch_id is null;
                 COMMIT;

                 message := 'SAP_WH_OUT:ERROR:RECTYPE:'||i_index.rec_type||':PROD#:'||i_index.prod_id ||':SEQ NO:'||i_index.sequence_number;

                l_SAP_wH_OBJECT_TABLE.extend;
                l_SAP_WH_OBJECT_TABLE(l_SAP_WH_OBJECT_TABLE.count) := SAP_WH_OBJECT( lv_batch_id,i_index.rec_type,i_index.prod_id, i_index.case_on_hand,
			    i_index.split_on_hand,i_index.case_on_hold, i_index.split_on_hold, i_index.brand, i_index.pack,
			    i_index.prod_size, i_index.descrip, i_index.buyer, i_index.cust_pref_vendor , i_index.upc);

              END LOOP;
            END IF;

       RETURN l_SAP_WH_OBJECT_TABLE;

EXCEPTION
     when others then
	pl_log.ins_msg ('FATAL', 'swms_wh_func',message, SQLCODE, SQLERRM,'MAINTENANCE','PL_SAP_INTERFACES','Y');
END swms_wh_func;
-------------------------------------------------------------------------------
-- FUNCTION
--    swms_lm_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_LM_OUT
--     and sends the resultset for Item data(SCI069) to
--     SAP through PI middleware.
--
-- Parameters:
--      None
--
-- Return Values:
--    SAP_LM_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/26/10 ykri0358 Created.
--    10/21/10 sray0453 CR4054 - Batch_id included to handle reprocessing.
----------------------------------------------------------------------------
    FUNCTION swms_lm_func(in_bypass_flag IN varchar2) RETURN SAP_LM_OBJECT_TABLE
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        l_sap_lm_object_table SAP_LM_OBJECT_TABLE := SAP_LM_OBJECT_TABLE();
        message VARCHAR2(2000);
        lv_batch_id Number(8);
         batch_id_resend number(8);
        lv_loop Number;
      BEGIN
            IF in_bypass_flag = 'N' THEN
            UPDATE SAP_LM_OUT SET record_status='N' WHERE record_status = 'Q';
            COMMIT;
            END IF;

            select min(batch_id) into batch_id_resend from SAP_LM_OUT where record_status = 'N' and batch_id is not null;

            IF batch_id_resend is not null THEN

                lv_batch_id := batch_id_resend;


                FOR i_index IN (SELECT batch_id, sequence_number,prod_id ,cust_pref_vendor, area,
                               ti, hi, abc, mfr_shelf_life, pallet_type, lot_trk,
                               sysco_shelf_life, fifo_trk, cust_shelf_life,
                               exp_date_trk, mfg_date_trk, temp_trk, min_temp,
                               max_temp, miniload_storage_ind, case_qty_per_carrier
                               FROM SAP_LM_OUT
                               WHERE bypass_flag = in_bypass_flag and record_status = 'N' and batch_id = batch_id_resend
                               ORDER BY sequence_number)

                LOOP
                    update SAP_LM_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                    COMMIT;

                    message := 'SAP_LM_OUT:ERROR:PROD_ID:' ||  i_index.prod_id || ':SEQUENCE#:' || i_index.sequence_number;
                    l_sap_lm_object_table.extend;
                    l_sap_lm_object_table(l_sap_lm_object_table.COUNT) := SAP_LM_OBJECT(lv_batch_id, in_bypass_flag, i_index.prod_id, i_index.cust_pref_vendor,
                                                                                        i_index.area, i_index.ti, i_index.hi,
                                                                                        i_index.abc, i_index.mfr_shelf_life,
                                                                                        i_index.pallet_type, i_index.lot_trk,
                                                                                        i_index.sysco_shelf_life, i_index.fifo_trk,
                                                                                        i_index.cust_shelf_life, i_index.exp_date_trk,
                                                                                        i_index.mfg_date_trk, i_index.temp_trk,
                                                                                        i_index.min_temp, i_index.max_temp,
                                                                                        i_index.miniload_storage_ind, i_index.case_qty_per_carrier);
                END LOOP;

            ELSE
                lv_loop := 0;

                FOR i_index IN (SELECT batch_id, sequence_number,prod_id ,cust_pref_vendor, area,
                               ti, hi, abc, mfr_shelf_life, pallet_type, lot_trk,
                               sysco_shelf_life, fifo_trk, cust_shelf_life,
                               exp_date_trk, mfg_date_trk, temp_trk, min_temp,
                               max_temp, miniload_storage_ind, case_qty_per_carrier
                               FROM SAP_LM_OUT
                               WHERE bypass_flag = in_bypass_flag and record_status = 'N' and batch_id is null
                               ORDER BY sequence_number)


                LOOP
                    IF lv_loop = 0  THEN
                        select max(batch_id) into lv_batch_id from SAP_LM_OUT;

                        IF lv_batch_id is NULL THEN
                            lv_batch_id := 1;

                        ELSE
                            lv_batch_id := lv_batch_id + 1;
                        END IF;

                        lv_loop := 1;
                    END IF;
                    update  SAP_LM_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                    and batch_id is null;
                    COMMIT;

                    message := 'SAP_LM_OUT:ERROR:PROD_ID:' ||  i_index.prod_id || ':SEQUENCE#:' || i_index.sequence_number;

                    l_sap_lm_object_table.extend;
                    l_sap_lm_object_table(l_sap_lm_object_table.COUNT) := SAP_LM_OBJECT(lv_batch_id, in_bypass_flag, i_index.prod_id, i_index.cust_pref_vendor,
                                                                                        i_index.area, i_index.ti, i_index.hi,
                                                                                        i_index.abc, i_index.mfr_shelf_life,
                                                                                        i_index.pallet_type, i_index.lot_trk,
                                                                                        i_index.sysco_shelf_life, i_index.fifo_trk,
                                                                                        i_index.cust_shelf_life, i_index.exp_date_trk,
                                                                                        i_index.mfg_date_trk, i_index.temp_trk,
                                                                                        i_index.min_temp, i_index.max_temp,
                                                                                        i_index.miniload_storage_ind, i_index.case_qty_per_carrier);

               END LOOP;
            END IF;
            RETURN l_sap_lm_object_table;

    EXCEPTION

    WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', 'SWMS_LM_FUNC', message, SQLCODE, SQLERRM, 'MAINTENANCE', 'PL_SAP_INTERFACES', 'Y');
END swms_lm_func;

-------------------------------------------------------------------------------
-- FUNCTION
--    swms_container_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_CONTAINER_OUT
--     and sends the resultset for Container data(SCI098) to
--     SAP through PI middleware.
--
-- Parameters:
--      None
--
-- Return Values:
--    SAP_CONTAINER_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/25/10 ykri0358 Created.
----------------------------------------------------------------------------
    FUNCTION swms_container_func RETURN SAP_CONTAINER_OBJECT_TABLE
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        l_sap_container_object_table SAP_CONTAINER_OBJECT_TABLE := SAP_CONTAINER_OBJECT_TABLE();
        message VARCHAR2(2000);
        lv_batch_id Number(8);
        batch_id_resend number(8);
        lv_loop Number;

      BEGIN
           update SAP_CONTAINER_OUT set record_status='N' where record_status = 'Q';
           COMMIT;

           select min(batch_id) into batch_id_resend from SAP_CONTAINER_OUT where record_status = 'N' and batch_id is not null order by sequence_number;

           IF batch_id_resend is not null THEN

                lv_batch_id := batch_id_resend;

                FOR i_index IN (SELECT sequence_number, truck_no , route_no , order_id, order_line_id,  cust_id,
                                   prod_id, total_qty, area, batch_no, src_loc, pallet_qty,
                                   g_weight, lot_no, mfg_date, exp_date, rcv_date, temperature
                            FROM SAP_CONTAINER_OUT
                            WHERE record_status='N' and batch_id = batch_id_resend ORDER BY sequence_number)
               LOOP
                    update SAP_CONTAINER_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                    COMMIT;

                    message :=  'SAP_CONTAINER_OUT:ERROR:truck#'||i_index.truck_no ||':Route #:'||i_index.route_no ||':Order Id:'||i_index.order_id||':SEQ NO:'||i_index.sequence_number;
                    l_sap_container_object_table.extend;
                    l_sap_container_object_table(l_sap_container_object_table.COUNT) := SAP_CONTAINER_OBJECT(lv_batch_id, i_index.truck_no ,
                                                                                    i_index.route_no, i_index.order_id, i_index.order_line_id, i_index.cust_id,
                                                                                    i_index.prod_id, i_index.total_qty, i_index.area, i_index.batch_no,
                                                                                    i_index.src_loc, i_index.pallet_qty, i_index.g_weight, i_index.lot_no,
                                                                                    i_index.mfg_date, i_index.exp_date, i_index.rcv_date, i_index.temperature);
              END LOOP;
           ELSE
              lv_loop := 0;

              FOR i_index IN (SELECT sequence_number, truck_no , route_no , order_id, order_line_id,  cust_id,
                                   prod_id, total_qty, area, batch_no, src_loc, pallet_qty,
                                   g_weight, lot_no, mfg_date, exp_date, rcv_date, temperature
                            FROM SAP_CONTAINER_OUT
                            WHERE record_status='N' and batch_id is null ORDER BY sequence_number)
              LOOP
                  IF lv_loop = 0 THEN
                       select max(batch_id) into lv_batch_id from SAP_CONTAINER_OUT;

                       IF lv_batch_id is NULL THEN
                           lv_batch_id := 1;
                       ELSE
                           lv_batch_id := lv_batch_id + 1;
                       END IF;

                       lv_loop := 1;
                 END IF;

                update  SAP_CONTAINER_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                and batch_id is null;
                COMMIT;
                message :=  'SAP_CONTAINER_OUT:ERROR:truck#'||i_index.truck_no ||':Route #:'||i_index.route_no ||':Order Id:'||i_index.order_id||':SEQ NO:'||i_index.sequence_number;

                l_sap_container_object_table.extend;
                l_sap_container_object_table(l_sap_container_object_table.COUNT) := SAP_CONTAINER_OBJECT(lv_batch_id, i_index.truck_no ,
                                                                                    i_index.route_no, i_index.order_id, i_index.order_line_id, i_index.cust_id,
                                                                                    i_index.prod_id, i_index.total_qty, i_index.area, i_index.batch_no,
                                                                                    i_index.src_loc, i_index.pallet_qty, i_index.g_weight, i_index.lot_no,
                                                                                    i_index.mfg_date, i_index.exp_date, i_index.rcv_date, i_index.temperature);

              END LOOP;
          END IF;
          RETURN l_sap_container_object_table;

    EXCEPTION

    WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', 'SWMS_CONTAINER_FUNC', message, SQLCODE, SQLERRM, 'MAINTENANCE', 'PL_SAP_INTERFACES', 'Y');
END swms_container_func;

-------------------------------------------------------------------------------
-- FUNCTION
--    swms_equip_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_EQUIP_OUT
--     and sends the resultset for equipment data(SCI087) to
--     SAP through PI middleware.
--
-- Parameters:
--      None
--
-- Return Values:
--    SAP_EQUIP_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/10/10 ykri0358 Created.
--    11/29/16 bnim1623 Add the column 'Add_user' on select for CRQ17639 
----------------------------------------------------------------------------
    FUNCTION swms_equip_func RETURN SAP_EQUIP_OBJECT_TABLE
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        l_sap_equip_object_table SAP_EQUIP_OBJECT_TABLE := SAP_EQUIP_OBJECT_TABLE();
        message VARCHAR2(2000);
        lv_batch_id Number(8);
        batch_id_resend number(8);
        lv_loop Number;
      BEGIN
            update SAP_EQUIP_OUT set record_status='N' where record_status = 'Q';
            COMMIT;

            select min(batch_id) into batch_id_resend from SAP_EQUIP_OUT where record_status = 'N' and batch_id is not null order by sequence_number;

            IF batch_id_resend is not null THEN
                lv_batch_id := batch_id_resend;

                FOR i_index IN (SELECT sequence_number, equip_id, inspection_date, equip_name, status, add_user
                            FROM SAP_EQUIP_OUT
                            WHERE record_status='N' and batch_id = batch_id_resend ORDER BY sequence_number)
                LOOP
                    update SAP_EQUIP_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                    COMMIT;

                    message :=  'SAP_EQUIP_OUT:ERROR:EQUIP#'||i_index.equip_id ||':SEQ NO:'||i_index.sequence_number;

                    l_sap_equip_object_table.extend;
                    l_sap_equip_object_table(l_sap_equip_object_table.COUNT) := SAP_EQUIP_OBJECT(lv_batch_id, i_index.equip_id ,
                                                                                    i_index.inspection_date, i_index.equip_name, i_index.status, i_index.add_user);
                END LOOP;
            ELSE
                lv_loop := 0;

                FOR i_index IN (SELECT sequence_number, equip_id, inspection_date, equip_name, status, add_user
                            FROM SAP_EQUIP_OUT
                            WHERE record_status='N' and batch_id is null ORDER BY sequence_number)
                LOOP
                    IF lv_loop = 0 THEN
                         select max(batch_id) into lv_batch_id from SAP_EQUIP_OUT;

                         IF lv_batch_id is NULL THEN
                             lv_batch_id := 1;
                         ELSE
                             lv_batch_id := lv_batch_id + 1;
                         END IF;

                         lv_loop := 1;
                    END IF;

                    update  SAP_EQUIP_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                    and batch_id is null;
                    COMMIT;

                    message :=  'SAP_EQUIP_OUT:ERROR:EQUIP#'||i_index.equip_id ||':SEQ NO:'||i_index.sequence_number;

                    l_sap_equip_object_table.extend;
                    l_sap_equip_object_table(l_sap_equip_object_table.COUNT) := SAP_EQUIP_OBJECT(lv_batch_id, i_index.equip_id ,
                                                                                    i_index.inspection_date, i_index.equip_name, i_index.status, i_index.add_user);


                END LOOP;
             END IF;
         RETURN l_sap_equip_object_table;

    EXCEPTION

    WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', 'SWMS_EQUIP_FUNC', message, SQLCODE, SQLERRM, 'MAINTENANCE', 'PL_SAP_INTERFACES', 'Y');
END swms_equip_func;

-------------------------------------------------------------------------------
-- FUNCTION
--    swms_pw_func
--
-- Description:
--     This function retrieves the data from Oracle staging table SAP_PW_OUT
--     and sends the resultset for data(PRI055) to
--     SAP through PI middleware.
--
-- Parameters:
--      None
--
-- Return Values:
--    SAP_PW_OBJECT_TABLE
--
-- Exceptions Raised:
--   The when OTHERS propagates the exception.
--
-- Called by:
--    SAP-PI
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/18/11 ykri0358 Created.
--    05/09/13 mdev3739 CRQ45458 Added erm_type variable for returning.
----------------------------------------------------------------------------
    FUNCTION swms_pw_func RETURN SAP_PW_OBJECT_TABLE
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        l_sap_pw_object_table SAP_PW_OBJECT_TABLE := SAP_PW_OBJECT_TABLE();
        message VARCHAR2(2000);
        lv_batch_id Number(8);
        batch_id_resend number(8);
        lv_loop Number;
      BEGIN
            update SAP_PW_OUT set record_status='N' where record_status = 'Q';
            COMMIT;

            select min(batch_id) into batch_id_resend from SAP_PW_OUT where record_status = 'N' and batch_id is not null order by sequence_number;

            IF batch_id_resend is not null THEN
                lv_batch_id := batch_id_resend;

                FOR i_index IN (SELECT sequence_number, erm_id, status, erm_type								
                            FROM SAP_PW_OUT
                            WHERE record_status='N' and batch_id = batch_id_resend ORDER BY sequence_number) -- CRQ45458 Added erm_type variable for returning
                LOOP
                    update SAP_PW_OUT set record_status = 'Q' where batch_id = batch_id_resend and sequence_number = i_index.sequence_number;
                    COMMIT;

                    message :=  'SAP_PW_OUT:ERROR:PO#'||i_index.erm_id ||':SEQ NO:'||i_index.sequence_number;

                    l_sap_pw_object_table.extend;
                    l_sap_pw_object_table(l_sap_pw_object_table.COUNT) := SAP_PW_OBJECT(lv_batch_id, i_index.erm_id ,
                                                                                    i_index.status, i_index.erm_type); -- CRQ45458 Added erm_type variable for returning
                END LOOP;
            ELSE
                lv_loop := 0;

                FOR i_index IN (SELECT sequence_number, erm_id, status, erm_type
                            FROM SAP_PW_OUT
                            WHERE record_status='N' and batch_id is null ORDER BY sequence_number) -- CRQ45458 Added erm_type variable for returning
                LOOP
                    IF lv_loop = 0 THEN
                         select max(batch_id) into lv_batch_id from SAP_PW_OUT;

                         IF lv_batch_id is NULL THEN
                             lv_batch_id := 1;
                         ELSE
                             lv_batch_id := lv_batch_id + 1;
                         END IF;

                         lv_loop := 1;
                    END IF;

                    update  SAP_PW_OUT set batch_id = lv_batch_id, record_status = 'Q' where sequence_number = i_index.sequence_number
                    and batch_id is null;
                    COMMIT;

                    message :=  'SAP_PW_OUT:ERROR:PO#'||i_index.erm_id ||':SEQ NO:'||i_index.sequence_number;

                    l_sap_pw_object_table.extend;
                    l_sap_pw_object_table(l_sap_pw_object_table.COUNT) := SAP_PW_OBJECT(lv_batch_id, i_index.erm_id ,
                                                                                    i_index.status, i_index.erm_type); -- CRQ45458 Added erm_type variable for returning


                END LOOP;
             END IF;
         RETURN l_sap_pw_object_table;

    EXCEPTION

    WHEN OTHERS THEN
        pl_log.ins_msg('FATAL', 'SWMS_PW_FUNC', message, SQLCODE, SQLERRM, 'RECIEVING', 'PL_SAP_INTERFACES', 'Y');
END swms_pw_func;

END pl_sap_interfaces;
/
