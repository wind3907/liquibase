CREATE OR REPLACE TRIGGER swms.trg_insupd_pm_brow
BEFORE INSERT OR UPDATE ON swms.pm
FOR EACH ROW
DECLARE
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_pm_brow.sql, swms, swms.9, 11.2 2/16/10 1.21
--
-- Table:
--    PM
--
-- Description:
--    This trigger performs various actions when an item is inserted
--    or updated.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/16/02 prpbcb   rs239a DN NA   rs239b DN 11062  Created.
--                      For RDC non-dependent changes.
--    02/23/04 prpakp   Added check to exp_date_trk and mfg_date_trk.
--    01/17/06 acpvxg   Added changes to set the miniload_storage_ind.
--    08/25/06 prpakp   Change to make sure that auto_ship_flag is N if null.
--    01/12/07 prpbcb   DN: 12195
--                      Ticket: 292371
--                      Project: 292371-Corrupted auto ship flag
--                      Change to set auto_ship_flag to N if value
--                      not Y or N.  swmsimreader sometimes corrupts the value.
--                      swmsimreader is being fixed but we still need a check
--                      in this trigger.
--    03/16/07 prppxx   D#12230 Insert IMT transaction for attribute changes:
--                      lot_trk, catch_wt, split_trk, spc, temp_trk, all shelf
--                      life changes, auto_ship_flag, hazaedous, category.
--
--    05/10/07 prpbcb   DN 12235
--                      Ticket: 265200
--                      Project: 265200-Putaway By Inches Modifications
--
--                      Set case height to 99 if it is 0 or null.
--
--                      Insert IMT transactions when case height changes
--                      and putaway is by inches.
--
--                      Modified to call
--                      pl_putaway_utilities.p_update_heights_for_item()
--                      when the case height changes and putaway is by inches.
--
--    09/05/07 prpbcb   DN 12280
--                      Ticket: 458478
--                      Project: 458478-Miniload Fixes
--
--                      Moved (and modified) the miniloader logic from
--                      swmsimoracle.pc to this trigger that sends a New SKU
--                      or Modify SKU message to the miniloader when it is a
--                      miniload item and atttributes for the item change.
--                      A New SKU message for the split item is sent when a
--                      non-splitable item is made splitable and the case is
--                      in the miniloader.
--                      A modify SKU message is sent:
--                         - When the item description changes.
--                         - When the case qty per carrier changes except if it
--                           is 0.
--
--                      The changes made to the logic that was in
--                      swmsimoracle.pc are when a non-splitable was
--                      made splitable.  The changes are:
--                      1.  Send a New SKU message for the split to the
--                          miniloader and not a modify SKU.  The miniloader
--                          does not have the split so it rejected the modify
--                          SKU so the split item was never created in the
--                          miniloader.
--                      2.  Do not sent a modify SKU for the case since the
--                          miniloader already has the case.  Before it was
--                          sent which did not cause a problem but there is
--                          no need to send it.
--                      3.  Set the item split zone id to the put zone.  Before
--                          it was left blank.
--                      4.  Create a MNI transaction, which is the transaction
--                          type created when an item is slotted to the
--                          miniloader, for the split item and in the
--                          transaction comment field put in something along
--                          the lines of
--                             "SUS FLAGGED NON SPLITABLE ITEM AS SPLITABLE.
--                             SPLIT SKU SENT TO MINILOADER".
-- Matrix showing when a new/modify SKU needs to be sent from SWMS to
-- the miniloader.  This will be put in the comments for file
-- trg_insupd_pm_brow.sql
/*
+-----------------------------------------------------------------------------+
|   |           |           |         | Case    | --- Send to Miniloader ---- |
| M |           | Item      | Item    | Qty Per | New  | New   | Mod  | Mod   |
| S | Item      | Made      | Descrip | Carrier | SKU  | SKU   | SKU  | SKU   |
| I | Splitable | Splitable | Changed | Changed | Case | Split | Case | Split |
+---+-----------+-----------+---------+---------+------+-------+------+-------+
| B |    N      |    Y      |         |         |      |   Y   |      |       |
| B |    N      |           |    Y    |         |      |       |  Y   |       |
| B |    N      |           |         |    Y    |      |       |  Y   |       |
| B |    N      |    Y      |    Y    |         |      |   Y   |  Y   |       |
| B |    N      |    Y      |         |    Y    |      |   Y   |  Y   |       |
+---+-----------+-----------+---------+---------+------+-------+------+-------+
| B |    Y      |           |    Y    |         |      |       |  Y   |   Y   |
| B |    Y      |           |         |    Y    |      |       |  Y   |   Y   |
+---+-----------+-----------+---------+---------+------+-------+------+-------+
| S |    Y      |           |    Y    |         |      |       |      |   Y   |
| S |    Y      |           |         |    Y    |      |       |      |   Y   |
+---+-----------+-----------+---------+---------+------+-------+------+-------+
MSI - Miniload storage indicator
Mod - Modify
*/
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/02/07 ctvgg000 HK Integration. 
--                      Added Zone Id, split_zone_id parameter to 
--                      pl_miniload_processing.send_sku_change procedure.   
--	  
--    04/22/08 prpbcb   DN 12372
--                      Project: 491264-Case Height Change
--                      Re-worked the changed made on 05/17/08 in re-calulating
--                      the heights when the case height changes and putaway
--                      is by inches.  The change did not always work
--                      correctly.  Now a PL/SQL table is populated with the
--                      item and CPV.  There is an after statement trigger on
--                      the PM table that will re-calculate the heights.
--                      We were having issues with the wrong case height
--                      being used in the re-calculation when a slot had
--                      a pallet of another item.
-- 
--   07/02/2008         DN# 12404
--                      Project: 480001-Miniload Identifier in SUS
--                      Added an insert statement to HACCP_PM_HIST table
--                      when either miniload_storage_ind or
--                      case_qty_per_carrier is updated. 
--	  
--    10/25/08 prpbcb   DN 12434
--                      Project:
--                   CRQ000000001006-Embed meaningful messages in miniload
--
--                      Set case_qty_per_carrier to the syspar default value
--                      if it is null.
--
--                      Create IMT transaction when the WEIGHT, AVG_WT or
--                      G_WEIGHT changes.
--
--                      If it is a miniload item and not splitable then the
--                      split_zone_id will be set to null if it is
--                      populated.  We are seeing situations where the
--                      split_zone_id is populated which can cause a problem
--                      when the orders are sent to the miniloader.
--
--                      If it is a miniload item with the case in the
--                      miniloader and the item is splitable and the
--                      split_zone_id is null the the split_zone_id will be
--                      set to the zone_id.  The is a fail safe operation as
--                      the split_zone_id should be populated.
--
--
--    04/07/09 prpbcb   DN 12486
--                      Project: CRQ8199-Old Ti Hi sent to SUS
--                      Moved logic for creating IMT transactions from form
--                      mi1sb.fmb to this trigger for the following.
--                         - pallet_type
--                         - ti
--                         - hi
--                         - exp_date_trk
--                         - mfg_date_trk
--                         - fifo_trk
--                         - min_qty
--                         - max_qty
--                         - stackable
--                         - case_pallet
--                         - abc
--                         - pallet_stack
--                         - case_qty_per_carrier   This one never had a
--                                                  IMT transaction
--                         - mfg_sku
--    01/20/10 prplhj   DN 12538 Include the update of tracked flags in the
--			PUTAWAYLST table if the PO/SN/VSN is still open when
--			the tracked flags have been changed. Add log messages
--			to SWMS_LOG table when any tracked flag value is
--			changed.
--
--    02/02/10 prpbcb   DN 12512
--                      Project:
--                CRQ8828-Miniload Functionality in Warehouse Move Process
--
--                      When an item is slotted to the miniloader call
--                      pl_planned_order.ml_send_planned_orders_for_item
--                      to send planned orders sent down before the item was
--                      slotted.
--    02/15/10 prplhj   DN 12562 Added "for update nowait" to the cursor
--			c_get_pos so that if PUTAWAYLST is locking up the
--			record for the track flag changes, we can still change
--			the track flags for the PM table without updating
--			them in PUTAWAYLST.
--    04/26/10 sray0453 DN SWMS212
--                      Project: SCI069-Warehouse attributes change should
--                      be sent to ECC if OPCO is an SAP OPCO.
--    10/31/11 jluo5859	CRQ25315 Recalculate case/split cube if any of case
--			dimension values changes (except to 0/NULL/99) and
--			log the dimension and/or cube changes to IMT trans.
--			The cube change should only occur when the syspar
--			CUBE_CHG_FOR_DIM_CHG is Y.
--    01/06/12 pshr2440 CRQ 32935 Modified the if condition  
--			so that the value of tti_trk is updated properly in 
--			putawaylst table.     
--    10/31/12 jluo5859	CRQ 39722. For any dimension value that is updated or
--			new, round the decimal part of the value, if any, to
--			only up to 3 digits. This should fix the problem that
--			the created IMT transaction TRANS.cmt value being
--			less than the designed length.
--  04-NOV-2014 avij3336    Charm# 6000003789 � Ireland Cubic values - Metric conversion project
--                          Included changes for calculating case_cube and split_cube based on the length unit syspar (CM/IN)
--  02-OCT-2018 sban3548    Jira# 391 - Added logic for putaway exceptions handling. Item master tracking flags are validated 
--                                      and defaulted to N if a not valid value is passed.
--
------------------------------------------------------------------------------
   l_object_name  VARCHAR2(30) := 'trg_insupd_pm_brow';

   l_case_rule_id   ZONE.rule_id%TYPE;
   l_index          PLS_INTEGER;   -- PL/SQL table index

   l_split_rule_id  ZONE.rule_id%TYPE;
   --l_cmt            trans.cmt%TYPE := '';
     l_cmt           VARCHAR2(1000) ;

   l_status          NUMBER;

   l_trk		BOOLEAN := FALSE;
   l_trk2		BOOLEAN := FALSE;
   l_chk		NUMBER := 0;
   l_chk2		VARCHAR2(1) := NULL;
   l_syspar_clambed	sys_config.config_flag_val%TYPE := 'N';
   
   /* SCI069-C Variable declaration*/
   l_host_type_flag   VARCHAR2(6)  := 'AS400';    -- SAP OPCO or NON SAP OPCO
   l_host_comm_flag   VARCHAR2(15) := 'APCOM';    -- Staging table to APCOM
   l_warehouse_upd  VARCHAR2(1);    -- Warehouse attributes updated?
   l_process		v$session.process%TYPE := NULL;
   l_field_beg		NUMBER := 0;
   l_field_end		NUMBER := 0;
   l_old_cube		VARCHAR2(100) := NULL;
   l_new_cube		VARCHAR2(100) := NULL;
   l_old_hght		VARCHAR2(100) := NULL;
   l_new_hght		VARCHAR2(100) := NULL;
   l_old_wdth		VARCHAR2(100) := NULL;
   l_new_wdth		VARCHAR2(100) := NULL;
   l_old_len		VARCHAR2(100) := NULL;
   l_new_len		VARCHAR2(100) := NULL;
   l_cube_chg_syspar	sys_config.config_flag_name%TYPE := NULL;
    CURSOR c_get_pos(csItem	pm.prod_id%TYPE,
		csCpv		pm.cust_pref_vendor%TYPE,
		csNewVal	VARCHAR2,
		ciOption	NUMBER) IS
	SELECT p.rec_id, p.prod_id, p.cust_pref_vendor,
		NVL(p.date_code, 'N') date_code,
		NVL(p.exp_date_trk, 'N') exp_date_trk,
		NVL(p.lot_trk, 'N') lot_trk, NVL(p.temp_trk, 'N') temp_trk,
		NVL(p.catch_wt, 'N') catch_wt,
		NVL(p.clam_bed_trk, 'N') clam_bed_trk,
		NVL(p.tti_trk, 'N') tti_trk,
		NVL(p.cryovac, 'N') cryovac, NVL(p.cool_trk, 'N') cool_trk
	FROM erm m, erd d, putawaylst p
	WHERE m.erm_id = d.erm_id
	AND   m.erm_type IN ('PO', 'SN', 'VN')
	AND   m.status = 'OPN'
	AND   d.prod_id = csItem
	AND   d.cust_pref_vendor = csCpv
	AND   m.erm_id = p.rec_id
	AND   d.prod_id = p.prod_id
	AND   d.cust_pref_vendor = p.cust_pref_vendor
	AND   (((ciOption = 1) AND
		(NVL(p.date_code, 'N') <> NVL(csNewVal, 'N'))) OR
	       (((ciOption = 2) AND
		(NVL(p.exp_date_trk, 'N') <> NVL(csNewVal, 'N')))) OR
	       (((ciOption = 3) AND
		(NVL(p.lot_trk, 'N') <> NVL(csNewVal, 'N')))) OR
	       (((ciOption = 4) AND
		(NVL(p.catch_wt, 'N') <> NVL(csNewVal, 'N')))) OR
	       (((ciOption = 5) AND
		(NVL(p.temp_trk, 'N') <> NVL(csNewVal, 'N')))) OR
	       (((ciOption = 6) AND
		(NVL(p.tti_trk, 'N') <> NVL(csNewVal, 'N')))) OR
	       (((ciOption = 7) AND
		(NVL(p.cool_trk, 'N') <> NVL(csNewVal, 'N')))) OR
	       (((ciOption = 8) AND
		(NVL(p.clam_bed_trk, 'N') <> NVL(csNewVal, 'N')))))
	ORDER BY d.erm_id, d.erm_line_id
	FOR UPDATE NOWAIT;
   CURSOR c_get_upd_hist (csItem	pm.prod_id%TYPE,
			csProcess	v$session.process%TYPE) IS
	SELECT msg_text
	FROM swms_log l
	WHERE msg_text LIKE '%' || csItem || '%' || csProcess || '%' || 'recalculated cube after' || '%'
	AND   procedure_name = l_object_name
	AND   add_date = (SELECT MAX(add_date)
			  FROM swms_log
			  WHERE msg_text = l.msg_text
			  AND   procedure_name = l.procedure_name)
	AND   add_date > SYSDATE - 10 / 1440;
BEGIN

	/******** BEG ADD ACPVXG 17-Jan-05 ******************/
   IF :NEW.zone_id IS NOT NULL THEN
   BEGIN
         SELECT rule_id
         INTO   l_case_rule_id
         FROM   ZONE
         WHERE  zone_id = :NEW.zone_id;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_case_rule_id := 0;
   END;
   END IF;

   IF :NEW.split_zone_id IS NOT NULL THEN
   BEGIN
         SELECT rule_id
         INTO   l_split_rule_id
         FROM   ZONE
         WHERE  zone_id = :NEW.split_zone_id;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_split_rule_id := 0;
   END;
   END IF;
	/******** END ADD ACPVXG 17-Jan-05 ******************/	

   -- Only save up to 3-digit decimals for any dimension value change or add
   IF :NEW.case_height IS NOT NULL AND
      LENGTH(SUBSTR(TO_CHAR(:NEW.case_height),
		instr(to_char(:NEW.case_height), '.') + 1)) > 3 THEN
	:NEW.case_height := ROUND(:NEW.case_height, 3);
   END IF;
   IF :NEW.case_width IS NOT NULL AND
      LENGTH(SUBSTR(TO_CHAR(:NEW.case_width),
		instr(to_char(:NEW.case_width), '.') + 1)) > 3 THEN
	:NEW.case_width := ROUND(:NEW.case_width, 3);
   END IF;
   IF :NEW.case_length IS NOT NULL AND
      LENGTH(SUBSTR(TO_CHAR(:NEW.case_length),
		instr(to_char(:NEW.case_length), '.') + 1)) > 3 THEN
	:NEW.case_length := ROUND(:NEW.case_length, 3);
   END IF;

   IF UPDATING THEN    --  start IF UPDATING
      :NEW.upd_user := REPLACE(USER, 'OPS$');
      :NEW.upd_date := SYSDATE;

      IF (:NEW.auto_ship_flag IS NULL
         OR :NEW.auto_ship_flag NOT IN ('Y', 'N')) THEN
         --
         -- Log a message if auto ship flag is non-null.  The value is
         -- something other the Y or N.
         --
         IF (:NEW.auto_ship_flag IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'UPDATING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  auto_ship_flag[' || :NEW.auto_ship_flag || ']'
                || '  auto ship flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;

          :NEW.auto_ship_flag := 'N';
      END IF;

      IF :NEW.mfg_date_trk IS NULL THEN
         :NEW.mfg_date_trk := 'N';
      END IF;
      IF :NEW.exp_date_trk IS NULL THEN
         :NEW.exp_date_trk := 'N';
      END IF;

      --
      -- 09/26/07 Brian Bent
      -- If the item was changed from non-splitable to splitable and the
      -- case is in the miniloader then set the split_zone_id to the zone_id
      -- and set l_split_rule_id to l_case_rule_id.  SUS can make the item
      -- splitable which will be sent to SWMS through the IM queue.
      -- This is under the assumption that the case and splits for an item
      -- will be in the same miniloader.
      --
      IF (NVL(:OLD.split_trk, 'N') = 'N' AND :NEW.split_trk = 'Y'
          AND l_case_rule_id = 3) THEN
         :NEW.split_zone_id := :NEW.zone_id;
         l_split_rule_id := l_case_rule_id;
      END IF;

      /******** BEG ADD ACPVXG 17-Jan-05 ******************/
      IF (l_case_rule_id = 3 OR l_split_rule_id = 3) THEN
         :NEW.miniload_storage_ind  := 'B';
         IF ((l_case_rule_id != 3) OR (l_case_rule_id IS NULL)) THEN
            :NEW.miniload_storage_ind  := 'S';
         END IF;
      ELSE
         :NEW.miniload_storage_ind := 'N';
      END IF;
	/********* END ADD ACPVXG 17-Jan-05 *****************/

      /* Insert IMT transaction to track changes on PM attributes */
      IF NVL(:OLD.lot_trk, 'x') !=  NVL(:NEW.lot_trk, 'x') OR
         NVL(:OLD.catch_wt_trk, 'x') != NVL(:NEW.catch_wt_trk, 'x') OR
         NVL(:OLD.temp_trk, 'x') != NVL(:NEW.temp_trk, 'x') THEN
         l_cmt := 'Old/New lot_trk=' || :OLD.lot_trk || '/' || :NEW.lot_trk ||
                  ',' || 'Old/New wt_trk=' || :OLD.catch_wt_trk || '/' || :NEW.catch_wt_trk ||
                  ',' || 'Old/New temp_trk=' || :OLD.temp_trk || '/' || :NEW.temp_trk;
         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      IF NVL(:OLD.split_trk, 'x') != NVL(:NEW.split_trk, 'x') OR
         NVL(:OLD.spc, -1) != NVL(:NEW.spc, -1) OR
         NVL(:OLD.auto_ship_flag, 'x') != NVL(:NEW.auto_ship_flag, 'x') THEN
         l_cmt := 'Old/New split_trk=' || :OLD.split_trk || '/' || :NEW.split_trk ||
                  ',' || 'Old/New spc=' || TO_CHAR(:OLD.spc) || '/' || TO_CHAR(:NEW.spc) ||
                  ',' || 'Old/New auto_ship_flag=' || :OLD.auto_ship_flag || '/' || :NEW.auto_ship_flag;
         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      IF NVL(:OLD.mfr_shelf_life, -1) != NVL(:NEW.mfr_shelf_life, -1) OR
         NVL(:OLD.sysco_shelf_life, -1) != NVL(:NEW.sysco_shelf_life, -1) OR
         NVL(:OLD.cust_shelf_life, -1) != NVL(:NEW.cust_shelf_life, -1) THEN
         l_cmt := 'Old/New MfrSlfLife=' || :OLD.mfr_shelf_life || '/' || :NEW.mfr_shelf_life ||
                  ',' || 'Old/New SyscoSlfLife=' || :OLD.sysco_shelf_life || '/' || :NEW.sysco_shelf_life ||
                  ',' || 'Old/New CustSlfLife=' || :OLD.cust_shelf_life || '/' || :NEW.cust_shelf_life;
         
         -- SWMS_212 Ware house attibutes changed. Update flage

         l_warehouse_upd := 'Y';
         
         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      IF NVL(:OLD.hazardous, 'x') != NVL(:NEW.hazardous, 'x') OR
         NVL(:OLD.category, 'x') != NVL(:NEW.category, 'x') THEN
         l_cmt := 'Old/New hazardous=' || :OLD.hazardous || '/' || :NEW.hazardous ||
                  ',' || 'Old/New category=' || :OLD.category || '/' || :NEW.category;
         INSERT INTO TRANS (trans_id, trans_type, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when the WEIGHT changes.
      --
      IF (NVL(:OLD.weight, -1) != NVL(:NEW.weight, -1)) THEN
         l_cmt := 'Old/New Wt='
              || TO_CHAR(:OLD.weight) || '/' || TO_CHAR(:NEW.weight);

         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when the AVG_WT or G_WEIGHT changes.
      --
      IF (   NVL(:OLD.avg_wt, -1)   != NVL(:NEW.avg_wt, -1) 
          OR NVL(:OLD.g_weight, -1) != NVL(:NEW.g_weight, -1) ) THEN
         l_cmt := 'Old/New Avg Wt='
              || TO_CHAR(:OLD.avg_wt) || '/' || TO_CHAR(:NEW.avg_wt)
              || ',' || 'Old/New Gross Wt='
              || TO_CHAR(:OLD.g_weight) || '/' || TO_CHAR(:NEW.g_weight);

         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when one of the following changes:
      --    - pallet_type
      --    - ti
      --    - hi
      --
      IF (   NVL(:OLD.pallet_type, 'x')  != NVL(:NEW.pallet_type, 'x') 
          OR NVL(:OLD.ti, -1)            != NVL(:NEW.ti, -1) 
          OR NVL(:OLD.hi, -1)            != NVL(:NEW.hi, -1) ) THEN
         l_cmt := 'Old/New Plt Type='
              || :OLD.pallet_type || '/' || :NEW.pallet_type
              || ',' || 'Old/New TI='
              || TO_CHAR(:OLD.ti) || '/' || TO_CHAR(:NEW.ti)
              || ',' || 'Old/New HI='
              || TO_CHAR(:OLD.hi) || '/' || TO_CHAR(:NEW.hi);
         
         -- SWMS_212 Ware house attibutes changed. Update flage
         l_warehouse_upd := 'Y';
         
         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when one of the following changes:
      --    - exp_date_trk
      --    - mfg_date_trk
      --    - fifo_trk
      -- The comment squished together so the complete value will display in
      -- the transction screen without having to scroll.
      --
      IF (   NVL(:OLD.exp_date_trk, 'x')  != NVL(:NEW.exp_date_trk, 'x')
          OR NVL(:OLD.mfg_date_trk, 'x')  != NVL(:NEW.mfg_date_trk, 'x')
          OR NVL(:OLD.fifo_trk, 'x')      != NVL(:NEW.fifo_trk, 'x') ) THEN
         l_cmt := 'Old/New ExpDate Tk='
              || :OLD.exp_date_trk || '/' || :NEW.exp_date_trk
              || ',' || 'Old/New MfgDate Tk='
              || :OLD.mfg_date_trk || '/' || :NEW.mfg_date_trk
              || ',' || 'Old/New FIFO='
              || :OLD.fifo_trk || '/' || :NEW.fifo_trk;

         -- SWMS_212 Ware house attibutes changed. Update flage

         l_warehouse_upd := 'Y';
         
         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when one of the following changes:
      --    - min_qty
      --    - max_qty
      --
      IF (   NVL(:OLD.min_qty, -1)     != NVL(:NEW.min_qty, -1) 
          OR NVL(:OLD.max_qty, -1)     != NVL(:NEW.max_qty, -1) ) THEN
         l_cmt := 'Old/New Min Qty='
              || TO_CHAR(:OLD.min_qty) || '/' || TO_CHAR(:NEW.min_qty)
              || ',' || 'Old/New Max Qty='
              || TO_CHAR(:OLD.max_qty) || '/' || TO_CHAR(:NEW.max_qty);

         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when one of the following changes:
      --    - stackable
      --    - case_pallet
      --
      IF (   NVL(:OLD.stackable, -1)   != NVL(:NEW.stackable, -1)
          OR NVL(:OLD.case_pallet, -1) != NVL(:NEW.case_pallet, -1) ) THEN
         l_cmt := 'Old/New Stackable='
              || TO_CHAR(:OLD.stackable) || '/' || TO_CHAR(:NEW.stackable)
              || ',' || 'Old/New Case Pallet='
              || TO_CHAR(:OLD.case_pallet) || '/' || TO_CHAR(:NEW.case_pallet);

         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when one of the following changes:
      --    - abc
      --    - pallet_stack
      --
      IF (   NVL(:OLD.abc, 'x')          != NVL(:NEW.abc, 'x') 
          OR NVL(:OLD.pallet_stack, -1)  != NVL(:NEW.pallet_stack, -1))
      THEN
         l_cmt := 'Old/New ABC='
              || :OLD.abc || '/' || :NEW.abc
              || ',' || 'Old/New Pallet Stack='
              || TO_CHAR(:OLD.pallet_stack) || '/'
              || TO_CHAR(:NEW.pallet_stack);

         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when one of the following changes:
      --    - case_qty_per_carrier
      --
      IF (NVL(:OLD.case_qty_per_carrier, -1) 
                                  != NVL(:NEW.case_qty_per_carrier, -1)) THEN
         l_cmt := 'Old/New Cases Per Carrier='
              || TO_CHAR(:OLD.case_qty_per_carrier) || '/'
              || TO_CHAR(:NEW.case_qty_per_carrier);

         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      --
      -- Create IMT transaction when one of the following changes:
      --    - mfg_sku
      --
      IF (NVL(:OLD.mfg_sku, 'x') != NVL(:NEW.mfg_sku, 'x')) THEN
         l_cmt := 'Old/New Mfg SKU='
              || :OLD.mfg_sku || '/' || :NEW.mfg_sku;

         INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
                            prod_id, cust_pref_vendor, cmt)
              VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
                      :OLD.prod_id, :OLD.cust_pref_vendor, l_cmt);
      END IF;

      -- Set case height to 99 if it is 0 or null.
      IF (NVL(:NEW.case_height, 0) = 0)  THEN
         :NEW.case_height := 99;
      END IF;

      BEGIN
	l_cube_chg_syspar := pl_common.f_get_syspar('CUBE_CHG_FOR_DIM_CHG', 'N');
      EXCEPTION
	WHEN OTHERS THEN
		l_cube_chg_syspar := 'N';
      END;

      IF NVL(:OLD.case_cube, -1) != NVL(:NEW.case_cube, -1) THEN
	-- Cube has changed
	l_process := pl_text_log.g_process;
	pl_text_log.ins_msg('W', 'trg_insupd_pm_brow',
		'Item[' || :NEW.prod_id || '] process[' ||
		l_process || '] Case cube changed old/new[' ||
		TO_CHAR(:OLD.case_cube) ||
		'/' || TO_CHAR(:NEW.case_cube) || '] hght[ ' ||
		TO_CHAR(:OLD.case_height) || '/' || TO_CHAR(:NEW.case_height) ||
		'] wdth[' || TO_CHAR(:OLD.case_width) || '/' ||
		TO_CHAR(:NEW.case_width) || '] len[' ||
		TO_CHAR(:OLD.case_length) || '/' || TO_CHAR(:NEW.case_length)
		|| ']',
		NULL, NULL);
	FOR cguh IN c_get_upd_hist(:NEW.prod_id, l_process) LOOP
		l_field_beg := INSTR(cguh.msg_text, 'caseCube') + LENGTH('caseCube') + 1;
		l_field_end := INSTR(cguh.msg_text, '/', l_field_beg);
		l_old_cube := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		l_field_beg := INSTR(cguh.msg_text, '/', l_field_end) + 1;
		l_field_end := INSTR(cguh.msg_text, ']', l_field_beg);
		l_new_cube := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		l_field_beg := INSTR(cguh.msg_text, 'hght') + LENGTH('hght') + 1;
		l_field_end := INSTR(cguh.msg_text, '/', l_field_beg);
		l_old_hght := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		l_field_beg := INSTR(cguh.msg_text, '/', l_field_end) + 1;
		l_field_end := INSTR(cguh.msg_text, ']', l_field_beg);
		l_new_hght := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		l_field_beg := INSTR(cguh.msg_text, 'wdth') + LENGTH('wdth') + 1;
		l_field_end := INSTR(cguh.msg_text, '/', l_field_beg);
		l_old_wdth := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		l_field_beg := INSTR(cguh.msg_text, '/', l_field_end) + 1;
		l_field_end := INSTR(cguh.msg_text, ']', l_field_beg);
		l_new_wdth := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		l_field_beg := INSTR(cguh.msg_text, 'len') + LENGTH('len') + 1;
		l_field_end := INSTR(cguh.msg_text, '/', l_field_beg);
		l_old_len := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		l_field_beg := INSTR(cguh.msg_text, '/', l_field_end) + 1;
		l_field_end := INSTR(cguh.msg_text, ']', l_field_beg);
		l_new_len := SUBSTR(cguh.msg_text, l_field_beg, l_field_end -  l_field_beg);
		IF (NVL(l_old_hght, -1) != NVL(l_new_hght, -1) OR 
		    NVL(l_old_wdth, -1) != NVL(l_new_wdth, -1) OR
		    NVL(l_old_len, -1) != NVL(l_new_len, -1)) AND
		   NVL(l_old_cube, -1) != NVL(l_new_cube, -1) AND
		   l_cube_chg_syspar = 'Y' THEN
			:NEW.case_cube := TO_NUMBER(l_new_cube);
			pl_text_log.ins_msg('W', 'trg_insupd_pm_brow',
				'Case cube previously changed due to dim changes: ' ||
				'Item[' || :NEW.prod_id ||
				'] Case cube changed old/new[' || l_old_cube ||
				'/' || TO_CHAR(:NEW.case_cube) || '] hght[ ' ||
                                l_old_hght || '/' || l_new_hght || '] wdth[' ||
                                l_old_wdth || '/' || l_new_wdth || '] len[' ||
                                l_old_len || '/' || l_new_len || ']',
                                NULL, NULL);
		END IF;
	END LOOP;

	:NEW.split_cube := :NEW.case_cube / NVL(:NEW.spc, 1);
	-- Create IMT transaction for cube change
	INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
		prod_id, cust_pref_vendor, cmt)
	VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
		:OLD.prod_id, :OLD.cust_pref_vendor,
		'1 Old/New case cube=' ||
		TO_CHAR(ROUND(:OLD.case_cube, 3))  || '/' ||
		TO_CHAR(ROUND(:NEW.case_cube, 3)) || ' ' ||
		'Old/New split cube=' ||
		TO_CHAR(ROUND(:OLD.split_cube, 3))  || '/' ||
		TO_CHAR(ROUND(:NEW.split_cube, 3)));
      END IF;

      IF (NVL(:OLD.case_height, -1) != NVL(:NEW.case_height, -1) OR
	  NVL(:OLD.case_width, -1) != NVL(:NEW.case_width, -1) OR
	  NVL(:OLD.case_length, -1) != NVL(:NEW.case_length, -1)) THEN
--	 :NEW.rdc_vendor_id IS NULL THEN
	-- At least one of the dimensions has changed
	pl_text_log.ins_msg('W', 'trg_insupd_pm_brow',
		'Item[' || :NEW.prod_id || '] ' ||
		'Case dims changed hght old/new[' || TO_CHAR(:OLD.case_height) ||
		'/' || TO_CHAR(:NEW.case_height) || '] wdth[' ||
		TO_CHAR(:OLD.case_width) || '/' || TO_CHAR(:NEW.case_width) ||
		'] len[' || TO_CHAR(:OLD.case_length) || '/' ||
		TO_CHAR(:NEW.case_length) || '] caseCube[' ||
		TO_CHAR(:OLD.case_cube) || '/' || TO_CHAR(:NEW.case_cube) || ']',
		NULL, NULL);
	l_process := pl_text_log.g_process;
	-- Create IMT transaction for dimension change
	INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
		prod_id, cust_pref_vendor, cmt)
	VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
		:OLD.prod_id, :OLD.cust_pref_vendor,
		'Old/New case height=' ||
		TO_CHAR(ROUND(:OLD.case_height, 3))  || '/' ||
		TO_CHAR(ROUND(:NEW.case_height, 3)) || ' ' ||
		'Old/New case width=' ||
		TO_CHAR(ROUND(:OLD.case_width, 3))  || '/' ||
		TO_CHAR(ROUND(:NEW.case_width, 3)) || ' ' ||
		'Old/New case length=' ||
		TO_CHAR(ROUND(:OLD.case_length, 3))  || '/' ||
		TO_CHAR(ROUND(:NEW.case_length, 3)));
	IF (NVL(:NEW.case_height, 0) NOT IN (0, 99) AND
	    NVL(:NEW.case_width, 0) <> 0 AND
	    NVL(:NEW.case_length, 0) <> 0) AND
	   l_cube_chg_syspar = 'Y' THEN
		-- Recalculate case and split cubes but ignore changed
		-- values in 0 and 99 (case height only)
		pl_text_log.ins_msg('W', 'trg_insupd_pm_brow',
			'Item[' || :NEW.prod_id || '] ' ||
			'Case dims changed w/ recalculated cube before: ' ||
			'old/new caseCube[' || TO_CHAR(:OLD.case_cube) || '/' ||
			TO_CHAR(:NEW.case_cube) || '] splitCube[' ||
			TO_CHAR(:OLD.split_cube) || '/' ||
			TO_CHAR(:NEW.split_cube) || ']',
			NULL, NULL);
		-- Formular for sites with dimensions by inches
		/* Calculate case_cube and split_cube based on the syspar LENGHT_UNIT */
		
		IF (pl_common.f_get_syspar('LENGTH_UNIT','IN') = 'CM') THEN
		
			:NEW.case_cube := to_char((:NEW.case_height * :NEW.case_width *
			:NEW.case_length),'99999999.9999');
			
			:NEW.split_cube  := to_char((:NEW.case_cube / NVL(:NEW.spc, 1)),'99999999.9999');
			
		ELSE
		
			:NEW.case_cube := (:NEW.case_height * :NEW.case_width *
			:NEW.case_length) / 1728;
				
			:NEW.split_cube := :NEW.case_cube / NVL(:NEW.spc, 1);			
				
		END IF;


		pl_text_log.ins_msg('W', 'trg_insupd_pm_brow',
			'Item[' || :NEW.prod_id || '] ' ||
			'Case dims changed w/ recalculated cube after: ' ||
			'old/new caseCube[' || :OLD.case_cube || '/' ||
			:NEW.case_cube || '] splitCube[' ||
			:OLD.split_cube || '/' || :NEW.split_cube ||
			'] hght[' || TO_CHAR(:OLD.case_height) || '/' ||
			TO_CHAR(:NEW.case_height) || ' wdth[' ||
			TO_CHAR(:OLD.case_width) || '/' ||
			TO_CHAR(:NEW.case_width) || '] len[' ||
			TO_CHAR(:OLD.case_length) || '/' ||
			TO_CHAR(:NEW.case_length) || ']',
			NULL, NULL);
		pl_log.ins_msg('WARN', 'trg_insupd_pm_brow',
			'Item[' || :NEW.prod_id || '] process[' ||
			l_process || '] ' ||
			'Case dims changed w/ recalculated cube after: ' ||
			'old/new caseCube[' || :OLD.case_cube || '/' ||
			:NEW.case_cube || '] splitCube[' ||
			:OLD.split_cube || '/' || :NEW.split_cube ||
			'] hght[' || TO_CHAR(:OLD.case_height) || '/' ||
			TO_CHAR(:NEW.case_height) || '] wdth[' ||
			TO_CHAR(:OLD.case_width) || '/' ||
			TO_CHAR(:NEW.case_width) || '] len[' ||
			TO_CHAR(:OLD.case_length) || '/' ||
			TO_CHAR(:NEW.case_length) || ']',
			NULL, NULL);
		-- Create IMT transaction for cube change
		INSERT INTO TRANS (trans_id, TRANS_TYPE, trans_date, user_id,
			prod_id, cust_pref_vendor,
			cmt)
		VALUES (trans_id_seq.NEXTVAL, 'IMT', SYSDATE, USER,
			:OLD.prod_id, :OLD.cust_pref_vendor,
			'2 Old/New case cube=' ||
			TO_CHAR(ROUND(:OLD.case_cube, 3))  || '/' ||
			TO_CHAR(ROUND(:NEW.case_cube, 3)) || ' ' ||
			'Old/New split cube=' ||
			TO_CHAR(ROUND(:OLD.split_cube, 3))  || '/' ||
			TO_CHAR(ROUND(:NEW.split_cube, 3)));
	END IF;
      END IF;

   IF :NEW.case_cube = 0 THEN 
      -- ticket: OPCOF-3807
      -- case_cube values cannot be 0. this causes issues when generating routes
      :NEW.case_cube := 1;
      pl_text_log.ins_msg('W', 'trg_insupd_pm_brow', 'Item[' || :NEW.prod_id || 
         '] case_cube was update to 1 from 0. case_cube cannot be 0 as it causes route generation to fail', 
         NULL, NULL);
   END IF;

	--
	-- If the case height changed and putaway is by inches then create an
	-- IMT transaction to record the case height change and save the item
	-- and CPV in a PL/SQL table.  The PL/SQL table is be used by an after
	-- update statement trigger on the PM table to re-calculate the
	-- the pallet height for the existing inventory and the location occupied
	-- and available heights.
	IF ( (NVL(:OLD.case_height, -1) != NVL(:NEW.case_height, -1)) AND
	   (pl_common.f_get_syspar('PUTAWAY_DIMENSION', 'C') = 'I') ) THEN
		BEGIN  -- Start a new block to trap errors
            		l_index :=
			pl_putaway_utilities.g_r_item_info_for_inches_tbl.COUNT + 1;
			pl_putaway_utilities.g_r_item_info_for_inches_tbl(l_index).prod_id :=
				:NEW.prod_id;
			pl_putaway_utilities.g_r_item_info_for_inches_tbl(l_index).cust_pref_vendor :=
				:NEW.cust_pref_vendor;
		EXCEPTION
			WHEN OTHERS THEN
				--
				-- Failure to store the item in the PL/SQL table will not stop
				-- processing.  An aplog message will be created.
				--
				Pl_Log.ins_msg('WARNING', l_object_name,
					'Item[' || :NEW.prod_id || ']'
					|| '  CPV[' || :NEW.cust_pref_vendor || ']'
					|| '  old case height[' || TO_CHAR(:OLD.case_height) || ']'
					|| '  new case height[' || TO_CHAR(:NEW.case_height) || ']'
					|| '  Case height changed, putaway by inches is on.'
					|| '  Failed to save teh itgem to the PL/SQL table.'
					|| '  This will not stop processing.',
					SQLCODE, SQLERRM, 'INVENTORY', l_object_name);
		END;
	END IF;  -- end check if case height changes and putaway dimension is by inch

      -- Set case height to 99 if it is 0 or null.
      IF (NVL(:NEW.case_height, 0) = 0)  THEN
         :NEW.case_height := 99;
      END IF;

      --
      -- 09/26/07 Brian Bent
      -- Send a new SKU message to the miniloader for the split item if a
      -- non-splitable item is made splitable and the case is in the
      -- miniloader.
      -- Send a modify SKU message to the miniloader:
      --    - When the item description changes.
      --          -  Send one for the case SKU if cases are in the miniloader.
      --          -  Send one for the split SKU if splits are in the miniloader.
      --    - When the case qty per carrier changes except if the new value is
      --      0 or null.
      --          -  Send one for the case SKU if cases are in the miniloader.
      --          -  Send one for the split SKU if splits are in the miniloader.
      --            
      
      IF (:NEW.miniload_storage_ind = 'N') THEN
         --
         -- Not a miniload item.
         --         
         NULL;
      ELSIF (:NEW.miniload_storage_ind IN ('S', 'B')) THEN
         --
         -- Processing a miniloader item.
         --
         DECLARE -- Start a new block to trap errors
            l_case_qty_per_carrier  PM.case_qty_per_carrier%TYPE;
            l_cmt                   MINILOAD_TRANS.cmt%TYPE := NULL; -- Comment
                                                  -- for the MNI transaction.
            l_new_compare_string    VARCHAR2(200);  -- Old column values
                                                    -- combined into one value.
            l_old_compare_string    VARCHAR2(200);  -- New column values
                                                    -- combined into one value.
            l_status                NUMBER;  -- Status of procedure call.
            l_what_to_send          PLS_INTEGER := NULL;  -- What needs to be
                                           -- sent to the miniloader.  It will
                                           -- be populated with a constant from
                                           -- pl_miniload_processing.
			l_zone_id 		 	    PM.zone_id%TYPE := NULL;
			l_split_zone_id 		PM.zone_id%TYPE := NULL; 					   
         BEGIN
            --
            -- Call the procedure to send the new/modify SKU only when
            -- something relevant to the miniloader has changed.
            --
            -- Combine the relevant fields into one value then use this in
            -- the comparisons.
            --
            l_old_compare_string :=
                  NVL(:OLD.descrip, 'x') || TO_CHAR(:OLD.case_qty_per_carrier);
            l_new_compare_string :=
                  NVL(:NEW.descrip, 'x') || TO_CHAR(:NEW.case_qty_per_carrier);
	  		
            IF (:OLD.zone_id != :NEW.zone_id AND :NEW.zone_id IS NOT NULL) THEN
               l_zone_id := :NEW.zone_ID; 
            ELSE
               l_zone_id := :OLD.zone_id;
            END IF;

            IF (:OLD.split_zone_id IS NOT NULL
                 OR :NEW.split_zone_id IS NOT NULL) THEN						
               IF ((:OLD.split_zone_id != :NEW.split_zone_id)
                    AND :NEW.split_zone_id IS NOT NULL) THEN
                  l_split_zone_id := :NEW.zone_ID; 
               ELSE		
                  l_split_zone_id := :OLD.zone_id;
               END IF;	
            END IF;

            IF (:NEW.miniload_storage_ind = 'B') THEN
               --
               -- Both cases and splits (if splitable) are stored in the
               -- miniloader.
               --
               IF (NVL(:OLD.split_trk, 'N') = 'N' AND :NEW.split_trk = 'Y') THEN
                  --
                  -- Non splitable item made splitable.  New SKU for split
                  -- needs to be sent and if there are other changes to the
                  -- item then send modify SKU for case.
                  --
                  IF (l_old_compare_string != l_new_compare_string) THEN
                     --
                     -- Item made splitable and item changed.  Send modify
                     -- SKU for case and new SKU for split to the miniloader.
                     --
                     l_what_to_send :=
                           pl_miniload_processing.CT_SEND_SKU_MOD_CS_NEW_SP;

                     l_cmt := 'SPLIT TRK CHANGED FROM N TO Y.  ITEM CHANGED.'
                              || '  NEW SKU SENT FOR SPLIT.'
                              || '  MODIFY SKU SENT FOR CASE.';
                  ELSE
                     --
                     -- Item made splitable.  Nothing else relevant to the
                     -- miniloader was changed.  Send new SKU for split to
                     -- the miniloader.
                     --
                     l_what_to_send :=
                           pl_miniload_processing.CT_SEND_SKU_NEW_SP;

                     l_cmt := 'SPLIT TRK CHANGED FROM N TO Y.  NOTHING ELSE'
                              || ' CHANGED RELEVANT TO THE ML.'
                              || '  NEW SKU SENT FOR SPLIT.';
                  END IF;
               ELSIF (:NEW.split_trk = 'N' AND
                      l_old_compare_string != l_new_compare_string) THEN
                  --
                  -- Not a split track item and item changed.  Send a modify
                  -- SKU for case.
                  --
                  l_what_to_send := pl_miniload_processing.CT_SEND_SKU_MOD_CS;

                  l_cmt := 'ITEM CHANGED.  NOT SPLITABLE.'
                           || '  MODIFY SKU SENT FOR CASE.';
               ELSIF (:NEW.split_trk = 'Y' AND
                      l_old_compare_string != l_new_compare_string) THEN
                  --
                  -- Split track item and item changed.  Send a modify
                  -- SKU for case and a modify SKU for split.
                  --
                  l_what_to_send :=
                             pl_miniload_processing.CT_SEND_SKU_MOD_CS_MOD_SP;

                  l_cmt := 'ITEM CHANGED AND IS SPLITABLE.'
                           || '  MODIFY SKU SENT FOR CASE.'
                           || '  MODIFY SKU SENT FOR SPLIT.';
               ELSE
                  --
                  -- No fields relevant to the miniloader were changed.
                  --
                  NULL;
               END IF;  -- end IF (:NEW.miniload_storage_ind = 'B')
            ELSIF (:NEW.miniload_storage_ind = 'S') THEN
               --
               -- Only splits are stored in the miniloader.
               --
               IF (l_old_compare_string != l_new_compare_string) THEN
                  --
                  -- Only splits are in the miniloader and the item changed.
                  -- Send a modify SKU for split.
                  --
                  l_what_to_send :=
                           pl_miniload_processing.CT_SEND_SKU_MOD_SP;

                  l_cmt := 'ITEM CHANGED AND ONLY SPLITS ARE IN THE'
                           || ' MINILOADER.'
                           || '  MODIFY SKU SENT FOR SPLIT.';
               END IF;
            ELSE
               --
               -- Should never reach this point since it indicates the
               -- :NEW.miniload_storage_ind is not B or S and we checked
               -- checked for B or S before entering this--there is a flaw
               -- in the logic.
               -- Write an aplog message and keep processing.
               --
               Pl_Log.ins_msg('WARNING', l_object_name,
                  'Item[' || :NEW.prod_id || ']'
                  || '  CPV[' || :NEW.cust_pref_vendor || ']'
                  || '  miniload storage ind[' || :NEW.miniload_storage_ind
                  || ']'
                  || '  Flaw in program logic.  Did not handle value for'
                  || ' the miniload storage ind.'
                  || '  This will not stop processing.',
                  NULL, NULL, 'INVENTORY', l_object_name);
            END IF;

            IF (l_what_to_send IS NOT NULL) THEN
               --
               -- We need to send a new/modify SKU to the miniloader.
               --
               -- Use the old case_qty_per_carrier if the new is null or 0
               -- and if the old one is null use 1.
               --
               l_case_qty_per_carrier := :NEW.case_qty_per_carrier;
               IF (NVL(l_case_qty_per_carrier, 0) = 0) THEN
                  l_case_qty_per_carrier := NVL(:OLD.case_qty_per_carrier, 1);
               END IF;

               --
               -- 09/21/07  Brian Bent  In the future if it gets to the point
               -- that many fields are passed as parameters to send_SKU_change
               -- then we can create a record and pass the record as a
               -- parameter.
               --
               pl_miniload_processing.send_SKU_change
                                      (l_what_to_send,
                                       :NEW.prod_id,
                                       :NEW.cust_pref_vendor,
                                       :NEW.descrip,
                                       :NEW.spc,
                                       l_case_qty_per_carrier,
                                       l_cmt,
                                       l_zone_id,
                                       l_split_zone_id,
                                       l_status);

               IF (l_status != pl_miniload_processing.CT_SUCCESS) THEN
                  pl_log.ins_msg('WARNING', l_object_name,
                      'l_what_to_send[' || TO_CHAR(l_what_to_send) || ']'
                      || '  Item[' || :NEW.prod_id || ']'
                      || '  CPV[' || :NEW.cust_pref_vendor || ']'
                      || '  miniload storage ind[' || :NEW.miniload_storage_ind
                      || ']'
                      || '   pl_miniload_processing.send_SKU_change'
                      || ' returned failure status sending new/modify'
                      || ' SKU to the miniloader.'
                      || '  This will not stop processing.',
                      NULL, NULL, 'INVENTORY', l_object_name);
               END IF;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               --
               -- Encoutered an error when attempting to send the new/modify
               -- SKU to the miniloader.  Write an aplog message.  Do not stop
               -- processing.
               --
               Pl_Log.ins_msg('WARNING', l_object_name,
                      'l_what_to_send[' || TO_CHAR(l_what_to_send) || ']'
                   || '  Item[' || :NEW.prod_id || ']'
                   || '  CPV[' || :NEW.cust_pref_vendor || ']'
                   || '  miniload storage ind[' || :NEW.miniload_storage_ind
                   || ']'
                   || '  Failed sending new/modify SKU to the'
                   || ' miniloader.  This will not stop processing.',
                   SQLCODE, SQLERRM, 'INVENTORY', l_object_name);
         END;
    
      ELSE
         --
         -- Unhandled value for :NEW.miniload_storage_ind.
         -- Write an aplog message.  Do not stop processing.
         --
         Pl_Log.ins_msg('WARNING', l_object_name,
                  'Item[' || :NEW.prod_id || ']'
                  || '  CPV[' || :NEW.cust_pref_vendor || ']'
                  || '  miniload storage ind[' || :NEW.miniload_storage_ind
                  || ']'
                  || '  Unhandled value for the miniload storage ind.'
                  || '  This will not stop processing.',
                  NULL, NULL, 'INVENTORY', l_object_name);
      END IF;  -- end processing if a new/modify sku needs to send to the
               -- miniloader

-- D#12404
         if ( :old.miniload_storage_ind != :NEW.miniload_storage_ind ) OR
            ( :old.case_qty_per_carrier != :NEW.case_qty_per_carrier) THEN

         -- SWMS_212 Ware house attibutes changed. Update flage

         l_warehouse_upd := 'Y';
         
            insert into HACCP_PM_HIST
            (change_date, prod_id, cust_pref_vendor,hazardous, old_lot_trk,
             new_lot_trk, old_temp_trk, new_temp_trk, old_max_temp, new_max_temp,
             ti, hi, abc, mfr_shelf_life, pallet_type, sysco_shelf_life, fifo_trk,
             cust_shelf_life, exp_date_trk, mfg_date_trk, min_temp, upload_date)
             VALUES
             (sysdate, :new.prod_id, :new.cust_pref_vendor, :new.hazardous, null,
              :new.lot_trk, null, :new.temp_trk, null, :new.max_temp, :new.ti, :new.hi,
              :new.abc, :new.mfr_shelf_life, :new.pallet_type, :new.sysco_shelf_life, :new.fifo_trk,
              :new.cust_shelf_life, :new.exp_date_trk, :new.mfg_date_trk, :new.min_temp, NULL);

         END IF;
-- END D#12404


      IF (:OLD.miniload_storage_ind = 'N' AND
          :NEW.miniload_storage_ind IN ('B', 'S')) THEN
         --
         -- The item was slotted to the miniloader.  Send the planned orders
         -- to the miniloader that were sent down before the item was slotted.
         --
         DECLARE  -- Start a new block to trap errors
            l_status   PLS_INTEGER;

            -- Record for the item info.
            l_r_item_info_planned_order
                               pl_planned_order.t_r_item_info_planned_order;
         BEGIN
            l_r_item_info_planned_order.prod_id        := :NEW.prod_id;
            l_r_item_info_planned_order.cust_pref_vendor :=
                                                    :NEW.cust_pref_vendor;
            l_r_item_info_planned_order.spc            := :NEW.spc;
            l_r_item_info_planned_order.auto_ship_flag := :NEW.auto_ship_flag;
            l_r_item_info_planned_order.miniload_storage_ind :=
                                                    :NEW.miniload_storage_ind;

            --
            -- Write a log message to note what is happening.
            --
               pl_log.ins_msg('INFO', l_object_name,
                      'Item[' || :NEW.prod_id || ']'
                      || '  CPV[' || :NEW.cust_pref_vendor || ']'
                      || ' OLD miniload_storage_ind['
                      || :OLD.miniload_storage_ind || ']'
                      || ' NEW miniload storage ind['
                      || :NEW.miniload_storage_ind || ']'
                      || '  Item slotted to the miniloader.  Send todays'
                      || ' planned orders to the miniloader that were sent'
                      || ' to SWMS before the item was slotted.',
                      NULL, NULL, 'INVENTORY', l_object_name);

            pl_planned_order.ml_send_plan_orders_for_item
                  (i_r_item_info_planned_order => l_r_item_info_planned_order,
                   i_order_date                => TRUNC(SYSDATE),
                   o_status                    => l_status);

            IF (l_status != pl_miniload_processing.CT_SUCCESS) THEN
               pl_log.ins_msg('WARNING', l_object_name,
                      'Item[' || :NEW.prod_id || ']'
                      || '  CPV[' || :NEW.cust_pref_vendor || ']'
                      || ' OLD miniload_storage_ind['
                      || :OLD.miniload_storage_ind || ']'
                      || ' NEW miniload storage ind['
                      || :NEW.miniload_storage_ind || ']'
                      || '   pl_planned_order.ml_send_plan_orders_for_item'
                      || ' returned failure status.'
                      || '  This will not stop processing.',
                      NULL, NULL, 'INVENTORY', l_object_name);
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               --
               -- Encountered an error sending the planned order to the
               -- miniloader.  Write an aplog message.  Do not stop
               -- processing.
               --
               pl_log.ins_msg('WARNING', l_object_name,
                      'Item[' || :NEW.prod_id || ']'
                   || '  CPV[' || :NEW.cust_pref_vendor || ']'
                   || ' OLD miniload_storage_ind[' || :OLD.miniload_storage_ind
                   || ']'
                   || ' NEW miniload storage ind[' || :NEW.miniload_storage_ind
                   || ']'
                   || '  Failed sending planned orders to the miniloader.'
                   || '  This will not stop processing.',
                   SQLCODE, SQLERRM, 'INVENTORY', l_object_name);
         END;
      END IF;


	IF NVL(:old.mfg_date_trk, 'N') <> NVL(:new.mfg_date_trk, 'N') THEN
	    Pl_Log.ins_msg('WARNING', l_object_name,
		'Item[' || :new.prod_id || '] ' ||
		'CPV[' || :new.cust_pref_vendor || '] ' ||
		'Chg TrkMfgDate PM[<' || :old.mfg_date_trk || '> to <' ||
		:new.mfg_date_trk || '>] This will not stop processing.',
		NULL, NULL, 'PM', l_object_name);
	    BEGIN
	    FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
		:new.mfg_date_trk, 1) LOOP
	        BEGIN
		    UPDATE putawaylst
		    SET date_code = NVL(:new.mfg_date_trk, 'N')
		    WHERE rec_id = cgp.rec_id
		    AND prod_id = cgp.prod_id
		    AND cust_pref_vendor = cgp.cust_pref_vendor;
		    Pl_Log.ins_msg('WARNING', l_object_name,
			'Item[' || :new.prod_id || '] ' ||
			'CPV[' || :new.cust_pref_vendor || '] ' ||
			'PO[' || cgp.rec_id || '] ' ||
			'MfgDateTrk PM[' || :new.mfg_date_trk || '] ' ||
			'PUTLST[' || cgp.date_code || '->' ||
			NVL(:new.mfg_date_trk, 'N') || '] ' ||
			'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
			'] This will not stop processing.',
			NULL, NULL, 'PUTAWAY', l_object_name);
		EXCEPTION
		    WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'MfgDateTrk PM[' || :new.mfg_date_trk || '] ' ||
				'PUTLST[' || cgp.date_code || '->' ||
				NVL(:new.mfg_date_trk, 'N') || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		END;
	    END LOOP;
	    EXCEPTION
		WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'MfgDateTrk PM[' || :new.mfg_date_trk || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
	    END;
	END IF;

	IF NVL(:old.exp_date_trk, 'N') <> NVL(:new.exp_date_trk, 'N') THEN
	    BEGIN
	    FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
		:new.exp_date_trk, 2) LOOP
		    Pl_Log.ins_msg('WARNING', l_object_name,
			'Item[' || :new.prod_id || '] ' ||
			'CPV[' || :new.cust_pref_vendor || '] ' ||
			'PO[' || cgp.rec_id || '] ' ||
			'ExpDateTrk PM[' || :new.exp_date_trk || '] ' ||
			'PUTLST[' || cgp.exp_date_trk || '->' ||
			NVL(:new.exp_date_trk, 'N') || '] ' ||
			'Before update putawaylst. ' ||
			'This will not stop processing.',
			NULL, NULL, 'PUTAWAY', l_object_name);
	        BEGIN
		    UPDATE putawaylst
		    SET exp_date_trk = NVL(:new.exp_date_trk, 'N')
		    WHERE rec_id = cgp.rec_id
		    AND prod_id = cgp.prod_id
		    AND cust_pref_vendor = cgp.cust_pref_vendor;
		    Pl_Log.ins_msg('WARNING', l_object_name,
			'Item[' || :new.prod_id || '] ' ||
			'CPV[' || :new.cust_pref_vendor || '] ' ||
			'PO[' || cgp.rec_id || '] ' ||
			'ExpDateTrk PM[' || :new.exp_date_trk || '] ' ||
			'PUTLST[' || cgp.exp_date_trk || '->' ||
			NVL(:new.exp_date_trk, 'N') || '] ' ||
			'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
			'] This will not stop processing.',
			NULL, NULL, 'PUTAWAY', l_object_name);
		EXCEPTION
		    WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'ExpDateTrk PM[' || :new.exp_date_trk || '] ' ||
				'PUTLST[' || cgp.exp_date_trk || '->' ||
				NVL(:new.exp_date_trk, 'N') || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		END;
	    END LOOP;
	    EXCEPTION
		WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'ExpDateTrk PM[' || :new.exp_date_trk || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
	    END;
	END IF;

	IF NVL(:old.lot_trk, 'N') <> NVL(:new.lot_trk, 'N') THEN
	    Pl_Log.ins_msg('WARNING', l_object_name,
		'Item[' || :new.prod_id || '] ' ||
		'CPV[' || :new.cust_pref_vendor || '] ' ||
		'Chg TrkLot PM[<' || :old.lot_trk || '> to <' ||
		:new.lot_trk || '>] This will not stop processing.',
		NULL, NULL, 'PM', l_object_name);
	    BEGIN
	    FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
		:new.lot_trk, 3) LOOP
	        BEGIN
		    UPDATE putawaylst
		    SET lot_trk = NVL(:new.lot_trk, 'N')
		    WHERE rec_id = cgp.rec_id
		    AND prod_id = cgp.prod_id
		    AND cust_pref_vendor = cgp.cust_pref_vendor;
		    Pl_Log.ins_msg('WARNING', l_object_name,
			'Item[' || :new.prod_id || '] ' ||
			'CPV[' || :new.cust_pref_vendor || '] ' ||
			'PO[' || cgp.rec_id || '] ' ||
			'LotTrk PM[' || :new.lot_trk || '] ' ||
			'PUTLST[' || cgp.lot_trk || '->' ||
			NVL(:new.lot_trk, 'N') || '] ' ||
			'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
			'] This will not stop processing.',
			NULL, NULL, 'PUTAWAY', l_object_name);
		EXCEPTION
		    WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'LotTrk PM[' || :new.lot_trk || '] ' ||
				'PUTLST[' || cgp.lot_trk || '->' ||
				NVL(:new.lot_trk, 'N') || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		END;
	    END LOOP;
	    EXCEPTION
		WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'LotTrk PM[' || :new.lot_trk || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
	    END;
	END IF;

	IF NVL(:old.catch_wt_trk, 'N') <> NVL(:new.catch_wt_trk, 'N') THEN
	    Pl_Log.ins_msg('WARNING', l_object_name,
		'Item[' || :new.prod_id || '] ' ||
		'CPV[' || :new.cust_pref_vendor || '] ' ||
		'Chg TrkCW PM[<' || :old.catch_wt_trk || '> to <' ||
		:new.catch_wt_trk || '>] This will not stop processing.',
		NULL, NULL, 'PM', l_object_name);
	    BEGIN
	    FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
		:new.catch_wt_trk, 4) LOOP
	        BEGIN
		    UPDATE putawaylst
		    SET catch_wt = NVL(:new.catch_wt_trk, 'N')
		    WHERE rec_id = cgp.rec_id
		    AND prod_id = cgp.prod_id
		    AND cust_pref_vendor = cgp.cust_pref_vendor;
		    Pl_Log.ins_msg('WARNING', l_object_name,
			'Item[' || :new.prod_id || '] ' ||
			'CPV[' || :new.cust_pref_vendor || '] ' ||
			'PO[' || cgp.rec_id || '] ' ||
			'CWTrk PM[' || :new.catch_wt_trk || '] ' ||
			'PUTLST[' || cgp.catch_wt || '->' ||
			NVL(:new.catch_wt_trk, 'N') || '] ' ||
			'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
			'] This will not stop processing.',
			NULL, NULL, 'PUTAWAY', l_object_name);
		EXCEPTION
		    WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'CWTrk PM[' || :new.catch_wt_trk || '] ' ||
				'PUTLST[' || cgp.catch_wt || '->' ||
				NVL(:new.catch_wt_trk, 'N') || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		END;
	    END LOOP;
	    EXCEPTION
		WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'CWTrk PM[' || :new.catch_wt_trk || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
	    END;
	END IF;

	IF NVL(:old.temp_trk, 'N') <> NVL(:new.temp_trk, 'N') THEN
	    Pl_Log.ins_msg('WARNING', l_object_name,
		'Item[' || :new.prod_id || '] ' ||
		'CPV[' || :new.cust_pref_vendor || '] ' ||
		'Chg TrkTemp PM[<' || :old.temp_trk || '> to <' ||
		:new.temp_trk || '>] This will not stop processing.',
		NULL, NULL, 'PM', l_object_name);
	    BEGIN
	    FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
		:new.temp_trk, 5) LOOP
	        BEGIN
		    UPDATE putawaylst
		    SET temp_trk = NVL(:new.temp_trk, 'N')
		    WHERE rec_id = cgp.rec_id
		    AND prod_id = cgp.prod_id
		    AND cust_pref_vendor = cgp.cust_pref_vendor;
		    Pl_Log.ins_msg('WARNING', l_object_name,
			'Item[' || :new.prod_id || '] ' ||
			'CPV[' || :new.cust_pref_vendor || '] ' ||
			'PO[' || cgp.rec_id || '] ' ||
			'TempTrk PM[' || :new.temp_trk || '->' ||
			NVL(:new.temp_trk, 'N') || '] ' ||
			'PUTLST[' || cgp.date_code || '] ' ||
			'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
			'] This will not stop processing.',
			NULL, NULL, 'PUTAWAY', l_object_name);
		EXCEPTION
		    WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'TempTrk PM[' || :new.temp_trk || '] ' ||
				'PUTLST[' || cgp.temp_trk || '->' ||
				NVL(:new.temp_trk, 'N') || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		END;
	    END LOOP;
	    EXCEPTION
		WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'TempTrk PM[' || :new.temp_trk || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
	    END;
	END IF;

	IF NVL(:old.hazardous, 'HS') <> NVL(:new.hazardous, 'HS') THEN
	    Pl_Log.ins_msg('WARNING', l_object_name,
		'Item[' || :new.prod_id || '] ' ||
		'CPV[' || :new.cust_pref_vendor || '] ' ||
		'Chg Haz PM[<' || :old.hazardous || '> to <' ||
		:new.hazardous || '>] This will not stop processing.',
		NULL, NULL, 'PM', l_object_name);
	    l_trk := pl_putaway_utilities.f_is_tti_tracked_item2(
			:old.hazardous);
			
	    l_chk2 := NULL;
	
		/*  Start CRQ 32935  Have added  if condition so that tti_trk value is changed properly*/
	
		IF (:new.hazardous IS NULL) THEN
			l_trk2:= FALSE;  
	        ELSE
                	l_trk2 := pl_putaway_utilities.f_is_tti_tracked_item2(:new.hazardous);
		END IF;
	
		/*  End CRQ 32935*/

		IF NOT (l_trk AND l_trk2) THEN
		IF (l_trk OR NOT l_trk2) THEN --CRQ 32935  Have changed if condition so that tti_trk value is changed properly
			l_chk2 := 'N';
		ELSE
			l_chk2 := 'Y';
		END IF;
		
		BEGIN
		FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
			l_chk2, 6) LOOP
		   BEGIN
			UPDATE putawaylst
			SET tti_trk = l_chk2
			WHERE rec_id = cgp.rec_id
			AND prod_id = cgp.prod_id
			AND cust_pref_vendor = cgp.cust_pref_vendor;
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'TTITrk PM haz[' || :old.hazardous || '->' ||
				:new.hazardous || '] ' ||
				'PUTLST[' || cgp.tti_trk || '->' ||
				l_chk2 || '] ' ||
				'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
				'] This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		   EXCEPTION
			WHEN OTHERS THEN
			    Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'TTITrk PM haz[' || :old.hazardous || '->' ||
				:new.hazardous || '] ' ||
				'PUTLST[' || cgp.tti_trk || '->' ||
				l_chk2 || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		   END;
		END LOOP;
		EXCEPTION
		   WHEN OTHERS THEN
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'TTITrk PM[' || :old.hazardous || '->' ||
				:new.hazardous || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
		END;
	    END IF;
	END IF;

	IF NVL(:old.category, 'XX') <> NVL(:new.category, 'XX') THEN
	    Pl_Log.ins_msg('WARNING', l_object_name,
		'Item[' || :new.prod_id || '] ' ||
		'CPV[' || :new.cust_pref_vendor || '] ' ||
		'Chg Cat PM[<' || :old.category || '> to <' ||
		:new.category || '>] This will not stop processing.',
		NULL, NULL, 'PM', l_object_name);
	    l_trk := pl_putaway_utilities.f_is_cool_tracked_item(
			:new.prod_id, :new.cust_pref_vendor, :old.category);
	    l_trk2 := pl_putaway_utilities.f_is_cool_tracked_item(
			:new.prod_id, :new.cust_pref_vendor, :new.category);
	    l_chk2 := NULL;
	    IF NOT (l_trk AND l_trk2) THEN
		IF l_trk AND NOT l_trk2 THEN
		    l_chk2 := 'N';	-- Cool to NotCool
		ELSIF NOT l_trk AND l_trk2 THEN
		    l_chk2 := 'Y';	-- NotCool to Cool
		ELSE
		    l_chk2 := NULL;	-- NotCool and NotCool
		END IF;
		IF l_chk2 IS NOT NULL THEN
		    BEGIN
		    FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
			l_chk2, 7) LOOP
		    BEGIN
			UPDATE putawaylst
			SET cool_trk = l_chk2
			WHERE rec_id = cgp.rec_id
			AND prod_id = cgp.prod_id
			AND cust_pref_vendor = cgp.cust_pref_vendor;
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'CoolTrk PM Cat[' || :old.category || '->' ||
				:new.category || '] ' ||
				'PUTLST[' || cgp.cool_trk || '->' ||
				l_chk2 || '] ' ||
				'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
				'] This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		    EXCEPTION
			WHEN OTHERS THEN
			    Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'CoolTrk PM Cat[' || :old.category || '->' ||
				:new.category || '] ' ||
				'PUTLST[' || cgp.cool_trk || '->' ||
				l_chk2 || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		    END;
		    END LOOP;
		    EXCEPTION
			WHEN OTHERS THEN
			    Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'CoolTrk PM[' || :old.category || '->' ||
				:new.category || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
		    END;
		END IF;
	    END IF;

	    l_syspar_clambed := pl_common.f_get_syspar('CLAM_BED_TRACKED', 'N');
	    l_trk := pl_putaway_utilities.f_is_clam_bed_tracked_item(
			:old.category, l_syspar_clambed);
	    l_trk2 := pl_putaway_utilities.f_is_clam_bed_tracked_item(
			:new.category, l_syspar_clambed);
	    l_chk2 := NULL;
	    IF NOT (l_trk AND l_trk2) THEN
		IF l_trk AND NOT l_trk2 THEN
		    l_chk2 := 'N';	-- Clam to NotClam
		ELSIF NOT l_trk AND l_trk2 THEN
		    l_chk2 := 'Y';	-- Not Clam to Clam
		ELSE
		    l_chk2 := NULL;	-- NotClam AND NotClam
		END IF;
		IF l_chk2 IS NOT NULL THEN
		    BEGIN
		    FOR cgp IN c_get_pos(:new.prod_id, :new.cust_pref_vendor,
			l_chk2, 8) LOOP
		    BEGIN
			UPDATE putawaylst
			SET clam_bed_trk = l_chk2
			WHERE rec_id = cgp.rec_id
			AND prod_id = cgp.prod_id
			AND cust_pref_vendor = cgp.cust_pref_vendor;
			Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'ClambedTrk PM Cat[' || :old.category ||
				'->' || :new.category || '] ' ||
				'PUTLST[' || cgp.clam_bed_trk || '->' ||
				l_chk2 || '] Syspar[' ||
				l_syspar_clambed || '] ' ||
				'Updated #rows[' || TO_CHAR(SQL%ROWCOUNT) ||
				'] This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		    EXCEPTION
			WHEN OTHERS THEN
			    Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'PO[' || cgp.rec_id || '] ' ||
				'ClambedTrk PM Cat[' || :old.category ||
				'->' || :new.category || '] ' ||
				'PUTLST[' || cgp.clam_bed_trk || '->' ||
				l_chk2 || '] Syspar' ||
				l_syspar_clambed || '] ' ||
				'Cannot update flag error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PUTAWAY', l_object_name);
		    END;
		    END LOOP;
		    EXCEPTION
			WHEN OTHERS THEN
			    Pl_Log.ins_msg('WARNING', l_object_name,
				'Item[' || :new.prod_id || '] ' ||
				'CPV[' || :new.cust_pref_vendor || '] ' ||
				'ClambedTrk PM[' || :old.category || '->' ||
				:new.category || '] ' ||
				'Table might be locked error[' ||
				TO_CHAR(SQLCODE) || '] ' ||
				'This will not stop processing.',
				NULL, NULL, 'PM', l_object_name);
		    END;
		END IF;
	    END IF;
	END IF;
    -- D#SWMS_212
-- 04/21/10  Infosys  If ware house attributes are changed write record 
-- into SAP_LM_OUT so that it is sent to SAP ECC

    IF   (:OLD.prod_id != :NEW.prod_id) OR
         (:OLD.cust_pref_vendor != :NEW.cust_pref_vendor) OR
         ( :OLD.area != :NEW.area) OR
         ( :OLD.lot_trk != :NEW.lot_trk) OR
         ( :OLD.temp_trk != :NEW.temp_trk) OR
         ( :OLD.min_temp != :NEW.min_temp) OR
         ( :OLD.max_temp != :NEW.max_temp) OR
         ( NVL(:OLD.abc, 'x')!= NVL(:NEW.abc, 'x')) THEN
         
        l_warehouse_upd := 'Y';
        
    END IF;   

    IF ( l_warehouse_upd = 'Y' ) THEN

        /* SMOD-357 */
		l_host_type_flag := pl_common.f_get_syspar('HOST_TYPE', 'x');

        l_host_type_flag := CASE l_host_type_flag
           WHEN 'AS400'   THEN 'A'
           WHEN 'SUS'     THEN 'A'
           WHEN 'IDS'     THEN 'I'
           WHEN 'SAP'     THEN 'S'
           ELSE 'A' -- ELSE assume it's 'AS400'
        END;
        
		l_host_comm_flag := pl_common.f_get_syspar('HOST_COMM', 'x');

        l_host_comm_flag := CASE l_host_comm_flag
			WHEN 'STAGING TABLES' THEN 'S'
			WHEN 'APCOM'          THEN 'A'
            ELSE 'x'
        END;

		IF ( l_host_comm_flag = 'x' ) THEN --  If l_host_comm_flag is 'x' then there is issue with syspar HOST_COMM
			IF ( l_host_type_flag = 'S' ) THEN
				l_host_comm_flag := 'S';	-- IF SAP OpCo set HOST_COMM as 'STAGING TABLES'
			ELSE
				l_host_comm_flag := 'A';	-- IF NON-SAP OpCo set HOST_COMM as 'APCOM'
			END IF;
		END IF;

        IF ( l_host_comm_flag = 'S' ) THEN

            insert into SAP_LM_OUT
            (sequence_number, interface_type, record_status, datetime,
             prod_id ,cust_pref_vendor, area,
             ti, hi, abc, mfr_shelf_life, pallet_type, lot_trk,
             sysco_shelf_life, fifo_trk, cust_shelf_life,
             exp_date_trk, mfg_date_trk, temp_trk, min_temp,
             max_temp, miniload_storage_ind, case_qty_per_carrier,
             add_date, add_user, upd_date, upd_user)
             VALUES
             (SAP_LM_SEQ.NEXTVAL, 'LM', 'N', TO_CHAR(SYSDATE, 'DD-MON-YY'),
              :new.prod_id, :new.cust_pref_vendor, :new.area, :new.ti,
              :new.hi, :new.abc, :new.mfr_shelf_life, :new.pallet_type,
              :new.lot_trk, :new.sysco_shelf_life, :new.fifo_trk,
              :new.cust_shelf_life, :new.exp_date_trk,
              :new.mfg_date_trk, :new.temp_trk,:new.min_temp,
              :new.max_temp, :new.miniload_storage_ind, :new.case_qty_per_carrier,
              SYSDATE, REPLACE(USER,'OPS$',NULL), SYSDATE,REPLACE(USER,'OPS$',NULL));
        END IF;
    END IF;
    
-- END D#SWMS_212

   END IF;  -- end IF UPDATING

   IF INSERTING THEN
      IF :NEW.mfg_date_trk IS NULL THEN
         :NEW.mfg_date_trk := 'N';
      END IF;
      IF :NEW.exp_date_trk IS NULL THEN
         :NEW.exp_date_trk := 'N';
      END IF;

      IF (:NEW.auto_ship_flag IS NULL
         OR :NEW.auto_ship_flag NOT IN ('Y', 'N')) THEN
         --
         -- Log a message if auto ship flag is non-null.  The value is
         -- something other the Y or N.
         --
         IF (:NEW.auto_ship_flag IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  auto_ship_flag[' || :NEW.auto_ship_flag || ']'
                || '  auto ship flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;

          :NEW.auto_ship_flag := 'N';
      END IF;

	 /******** BEG ADD ACPVXG 17-Jan-05 *****************/
      IF l_case_rule_id = 3 OR l_split_rule_id = 3 THEN
         :NEW.miniload_storage_ind  := 'B';
         IF l_case_rule_id != 3 THEN
            :NEW.miniload_storage_ind  := 'S';
         END IF;
      ELSE
         :NEW.miniload_storage_ind := 'N';
      END IF;
	/********** END ADD ACPVXG 17-Jan-05 *****************/

      --
      -- Set case height to 99 if it is 0 or null.
      --
      IF (NVL(:NEW.case_height, 0) = 0)  THEN
         :NEW.case_height := 99;
      END IF;
   END IF;  -- end if INSERTING

    /* Jira# 391: sban3548 - Begin of putaway exceptions handling
     If one of the below tracking flags are inserted/updated and the new value is not a valid one then default to a valid value (N).
	 Tracking flags: LOT_TRK,CATCH_WT_TRK,SPLIT_TRK,EXP_DATE_TRK, TEMP_TRK, REPACK_TRK, MFG_DATE_TRK, FIFO_TRK.
 	 The default/NVL value for all the tracking is N.
	 Valid values are:
		For all tracking flags (except FIFO_TRK)- Y or N.
		For FIFIO_TRK: N or S or A 
	 Log a message if tracking flags are non-null and not valid.
	*/
	  IF ((NVL(:OLD.LOT_TRK, 'N') != NVL(:NEW.LOT_TRK, 'N')) AND 
		 (:NEW.LOT_TRK IS NULL OR :NEW.LOT_TRK NOT IN ('Y', 'N'))) THEN
         IF (:NEW.LOT_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  LOT_TRK[' || :NEW.LOT_TRK || ']'
                || '  lot track flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.LOT_TRK := 'N';
      END IF;

	  IF ((NVL(:OLD.CATCH_WT_TRK, 'N') != NVL(:NEW.CATCH_WT_TRK, 'N')) AND 
		 (:NEW.CATCH_WT_TRK IS NULL OR :NEW.CATCH_WT_TRK NOT IN ('Y', 'N'))) THEN
         IF (:NEW.CATCH_WT_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  CATCH_WT_TRK[' || :NEW.CATCH_WT_TRK || ']'
                || '  catch weight track flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.CATCH_WT_TRK := 'N';
      END IF;
	  
	  IF ((NVL(:OLD.SPLIT_TRK, 'N') != NVL(:NEW.SPLIT_TRK, 'N')) AND 
		 (:NEW.SPLIT_TRK IS NULL OR :NEW.SPLIT_TRK NOT IN ('Y', 'N'))) THEN
         IF (:NEW.SPLIT_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  SPLIT_TRK[' || :NEW.SPLIT_TRK || ']'
                || '  Split track flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.SPLIT_TRK := 'N';
      END IF;

	  IF ((NVL(:OLD.EXP_DATE_TRK, 'N') != NVL(:NEW.EXP_DATE_TRK, 'N')) AND 
		 (:NEW.EXP_DATE_TRK IS NULL OR :NEW.EXP_DATE_TRK NOT IN ('Y', 'N'))) THEN
         IF (:NEW.EXP_DATE_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  EXP_DATE_TRK[' || :NEW.EXP_DATE_TRK || ']'
                || '  Expiry date track flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.EXP_DATE_TRK := 'N';
      END IF;
	  
	  IF ((NVL(:OLD.TEMP_TRK, 'N') != NVL(:NEW.TEMP_TRK, 'N')) AND 
		 (:NEW.TEMP_TRK IS NULL OR :NEW.TEMP_TRK NOT IN ('Y', 'N'))) THEN
         IF (:NEW.TEMP_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  TEMP_TRK[' || :NEW.TEMP_TRK || ']'
                || '  Temperature track flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.TEMP_TRK := 'N';
      END IF;
	  
	  IF ((NVL(:OLD.REPACK_TRK, 'N') != NVL(:NEW.REPACK_TRK, 'N')) AND 
		 (:NEW.REPACK_TRK IS NULL OR :NEW.REPACK_TRK NOT IN ('Y', 'N'))) THEN
         IF (:NEW.REPACK_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  REPACK_TRK[' || :NEW.REPACK_TRK || ']'
                || '  Repack track flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.REPACK_TRK := 'N';
      END IF;

	  IF ((NVL(:OLD.MFG_DATE_TRK, 'N') != NVL(:NEW.MFG_DATE_TRK, 'N')) AND 
		 (:NEW.MFG_DATE_TRK IS NULL OR :NEW.MFG_DATE_TRK NOT IN ('Y', 'N'))) THEN
         IF (:NEW.MFG_DATE_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  MFG_DATE_TRK[' || :NEW.MFG_DATE_TRK || ']'
                || '  Mfg. Date track flag populated but not Y or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.MFG_DATE_TRK := 'N';
      END IF;

	  IF ((NVL(:OLD.FIFO_TRK, 'N') != NVL(:NEW.FIFO_TRK, 'N')) AND 
		 (:NEW.FIFO_TRK IS NULL OR :NEW.FIFO_TRK NOT IN ('S', 'N', 'A'))) THEN
         IF (:NEW.FIFO_TRK IS NOT NULL) THEN
            Pl_Log.ins_msg('WARNING', l_object_name,
                'INSERTING  Item[' || :NEW.prod_id || ']'
                || '  CPV[' || :NEW.cust_pref_vendor || ']'
                || '  FIFO_TRK[' || :NEW.FIFO_TRK || ']'
                || '  FIFO track flag populated but not S or A or N.  Setting to N.',
                NULL, NULL);
         END IF;
         :NEW.FIFO_TRK := 'N';
      END IF;    
   -- Jira# 391: sban3548 - End of putaway exceptions handling

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;
   WHEN OTHERS THEN
	Pl_Log.ins_msg('WARNING', l_object_name,
		'Item[' || :new.prod_id || '] ' ||
		'CPV[' || :new.cust_pref_vendor || '] ' ||
		'Cannot update PM flag error[' ||
		TO_CHAR(SQLCODE) || '] ' ||
		'This will not stop processing.',
		NULL, NULL, 'PM', l_object_name);
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END trg_insupd_pm_brow;
/

