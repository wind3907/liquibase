CREATE OR REPLACE PACKAGE swms.pl_ml_repl_rf
AS
-- sccs_id=%Z% %W% %G% %I%
-----------------------------------------------------------------------------
-- Package Name:
--   pl_ml_repl_rf
--
-- Description:
--    Miniloader Replenishment processing.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/19/09 ctnxk000 All RF related code for ML replenishment
--    01/11/10 prbcb000 DN 12533
--                      In procedure create_txn() changed
--                         'FN' || i_rpl_task_id,
--                       to  
--                         'FN' || TO_CHAR(r_replen.task_id),
--
--    04/23/10 prbcb000 DN 12571
--                      Project: CRQ15757-Miniload In Reserve Fixes
--
--                      Getting labor mgmt error when completing miniloader
--                      demand replenishments labor batch.
--                      Modified procedure p_create_txn() to populate the
--                      transaction labor_batch_no.
--                         - Adding selecting replenlst.labor_batch_no in
--                           cursor c_replen.
--                         - Added labor_batch_no in the insert into the
--                           TRANS table.
--
--
--    03/20/11 prpbcb   DN 12603
--                      Project:
--                        CRQ20684-Split miniloader replenishments not on RF
--                      Activity: SWMS12.2_0293_CR20684
--
--                      p_ml_drop was failing when processing then 2nd
--                      replenishment when a case replenishment and a
--                      split replenishmnent to the miniloader was created
--                      after slotting an item to the miniloader and the
--                      home slot had cases and splits.  Changed p_ml_drop
--                      to substract the replenishment qty from qoh and
--                      qty_alloc instead of
--                         qoh = qoh - qty_alloc,
--                         qty_alloc = 0
--
--                      p_ml_drop was using a uom of 2 instead of 1
--                      for the expected receipt after splits dropped at 
--                      the induction location.  Changed selecting the
--                      priority unpack code in cursor c_ml_drop
--                      from
--                         p.unpack_code
--                      to
--              DECODE(r.uom, 1, 'Y',  p.unpack_code) unpack_code,
--                      so that a expected receipt for splits is
--                      created when splits are dropped to the
--                      induction location.
--
--                      Changed p_ml_drop to create an expected receipt
--                      after dropping a demand replenishment for cases
--                      to the induction location and the expected
--                      receipt does no exist.  The expected receipt
--                      should have been created when the demand
--                      replenishment was created but there have been
--                      situations when it has not.  In my testing the
--                      expected receipt was created so I was not able
--                      to duplicate the issue.
--                      But the issue is happening at the OpCo so this
--                      change will act as a failsafe measure.
--
--    06/07/11 prpbcb   DN 12603
--                      Project:
--                        CRQ20684-Split miniloader replenishments not on RF
--                      Activity: SWMS12.2_0293_CR20684
--                      Constant ct_app_func declared too small.
--                      Changed from VARHCAR2(9) to VARCHAR2(30).
--
--    08/19/11 prpbcb   PBI: 3328
--                      Project:
--                         PBI3328-Miniload_putback_pallet_has_wrong_qty
--                      Activity:
--                         PBI3328-Miniload_putback_pallet_has_wrong_qty
--
--                      The putback pallet is getting the qty dropped
--                      at the induction location subtracted twice
--                      from it.  Once when it is put back and once when
--                      the item is dropped at the induction location.
--                      Changes made under clearcase activty
--                      "SWMS12.2_0293_CR20684" may have introduced this
--                      bug.  To fix this bug procedure "p_ml_putback"
--                      was changed to only update the putback LP 
--                      location and to leave the quantities alone.
--                      The drop to the induction location will be the
--                      action updating the putback LP quantities.
--                      This makes the processing similar to how it is
--                      for a miniloader case to miniloader split
--                      replenishment.  The difference being there is no
--                      putback for the miniloader case to miniloader
--                      split replenishment.
--
--    02/16/12 prpbcb   DN
--                      Project:
--                         CR32863-Miniloader_expected_receipt_has_wrong_item_number
--                      Activity:
--                         CR32863-Miniloader_expected_receipt_has_wrong_item_number
--
--                      The change I made on 3/20/11 to procedure p_ml_drop() to
--                      send an expected receipt after a drop made
--                      would sometimes use the wrong item.  This would
--                      happen if an item had a putback and another item
--                      did not.  The item that had a putback would be
--                      used in the expected receipt for the item that
--                      did not have the putback.
--                      Added "r.exp_date" to the SELECT statement in
--                      cursor c_ml_drop.
--                      In procedure p_send_exp_results() changed the
--                      parameters in the call to p_send_exp_results()
--                      Changed to use:
--                         r_ml_drop.prod_id
--                         r_ml_drop.cust_pref_vendor
--                         r_ml_drop.exp_date
--                      instead of:
--                          r_inv.prod_id
--                          r_inv.cpv
--                          r_inv.exp_date
--
--
--    09/20/12 prpbcb   DN NA
--                      Project:
--                  CRQ39115-Miniload_replenishment_wrong_equipment
--                      Activity:
--                  CRQ39115-Miniload_replenishment_wrong_equipment
--
--                      Getting wrong equipment msg instead of no task
--                      generated on the RF when there are no miniloader
--                      replenishments for the area.
--
--                      Modified functions:
--                        - f_valid_equipment()
--                      Modified procedures:
--                        -  p_ml_area()
--
--                     11/26/12 prpbcb   Also need to fix issue
--                     where p_ml_pik is mistakenly updates two
--                     replenishments to PIK status.
--
--  28-OCT-2014 spot3255   Charm# 6000003789 - Ireland Cubic values - Metric conversion project
--                           Increased length of below variables to hold Cubic centimetre.
--                           aisle_cube,avl_cube from number(6,2) to number(12,4).
--    04/14/15 prpbcb  Project:
--  Charm6000006908_Miniloader_replenishment_bug_two_tasks_set_to_PIK_status
--                     Incident: 2249343
--
--                     Fix "p_ml_pik" updating two replenishments to PIK status.
--                     Changed cursor c_ml_pik.
--                     Added to where clause:
--                 AND (p_task_id IS NOT NULL or p_pallet_id IS NOT NULL)
--
--                     Changed how procedure "p_ml_drop" validates the
--                     drop point.
--
--
--    07/21/15 prpbcb  Dual maintain from R13.1
--                     Copied the file as is.
--  Charm6000006908_Miniloader_replenishment_bug_two_tasks_set_to_PIK_status
--
--
--    07/19/16 bben0556 Brian Bent
--                            Project:
--                R30.5--WIB#663--CRQ000000007533_Save_what_created_NDM_in_trans_RPL_record
--
--                      Modified proceedure "p_create_txn()" to populate
--                      these new columns when inserting the trans record:
--                         - TRANS.REPLEN_CREATION_TYPE  (from replenlst.replen_type)
--                         - TRANS.REPLEN_TYPE           (from replenlst.type)
--                         - TRANS.TASK_PRIORITY         (from replenlst.priority)
--                         - TRANS.SUGGESTED_TASK_PRIORITY  is not populated because we
--                                                          do not know all the different
--                                                          replenist priorities send to
--                                                          the RF.
--
--                      Changed cursor "c_replen" to select "replen_type"
--                      and "type" from the REPLENLST table.
--
--                      TRANS.REPLEN_CREATION_TYPE added to the transaction
--                      tables to store what created the non-demand
--                      replenishment.  The OpCo wants to know this.
--                      The value comes from column REPLENST.REPLEN_TYPE 
--                      which for non-demand replenishments will have one of
--                      these values:
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron job when a store-order is received that
--             requires a replenishment
--
--
--                      TRANS.REPLEN_TYPE added to the transaction tables
--                      to store the replenishment type.  It main purpose is
--                      to store the matrix replenishment type.  The value
--                      will come from REPLENLST.TYPE.
--                      Matrix replenishments have diffent types but we use
--                      RPL for the transaction.  The OpCo wants to know the
--                      matrix replenishment type.  The matrix replenishment
--                      types are in table MX_REPLEN_TYPE which are
--                      listed here.
--               TYPE DESCRIP
--               ---  ----------------------------------------
--               DSP  Demand: Matrix to Split Home
--               DXL  Demand: Reserve to Matrix
--               MRL  Manual Release: Matrix to Reserve
--               MXL  Assign Item: Home Location to Matrix
--               NSP  Non-demand: Matrix to Split Home
--               NXL  Non-demand: Reserve to Matrix
--               UNA  Unassign Item: Matrix to Main Warehouse
--
--
--                      TASK_PRIORITY stores the forklift task priority
--                      for the NDM.  I also populated it for DMD's.
--                      The value comes from USER_DOWNLOADED_TASKS.
--
--                      SUGGESTED_TASK_PRIORITY stores the hightest
--                      forklift task priority from the replenishment
--                      list sent to the RF.  The value comes from
--                      USER_DOWNLOADED_TASKS.  Distribution Services
--                      wants to know if the forklift operator is doing
--                      lower priority drops before higher ones.
--
--------------------------------------------------------------------------

	--------------------------------------------------------------------------
	-- Public Type Definitions 
	--------------------------------------------------------------------------
	TYPE	aisle_rec	IS RECORD (
		area		pm.area%TYPE,
		aisle_name	aisle_info.name%TYPE,
		ind_loc		zone.induction_loc%TYPE,
		aisle_cases	NUMBER (4),
		aisle_cube	NUMBER (12,4),
		num_tasks	NUMBER (3),
		num_piks	NUMBER (3),
		num_put_backs	NUMBER (3),
		num_unf_pbs	NUMBER (3));

	TYPE	tab_aisle_rec IS TABLE OF aisle_rec INDEX BY BINARY_INTEGER;

	TYPE	repl_rec IS RECORD (
		rpl_type	replenlst.type%TYPE,
  		src_loc		replenlst.src_loc%TYPE,
  		task_cnt	NUMBER (3),
  		priority	NUMBER (2),
  		dest_loc	replenlst.dest_loc%TYPE,
		prod_id		replenlst.prod_id%TYPE,
  		cpv		replenlst.cust_pref_vendor%TYPE,
		descrip		pm.descrip%TYPE,
		qty		replenlst.qty%TYPE,
		mfg_sku		pm.mfg_sku%TYPE,
		pack		pm.pack%TYPE,
		prod_size       v_ml_replen_info.prod_size%TYPE,
		src_uom		NUMBER (2),
		unpack_code	VARCHAR2 (1),
		task_id		NUMBER (10),
		pick_status	VARCHAR2 (1),
		mfg_date 	VARCHAR2 (6),
		exp_date	VARCHAR2 (6),
		mnl_pallet_id	VARCHAR2 (18),
		orig_pallet_id	replenlst.pallet_id%TYPE,
		putback_qty 	NUMBER (3));

	TYPE	tab_repl_rec IS TABLE OF repl_rec INDEX BY BINARY_INTEGER;

	TYPE	fail_task_rec IS RECORD (
  		status		NUMBER (6),
		task_id		NUMBER (10));

	TYPE	tab_fail_task_rec IS TABLE OF fail_task_rec INDEX BY BINARY_INTEGER;

	TYPE	sug_loc_rec IS RECORD (
		sort_field	NUMBER (2),
		sec_sort_fld	NUMBER (2),
		put_path	NUMBER (9),
		logi_loc	VARCHAR2 (7),
		avl_cube	NUMBER (12,4));

	TYPE	tab_sug_loc_rec IS TABLE OF sug_loc_rec INDEX BY BINARY_INTEGER;

	TYPE	inv_rec IS RECORD (
		prod_id		inv.prod_id%TYPE,
		rec_id		inv.rec_id%TYPE,
		mfg_date	inv.mfg_date%TYPE,
		rec_date	inv.rec_date%TYPE,
		exp_date	inv.exp_date%TYPE,
		inv_date	inv.inv_date%TYPE,
		logi_loc	inv.logi_loc%TYPE,
		plogi_loc	inv.plogi_loc%TYPE,
		qoh		inv.qoh%TYPE,
		qty_alloc	inv.qty_alloc%TYPE,
		qty_planned	inv.qty_planned%TYPE,
		lot_id		inv.lot_id%TYPE,
		cpv		inv.cust_pref_vendor%TYPE,
		parent_lp	inv.parent_pallet_id%TYPE,
		inv_uom		inv.inv_uom%TYPE);

	--------------------------------------------------------------------------
	-- Public Constants 
	--------------------------------------------------------------------------
	ct_program_code		CONSTANT VARCHAR2 (50) := 'MLRPL';
	ct_replen_picked	CONSTANT NUMBER (2) := 1;
	ct_replen_completed	CONSTANT NUMBER (2) := 2;
	ct_pallet_putback	CONSTANT NUMBER (2) := 3;
	ct_dmd_generation	CONSTANT NUMBER (2) := 4;
	wrong_equip	EXCEPTION;
	skip_rest	EXCEPTION;

	--------------------------------------------------------------------------
	-- Public Procedure Declarations
	--------------------------------------------------------------------------
	PROCEDURE p_ml_area (
		i_area		IN	VARCHAR2,
		i_ind_loc	IN	VARCHAR2 DEFAULT NULL,
		i_equip_id	IN	VARCHAR2,
		o_aisle_list	OUT	tab_aisle_rec,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2);

	PROCEDURE p_ml_aisle (
		i_area		IN	VARCHAR2,
		i_from_aisle	IN	VARCHAR2,
		i_to_aisle	IN	VARCHAR2,
		i_ind_loc	IN	VARCHAR2 DEFAULT NULL,
		o_repl_list	OUT	tab_repl_rec,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2);

	PROCEDURE p_ml_pik (
		i_task_id	IN	NUMBER,
		i_scan_data	IN	VARCHAR2,
		i_scan_method	IN	VARCHAR2,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2);

	PROCEDURE p_ml_drop (
		i_dest_loc	IN	VARCHAR2,
		i_scan_method	IN	VARCHAR2,
		o_fail_task	OUT	tab_fail_task_rec,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2);

	PROCEDURE p_ml_putback (
		i_task_id	IN	NUMBER,
		i_location	IN	VARCHAR2,
		i_scan_method	IN	VARCHAR2,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2);

	PROCEDURE p_create_txn (
		i_action	IN NUMBER,
		i_task_id	IN NUMBER DEFAULT NULL,
		i_rpl_task_id	IN NUMBER DEFAULT NULL,
		i_scan_method	IN VARCHAR2 DEFAULT 'S',
		i_inv_data	IN inv_rec,
		o_status	OUT NUMBER);

	/*
	FUNCTION f_valid_equipment (
		p_equip_id	IN	VARCHAR2,
		p_repl_type	IN	VARCHAR2)
	RETURN	BOOLEAN;

	PROCEDURE p_validate_scan (
		i_task_id	IN	NUMBER,
		i_scan_data	IN	VARCHAR2,
		o_status	OUT	NUMBER,
		o_msg		OUT	VARCHAR2);
	*/
	PROCEDURE p_ml_get_loc (
		i_pallet_id	IN	VARCHAR2,
		max_locs	IN	NUMBER,
		o_sug_loc_list	OUT	tab_sug_loc_rec,
		o_status	OUT	NUMBER);

END pl_ml_repl_rf;
/
CREATE OR REPLACE PACKAGE BODY swms.pl_ml_repl_rf
AS
-- sccs_id=%Z% %W% %G% %I%

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
	gl_pkg_name		VARCHAR2 (30) := 'pl_ml_repl_rf';		-- Package name. Used in error messages.
	g_user_id		VARCHAR2 (10) := REPLACE (USER, 'OPS$');
        -- Application function for the log messages.
        ct_app_func     CONSTANT VARCHAR2 (30)  := 'ML REPL RF';


	--
	-- The move could be for the following conditions.
	--
	-- 1. Non-splittable Item was slotted, but now is moved to mini-load
	-- 2. Non-splittable Item was floating, but now is moved to ML
	-- 3. Splittable item was slotted, but now is moved to mini-load.
	-- 4. Splittable item was slotted, but now only the splits are moved to ML
	-- 5. Splittable item was floating, but now is moved to mini-load.
	-- 6. Splittable item was floating, but now only the splits are moved to ML
	-- 
	--    When splits are moved to the mini-load, the uom is 1,
	--	the orig_pallet_id is null if the item was slotted.
	--	the orig_pallet_id is not null if the item was floating.
	--    When cases are moved to the mini-load, the uom is 2.
	--	orig_pallet_id is null if the item was slotted.
	--	orig_pallet_id is not null if the item was floating.
	--	Condition 2, 5 and 6 will have orig_pallet_id.
	--
--------------------------------------------------------------------------
-- Private Cursors
--------------------------------------------------------------------------
	CURSOR	c_ml_area_chk IS
		SELECT	area, aisle, DECODE (type, 'MNL', dest_loc, src_loc),
			SUM (num_pieces) aisle_cases,
			SUM (r_cube) aisle_cube,
			COUNT (task_id) num_tasks,
			COUNT (DECODE (pick_status, 'N', NULL, 0)) num_piks,
			COUNT (DECODE (NVL (putback_qty, 0), 0, NULL, 0)) num_put_backs,
			COUNT (DECODE (type, 'RLP', 0, NULL)) num_unf_pbs
		  FROM	v_ml_replen_info
		 WHERE	user_id = g_user_id
		   AND	status = 'PIK'
		 GROUP	BY area, aisle,
			DECODE (type, 'MNL', dest_loc, src_loc)
		 ORDER	BY 1, 2, 3;
	CURSOR	c_ml_area (
			p_area	VARCHAR2,
			p_ind_loc VARCHAR2) IS
		SELECT	area, aisle, dest_loc,
			SUM (num_pieces) aisle_cases,
			ROUND (SUM (r_cube), 0) aisle_cube,
			COUNT (task_id) num_tasks,
			0 num_piks,
			0 num_put_backs,
			0 num_unf_pbs
		  FROM	v_ml_replen_info
		 WHERE	area = p_area
		   AND	status = 'NEW'
		   AND	dest_loc = NVL (p_ind_loc, dest_loc)
		 GROUP	BY area, aisle, dest_loc
		 ORDER	BY 1, 2, 3;

	--
	-- In the cursor c_ml_aisle type is added to the order by clause for the following 
	-- reason.
	-- If the RF unit crashes/reboots after a successful drop is made at the induction location
	-- and there is a put-back quantity on the same pallet, the actual replen task would have
	-- got deleted with just the put-back task left behind. In this case, show this put-back
	-- task as the first one in the list.
	--
	CURSOR	c_ml_aisle (
			p_area		VARCHAR2,
			p_area1		VARCHAR2,
			p_from_aisle	VARCHAR2,
			p_to_aisle	VARCHAR2,
			p_ind_loc	VARCHAR2) IS
		SELECT	type,
			DECODE (type, 'MNL', src_loc, dest_loc) src_loc,
			1 task_cnt, priority,
			DECODE (type, 'MNL', dest_loc, src_loc) dest_loc,
			prod_id	, cust_pref_vendor, descrip,
			num_pieces qty, mfg_sku, pack, prod_size, uom,
			unpack_code, task_id, pick_status,
			TO_CHAR (mfg_date, 'YYMMDD') mfg_date,
			TO_CHAR (exp_date, 'YYMMDD') exp_date, pallet_id,
			orig_pallet_id, 0 putback_qty
		  FROM	v_ml_replen_info
		 WHERE	area = p_area
		   AND	((status = 'PIK') OR
			 ((p_area = p_area1) AND
			  (aisle BETWEEN
					NVL (p_from_aisle, aisle)
				    AND NVL (p_to_aisle, aisle))))
		   AND	DECODE (type, 'MNL', dest_loc, src_loc) =
				NVL (p_ind_loc, DECODE (type, 'MNL', dest_loc, src_loc))
		ORDER	BY type DESC, pick_status DESC, priority, s_pikpath;

	CURSOR	c_ml_pb_qty (
			p_pallet_id	VARCHAR2) IS
		SELECT	qty
		  FROM	replenlst
		 WHERE	pallet_id = p_pallet_id
		   AND	((status = 'NEW') OR
			 (status = 'PIK' AND user_id = g_user_id))
		   AND	type = 'RLP';

	CURSOR	c_ml_pik (
			p_task_id	NUMBER,
			p_pallet_id	VARCHAR2) IS
		SELECT	task_id, priority, pallet_id, orig_pallet_id
		  FROM	replenlst
		 WHERE	task_id = NVL (p_task_id, task_id)
		   AND	pallet_id = NVL (p_pallet_id, pallet_id)
and (p_task_id IS NOT NULL or p_pallet_id IS NOT NULL)    -- 04/15/2015 Brian Bent Added
		   FOR	UPDATE OF status NOWAIT;

        --
        -- 04/05/2011 prpbcb Bug fix.   An expected receipt for cases
        --                   instead of splits was created after dropping
        --                   splits to the induction location.  Changed 
        --                      p.unpack_code
        --                   to
        --              DECODE(r.uom, 1, 'Y',  p.unpack_code) unpack_code,
        --
        -- 02/16/2012 prpbcb Added "r.exp_date" to the SELECT statement.
        --
	CURSOR	c_ml_drop (p_dest_loc VARCHAR2) IS
		SELECT	p.update_inv,
                        DECODE(r.uom, 1, 'Y',  p.unpack_code) unpack_code,
                        r.task_id,
                        r.pallet_id,
                        r.batch_no,
                        r.qty,
			r.src_loc,
                        r.dest_loc,
                        r.prod_id,
                        r.cust_pref_vendor,
			r.op_acquire_flag,
                        r.uom,
                        r.orig_pallet_id,
                        pm.miniload_storage_ind msi,
			DECODE (r.uom, 1, r.qty, r.qty * pm.spc) qty_in_splits,
                        r.priority,
                        r.exp_date
		  FROM	pm, priority_code p, replenlst r
		 WHERE	r.user_id           = g_user_id
		   AND	r.status            = 'PIK'
		   AND	r.type              = 'MNL'
		   AND	p.priority_value    = r.priority
		   AND	r.dest_loc          = p_dest_loc
		   AND	pm.prod_id          = r.prod_id
		   AND	pm.cust_pref_vendor = r.cust_pref_vendor
		   FOR	UPDATE OF r.status NOWAIT;

	CURSOR	c_ml_putback (
			p_task_id	NUMBER) IS
		SELECT	r.putback_task_id, NVL (r.orig_pallet_id, r.pallet_id) pallet_id,
			r.putback_qty, r.area,
			DECODE (r.type, 'MNL', r.src_loc, r.dest_loc) dest_loc,
			CEIL (r.putback_qty / p.ti) * p.ti * p.case_cube + pt.skid_cube pallet_cube,
			CEIL (r.putback_qty / p.ti) * p.case_height + pt.skid_height pallet_height,
			r.prod_id, r.cust_pref_vendor cpv, r.stackable, r.task_id
		  FROM	pm p, pallet_type pt, v_ml_replen_info r
		 WHERE	user_id = g_user_id
		   AND	r.status = 'PIK'
		   AND	p.prod_id = r.prod_id
		   AND	p.cust_pref_vendor = r.cust_pref_vendor
		   AND	pt.pallet_type = p.pallet_type
		   AND	r.putback_qty > 0
		   AND	((r.type = 'MNL' AND r.task_id = p_task_id) OR
		   	 (r.type = 'RLP' AND r.putback_task_id = p_task_id) OR
			 (NOT EXISTS (SELECT 0 FROM v_ml_replen_info v1 WHERE v1.task_id = p_task_id)));

	CURSOR	c_ml_sugg_loc (
			i_pallet_id	VARCHAR2,
			i_ind_loc	VARCHAR2,
			i_put_path	NUMBER) IS
		SELECT	/*+ RULE +*/ DISTINCT nz.sort,
			DECODE (i1.prod_id, NULL, 1,
				pb.prod_id, 2, 3) sec_sort_field,
			l.put_path,
			l.logi_loc,
			l.cube - pb.pallet_cube avail_cube
		  FROM	sys_config s,
			inv i1,
			loc l,
			next_zones nz,
			lzone lz,
			zone z,
			zone z1,
			(SELECT	r.prod_id, r.cust_pref_vendor, /* r.src_loc */ i_ind_loc ind_loc,
				r.dest_loc src_loc,
				CEIL (r.qty / p.ti) * p.ti * p.case_cube + pt.skid_cube pallet_cube,
				CEIL (r.qty / p.ti) * p.case_height + pt.skid_height pallet_height
			  FROM	pm p, pallet_type pt, replenlst r
			 WHERE	r.user_id = g_user_id
			   AND	r.type = 'RLP'
			   AND	r.status = 'PIK'
			   AND	pallet_id = i_pallet_id
			   AND	p.prod_id = r.prod_id
			   AND	p.cust_pref_vendor = r.cust_pref_vendor
			   AND	pt.pallet_type = p.pallet_type) pb
		 WHERE	z.induction_loc = pb.ind_loc
		   AND	l.perm = 'N'
		   AND	nz.zone_id = z.zone_id
		   AND	lz.zone_id = nz.next_zone_id
		   AND	l.logi_loc = lz.logi_loc
		   AND	l.logi_loc = i1.plogi_loc (+)
		   AND	z1.zone_id = lz.zone_id
		   AND	z1.rule_id != 3
		   AND	s.config_flag_name = 'PUTAWAY_DIMENSION'
		   AND	l.status = 'AVL'
		   AND	((s.config_flag_val = 'C' AND
			 l.cube - pb.pallet_cube >=
				(SELECT NVL (SUM (CEIL (i.qoh / p.ti) * p.ti * p.case_cube + pt.skid_cube), 0)
				   FROM	pallet_type pt, pm p, inv i
				  WHERE	i.plogi_loc = l.logi_loc
				    AND	p.prod_id = i.prod_id
				    AND	p.cust_pref_vendor = i.cust_pref_vendor
				    AND	pt.pallet_type = p.pallet_type)) OR
			 (s.config_flag_val = 'I' AND
			 l.available_height >= pb.pallet_height))
		 ORDER	BY nz.sort,
			DECODE (i1.prod_id, NULL, 1,
				pb.prod_id, 2, 3),
			(l.cube - pb.pallet_cube) DESC,
			ABS (l.put_path - i_put_path);

	CURSOR	c_inv (i_pallet_id VARCHAR2) IS
	SELECT	prod_id, rec_id, mfg_date, rec_date, exp_date, inv_date,
		logi_loc, plogi_loc, qoh, qty_alloc, qty_planned, 
		lot_id, cust_pref_vendor, parent_pallet_id, inv_uom
	  FROM	inv
	 WHERE	logi_loc = i_pallet_id
	   FOR	UPDATE OF qoh NOWAIT;
--------------------------------------------------------------------------
-- Private Records
--------------------------------------------------------------------------
	r_inv	inv_rec;

--------------------------------------------------------------------------
-- Private SQL Statements
--------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------
	-- Application function for the log messages.

--------------------------------------------------------------------------
-- Private Procedures and Functions
--------------------------------------------------------------------------

	FUNCTION f_valid_equipment (
		p_equip_id	IN	VARCHAR2,
		p_repl_type	IN	VARCHAR2,
		i_area          IN	VARCHAR2)
	RETURN	BOOLEAN IS

		ret_value	NUMBER := 0;
	BEGIN
		-- log_message.init_proc ('f_valid_equipment');

                --
                -- The equipment is valid if it is setup in at least one
                -- of the replenishment tasks source location PIK zone
                -- for the desginated area.
                --
		SELECT	0
		  INTO	ret_value
		  FROM	zequip ze, zone z, lzone l, replenlst r,
                        swms_sub_areas ssa, aisle_info ai
		 WHERE	r.type       = p_repl_type
		   AND	l.logi_loc   = r.src_loc
		   AND	z.zone_id    = l.zone_id
		   AND	z.zone_type  = 'PIK'
		   AND	ze.zone_id   = z.zone_id
		   AND	ze.equip_id  = p_equip_id
                   AND  ai.name      = SUBSTR(r.src_loc, 1, 2)
                   AND  ssa.sub_area_code = ai.sub_area_code
                   AND  ssa.area_code = i_area
		   AND	ROWNUM = 1;

		-- log_message.init_proc (NULL);
		RETURN TRUE;
        EXCEPTION
           WHEN NO_DATA_FOUND THEN
              pl_log.ins_msg('ERROR', 'f_valid_equipment',
                  'TABLE=zequip ze, zone z, lzone l, replenlst r,swms_sub_areas ssa, aisle_info ai'
                  || '  KEY=[' || p_repl_type || ']'
                  || '[' || p_equip_id || ']'
                  || '[' || i_area || ']'
                  || '(p_repl_type,p_equip_id,i_area)'
                  || '  ACTION=SELECT  MESSAGE='
                  || '  Equipment not setup in replenlst source location PIK zone',
                  SQLCODE, SQLERRM, ct_app_func, gl_pkg_name);
              RETURN FALSE;

           WHEN OTHERS THEN
              pl_log.ins_msg('FATAL', 'f_valid_equipment',
                  'TABLE=zequip ze, zone z, lzone l, replenlst r,swms_sub_areas ssa, aisle_info ai'
                  || '  KEY=[' || p_repl_type || ']'
                  || '[' || p_equip_id || ']'
                  || '[' || i_area || ']'
                  || '(p_repl_type,p_equip_id,i_area)'
                  || '  ACTION=SELECT  MESSAGE='
                  || '  Error validating the equipment for the src loc PIK zone',
                  SQLCODE, SQLERRM, ct_app_func, gl_pkg_name);
              RAISE;  -- Propagate the exception
	END f_valid_equipment;


	FUNCTION f_validate_loc (
			i_location	IN	VARCHAR2,
			i_area		IN	VARCHAR2,
			i_stackable	IN	VARCHAR2,
			l_pallet_cube	IN	NUMBER,
			l_pallet_height	IN	NUMBER)
	RETURN NUMBER
	IS
		CURSOR	l_val_loc IS
		SELECT	l.status,
			l.cube,
			l.perm,
			available_height,
			ssa.area_code
		  FROM	swms_sub_areas ssa, aisle_info ai, loc l
		 WHERE	l.logi_loc = i_location
		   AND	ai.pick_aisle = l.put_aisle
		   AND	ssa.sub_area_code = ai.sub_area_code
		   AND	i_location NOT IN (
				SELECT	induction_loc
				  FROM	zone
				 WHERE	induction_loc IS NOT NULL);

		CURSOR	l_loc_inv (p_location VARCHAR2) IS
		SELECT	NVL (SUM (CEIL ((i.qoh + NVL (i.qty_planned, 0)) / p.spc / p.ti) *
				p.ti * p.case_cube + pt.skid_cube), 0) alloc_cube,
			NVL (SUM (CEIL (i.qoh / p.ti) * p.case_height +
				pt.skid_height), 0) pallet_height,
			NVL (SUM (MOD (i.qoh/p.spc, p.ti)), 0) extra_cases,
			MAX (DECODE (p.stackable, 0, NULL, p.stackable)) stackable
		  FROM	pm p, pallet_type pt, inv i
		 WHERE	i.plogi_loc = p_location
		   AND	p.prod_id = i.prod_id
		   AND	p.cust_pref_vendor = i.cust_pref_vendor
		   AND	pt.pallet_type = p.pallet_type;
		
		l_putaway_dim	VARCHAR2 (2);
		r_val_loc	l_val_loc%ROWTYPE;
		r_loc_inv	l_loc_inv%ROWTYPE;
	BEGIN

		OPEN	l_val_loc;
		FETCH	l_val_loc INTO r_val_loc;
		IF (l_val_loc%NOTFOUND) THEN
			RETURN	pl_swms_error_codes.INV_LOCATION;
		ELSIF (r_val_loc.status = 'DMG') THEN
			RETURN pl_swms_error_codes.LOC_DAMAGED;
		ELSIF (r_val_loc.area_code != i_area)
		THEN
			RETURN pl_swms_error_codes.INV_AREA;
		ELSIF (r_val_loc.perm = 'Y')
		THEN
			RETURN pl_swms_error_codes.HOME_SLOT_UNAVL;
		ELSE
			l_putaway_dim := pl_common.f_get_syspar('PUTAWAY_DIMENSION', 'C');
			OPEN l_loc_inv (i_location);
			FETCH l_loc_inv INTO r_loc_inv;
			IF (l_loc_inv%FOUND) THEN
				IF (l_putaway_dim = 'C') THEN
					r_val_loc.cube := r_val_loc.cube - r_loc_inv.alloc_cube;
				END IF;
			END IF;
			CLOSE l_loc_inv;
			IF ((l_putaway_dim = 'C' AND r_val_loc.cube < l_pallet_cube) OR
			    (l_putaway_dim = 'I' AND r_val_loc.available_height < l_pallet_height))
			THEN
				RETURN pl_swms_error_codes.QTY_TOO_LARGE;
			ELSIF ((r_loc_inv.extra_cases > 0) OR
				(r_loc_inv.stackable > i_stackable))
			THEN
				RETURN pl_swms_error_codes.INV_LOCATION;
			END IF;
		END IF;
		CLOSE l_val_loc;
		RETURN pl_swms_error_codes.NORMAL;

	END f_validate_loc;

	PROCEDURE p_send_exp_results (
		i_prod_id	IN	VARCHAR2,
		i_cpv		IN	VARCHAR2,
		i_unpack_cd	IN	VARCHAR2,
		i_pallet_id	IN	VARCHAR2,
		i_qty		IN	NUMBER,
		i_exp_date	IN	DATE,
		o_message	OUT	VARCHAR2,
		o_status	OUT	NUMBER) IS

		l_exp_rcpt	pl_miniload_processing.t_exp_receipt_info;
		l_uom		NUMBER (2);
		l_status	NUMBER (1);
	BEGIN
		IF (i_unpack_cd = 'Y') THEN
			l_uom := 1;
		ELSE
			l_uom := 2;
		END IF;
		l_exp_rcpt.v_expected_receipt_id := i_pallet_id;
		l_exp_rcpt.v_prod_id := i_prod_id;
		l_exp_rcpt.v_cust_pref_vendor := i_cpv;
		l_exp_rcpt.n_qty_expected := i_qty;
		l_exp_rcpt.n_uom := l_uom;
		l_exp_rcpt.v_inv_date := i_exp_date;
		o_message := 'Posting Expected Receipt to Staging Director, Pallet = [' ||
				i_pallet_id || '], prod_id = [' || i_prod_id || '], CPV = [' || i_cpv ||
				' Qty = [' || i_qty || '], UOM = [' || l_uom || '], Exp date = [' ||
				i_exp_date || ']';

		pl_miniload_processing.p_send_exp_receipt(l_exp_rcpt, l_status);

		IF  ((l_status != pl_miniload_processing.ct_success)
		AND  (l_status != pl_miniload_processing.ct_er_duplicate))
		THEN
			o_message := 'Failed ' || o_message;
		END IF;
		o_status := pl_swms_error_codes.NORMAL;
	END p_send_exp_results;

	PROCEDURE p_validate_scan (
		i_task_id	IN	NUMBER,
		i_scan_data	IN	VARCHAR2,
		o_status	OUT	NUMBER,
		o_msg		OUT	VARCHAR2)
	IS
		l_prod_id	VARCHAR2 (10);
		temp		NUMBER;
		scan_code	VARCHAR2 (7);
		l_uom		NUMBER (02);
		l_count		NUMBER (02);
		l_lpc		NUMBER (02);
	BEGIN
		o_status := pl_swms_error_codes.NORMAL;
		SELECT	r.prod_id,
			DECODE (i_scan_data,
				NVL (r.orig_pallet_id, pallet_id), 'OK',
				DECODE (DECODE (l.slot_type, 'MLS', NULL, r.orig_pallet_id), NULL,
					DECODE (i_scan_data,
						src_loc, 'LOC',
						p.external_upc, 'UPC', 
						DECODE (LENGTH (i_scan_data),
							LENGTH (src_loc), 'BADLOC', 'BADUPC')), 'BADLP')),
			COUNT (DISTINCT i.prod_id),
			COUNT (DISTINCT i.logi_loc)
		  INTO	l_prod_id, scan_code, l_count, l_lpc
		  FROM	loc l, inv i, replenlst r,
			(SELECT	*
			   FROM	pm_upc
			  WHERE	external_upc = i_scan_data) p
		 WHERE	r.task_id = i_task_id
		   AND	r.prod_id = p.prod_id (+)
		   AND	r.cust_pref_vendor = p.cust_pref_vendor (+)
		   AND	l.logi_loc = r.src_loc
		   AND	((i.logi_loc = NVL (r.orig_pallet_id, r.pallet_id)) OR
			 (r.priority IN (12, 15) AND i.logi_loc = r.pallet_id))
		 GROUP BY r.prod_id,
			DECODE (i_scan_data,
				NVL (orig_pallet_id, pallet_id), 'OK',
				DECODE (DECODE (l.slot_type, 'MLS', NULL, r.orig_pallet_id), NULL,
					DECODE (i_scan_data,
						src_loc, 'LOC',
						p.external_upc, 'UPC', 
						DECODE (LENGTH (i_scan_data),
							LENGTH (src_loc), 'BADLOC', 'BADUPC')), 'BADLP'));
		IF (scan_code = 'BADUPC')
		THEN
			o_msg := 'Invalid UPC code ' || i_scan_data || ' for item ' || l_prod_id;
			o_status := pl_swms_error_codes.INV_EXT_UPC;
		ELSIF (scan_code = 'BADLOC') THEN
			o_msg := 'Invalid Location ' || i_scan_data || ' for item ' || l_prod_id;
			o_status := pl_swms_error_codes.INV_LOCATION;
		ELSIF (scan_code = 'BADLP') THEN
			o_msg := 'Invalid License Plate ' || i_scan_data || ' for item ' || l_prod_id;
			o_status := pl_swms_error_codes.INV_LABEL;
		END IF;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
                   pl_log.ins_msg('WARN', 'p_validate_scan',
                       'TABLE=loc,inv,replenlst'
                       || 'KEY=i_task_id[' || TO_CHAR(i_task_id) || ']'
                       || ',i_scan_data[' || i_scan_data || ']'
                       || '  ACTION=SELECT  MESSAGE='
                       || '  Found no replenishment record.'
                       || '  Possibly because wrong value scanned',
                       NULL, NULL, ct_app_func, gl_pkg_name);

				o_msg := 'Invalid Scan Data. Must scan Location, UPC or LP';
				o_status := pl_swms_error_codes.INV_LABEL;
	END p_validate_scan;

	PROCEDURE p_create_txn (
		i_action	IN NUMBER,
		i_task_id	IN NUMBER DEFAULT NULL,
		i_rpl_task_id	IN NUMBER DEFAULT NULL,
		i_scan_method	IN VARCHAR2 DEFAULT 'S',
		i_inv_data	IN inv_rec,
		o_status	OUT NUMBER)
	IS
           CURSOR c_replen(i_task_id NUMBER,
                           i_action  NUMBER)
           IS
              SELECT p.update_inv,
                     r.task_id,
                     r.pallet_id,
                     r.batch_no,
                     r.qty,
                     r.src_loc,
                     r.dest_loc,
                     r.prod_id,
                     r.cust_pref_vendor,
                     r.orig_pallet_id,
                     r.uom,
                     pm.spc,
                     r.labor_batch_no,
                     r.replen_type,
                     r.type,
                     r.priority
                FROM pm,
                     priority_code p,
                     replenlst r
               WHERE r.user_id           = g_user_id
                 AND r.task_id           = NVL(i_task_id, task_id)
                 AND r.type              = DECODE(i_action, ct_pallet_putback, 'RLP', 'MNL')
                 AND p.priority_value    = r.priority
                 AND pm.prod_id          = r.prod_id
                 AND pm.cust_pref_vendor = r.cust_pref_vendor
                 AND r.status            = DECODE(i_action, ct_replen_completed, 'DEL',
                                                            ct_pallet_putback, 'DEL',
                                                            'PIK')
                 FOR UPDATE OF r.task_id NOWAIT;
	BEGIN
		FOR r_replen IN c_replen (i_task_id, i_action)
		LOOP
			BEGIN
				INSERT INTO trans
                                             (trans_id,
                                              trans_type,
                                              trans_date, 
                                              prod_id,
                                              cust_pref_vendor,
                                              qty,
                                              uom,
                                              src_loc, 
                                              dest_loc,
                                              pallet_id,
                                              user_id,
                                              batch_no,
                                              scan_method1,
                                              cmt,
                                              labor_batch_no,
                                              ref_pallet_id,
                                              rec_id,
                                              lot_id,
                                              exp_date,
                                              mfg_date,
                                              replen_creation_type,
                                              replen_type,
                                              task_priority)
                                       VALUES
                                             (trans_id_seq.NEXTVAL,
                                              --
                 DECODE(i_action, ct_pallet_putback, 'PPB',
                                  ct_replen_picked, DECODE(r_replen.update_inv, 'N', DECODE(r_replen.pallet_id, r_replen.src_loc, 'PHM', 'PFK'),
                                                                                'IND'),
                                  ct_dmd_generation, 'RPL',
                                  DECODE(r_replen.update_inv, 'N', 'DFK', 'RPL')),
                                              --
                                              SYSDATE,
                                              r_replen.prod_id, 
                                              r_replen.cust_pref_vendor,
                                              DECODE(r_replen.uom, 1, 1, r_replen.spc) * r_replen.qty,
                                              r_replen.uom,
                                              DECODE(i_action, ct_pallet_putback, r_replen.dest_loc, r_replen.src_loc),
                                              DECODE(i_action, ct_pallet_putback, r_replen.src_loc, r_replen.dest_loc),
                                              r_replen.pallet_id,
                                              USER, r_replen.batch_no,
                                              i_scan_method,
                                              'Task Id = ' || TRIM(TO_CHAR(r_replen.task_id)),
                                              r_replen.labor_batch_no,
                                              NVL(r_replen.orig_pallet_id, r_replen.pallet_id),
                                              i_inv_data.rec_id,
                                              i_inv_data.lot_id,
                                              i_inv_data.exp_date,
                                              i_inv_data.mfg_date,
                                              r_replen.replen_type,
                                              r_replen.type,
                                              r_replen.priority);
			EXCEPTION
				WHEN OTHERS THEN
					o_status := pl_swms_error_codes.TRANS_INSERT_FAILED;
			END;

			IF ((i_action = ct_replen_completed) AND (r_replen.update_inv = 'Y'))
			THEN
			BEGIN
				DELETE	trans
				 WHERE	pallet_id = r_replen.pallet_id
				   AND	cmt = 'Task Id = ' || r_replen.task_id
				   AND	trans_type = 'IND'
				   AND	user_id = USER;
			EXCEPTION
				WHEN OTHERS THEN
					o_status := pl_swms_error_codes.DEL_TRANS_FAIL;
			END;
			END IF;
			IF (i_action IN (ct_pallet_putback, ct_replen_completed))
			THEN
			BEGIN
				DELETE	replenlst
				 WHERE	CURRENT OF c_replen;
			EXCEPTION
				WHEN OTHERS THEN
					o_status := pl_swms_error_codes.DEL_RPL_FAIL;
			END;
			END IF;
		END LOOP;
	END p_create_txn;

	PROCEDURE p_ml_area (
		i_area		IN	VARCHAR2,
		i_ind_loc	IN	VARCHAR2 DEFAULT NULL,
		i_equip_id	IN	VARCHAR2,
		o_aisle_list	OUT	tab_aisle_rec,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2)
	IS
		rec_aisle	aisle_rec;
		l_counter	NUMBER := 0;
		l_ind_loc	zone.induction_loc%TYPE := i_ind_loc;
		i		NUMBER := 0;
		recFound	BOOLEAN := FALSE;
	BEGIN
		o_msg := NULL;
		-- log_message.init_proc ('p_ml_area');
		-- log_message.u_write ('I', 'Area = ' || i_area ||
		--		', Induction Loc = [' || NVL (i_ind_loc, 'NULL') || ']');

                pl_log.ins_msg('INFO', 'p_ml_area',
                           'Starting procedure'
                           || '  i_area['     || i_area     || ']'
                           || '  i_ind_loc['  || i_ind_loc  || ']'
                           || '  i_equip_id[' || i_equip_id || ']',
                           NULL, NULL, ct_app_func, gl_pkg_name);

		FOR rec_aisle IN c_ml_area_chk
		LOOP
			l_counter := l_counter + 1;
			o_aisle_list (l_counter) := rec_aisle;
		END LOOP;
		IF (l_counter != 0)
		THEN
		BEGIN
			IF (o_aisle_list (1).area != i_area)
			THEN
				o_status := pl_swms_error_codes.NORMAL;
				RAISE skip_rest;
			ELSE
				l_ind_loc := o_aisle_list (1).ind_loc;
			END IF;
		END;
		END IF;

		OPEN c_ml_area (i_area, l_ind_loc);
		LOOP
			FETCH c_ml_area INTO rec_aisle;
			IF (c_ml_area%NOTFOUND) THEN
				EXIT;
			END IF;

                        --
                        -- If this point is reached then there is at least
                        -- one miniloader replenishment in the area.
                        -- Check the equipment zone.
                        --
                        pl_log.ins_msg('INFO', 'p_ml_area',
                           'There is a least 1 replenishment for the area.'
                           || '  Call f_valid_equipment to check the equipment zone',
                           NULL, NULL, ct_app_func, gl_pkg_name);

                        IF (f_valid_equipment (i_equip_id, 'MNL', i_area) = FALSE)
                        THEN
                           RAISE   WRONG_EQUIP;
                        END IF;


			recFound := FALSE;

			FOR i IN 1..l_counter
			LOOP
				IF ((o_aisle_list (i).aisle_name = rec_aisle.aisle_name)
				AND (o_aisle_list (i).ind_loc = rec_aisle.ind_loc))
				THEN
					o_aisle_list (i).aisle_cases := o_aisle_list (i).aisle_cases +
									rec_aisle.aisle_cases;
					o_aisle_list (i).aisle_cube := o_aisle_list (i).aisle_cube +
									rec_aisle.aisle_cube;
					o_aisle_list (i).num_tasks := o_aisle_list (i).num_tasks +
									rec_aisle.num_tasks;
					recFound := TRUE;
					EXIT;
				END IF;
			END LOOP;
			IF (NOT (recFound))
			THEN
				l_counter := l_counter + 1;
				o_aisle_list (l_counter) := rec_aisle;
			END IF;
		END LOOP;
		CLOSE c_ml_area;
		IF (l_counter = 0) THEN
			o_status := pl_swms_error_codes.NO_TASK;
		ELSE
			o_status := pl_swms_error_codes.NORMAL;
		END IF;
		-- log_message.init_proc (NULL);
		EXCEPTION
			WHEN skip_rest THEN
				NULL;
			WHEN WRONG_EQUIP THEN
				o_msg := 'Wrong Equipment ' || i_equip_id ||
					 ' For User ' || g_user_id;
				/*
				log_message.u_write ('F', 'Wrong Equipment ' || i_equip_id ||
					' For User ' || g_user_id);
				log_message.init_proc (NULL);
				*/
				o_status := pl_swms_error_codes.WRONG_EQUIP;
			WHEN OTHERS THEN
				o_msg := SQLERRM;
				/*
				log_message.u_write ('F', g_user_id || SQLERRM);
				log_message.init_proc (NULL);
				*/
				o_status := pl_swms_error_codes.DATA_ERROR;

	END p_ml_area;

	PROCEDURE p_ml_aisle (
		i_area		IN	VARCHAR2,
		i_from_aisle	IN	VARCHAR2,
		i_to_aisle	IN	VARCHAR2,
		i_ind_loc	IN	VARCHAR2 DEFAULT NULL,
		o_repl_list	OUT	tab_repl_rec,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2)
	IS
		rec_repl	repl_rec;
		temp_repl	c_ml_aisle%ROWTYPE;
		l_counter	NUMBER := 0;
		l_area		pm.area%TYPE;
	BEGIN
		o_msg := NULL;
		-- log_message.init_proc ('p_ml_aisle');
		o_status := pl_swms_error_codes.NO_TASK;
		SELECT	DISTINCT s.area_code
		  INTO	l_area
		  FROM	swms_sub_areas s, aisle_info a
		 WHERE	a.name = i_from_aisle
		   AND	s.sub_area_code = a.sub_area_code
		   AND	rownum = 1;
		OPEN c_ml_aisle (l_area, i_area, i_from_aisle, i_to_aisle, i_ind_loc);
		LOOP
			FETCH c_ml_aisle INTO rec_repl;
			IF (c_ml_aisle%NOTFOUND) THEN
				EXIT;
			END IF;
			OPEN c_ml_pb_qty (rec_repl.orig_pallet_id);
			FETCH c_ml_pb_qty INTO rec_repl.putback_qty;
			IF (c_ml_pb_qty%NOTFOUND) THEN
				rec_repl.putback_qty := 0;
			END IF;
			CLOSE	c_ml_pb_qty;
			l_counter := l_counter + 1;
			o_repl_list (l_counter) := rec_repl;
		END LOOP;
		CLOSE c_ml_aisle;
		IF (l_counter = 0) THEN
			o_status := pl_swms_error_codes.NO_TASK;
		ELSE
			o_status := pl_swms_error_codes.NORMAL;
		END IF;
		-- log_message.init_proc (NULL);
		EXCEPTION
			WHEN OTHERS THEN
				o_msg := SQLERRM;
				o_status := SQLCODE;
				-- log_message.init_proc (NULL);

	END p_ml_aisle;

	PROCEDURE p_ml_pik (
		i_task_id	IN	NUMBER,
		i_scan_data	IN	VARCHAR2,
		i_scan_method	IN	VARCHAR2,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2)
	IS
		r_ml_pik	c_ml_pik%ROWTYPE;
		validation_err	EXCEPTION;
		l_status	NUMBER (6);
	BEGIN
		o_msg := NULL;
		-- log_message.init_proc ('p_ml_pik');
		p_validate_scan (
			i_task_id, i_scan_data,
			o_status, o_msg);
		IF (o_status != pl_swms_error_codes.NORMAL)
		THEN
			RAISE validation_err;
		END IF;
		OPEN c_ml_pik (i_task_id, NULL);
		FETCH c_ml_pik INTO r_ml_pik;
		IF (c_ml_pik%FOUND) THEN
		BEGIN
			DBMS_OUTPUT.PUT_LINE ('After First Fetch of c_ml_pik. Pallet Id = ' || r_ml_pik.pallet_id);

			UPDATE	replenlst
			   SET	status = 'PIK',
				user_id = g_user_id
			 WHERE	CURRENT OF c_ml_pik;
			CLOSE c_ml_pik;

			IF (r_ml_pik.priority > 15) /* Donot update INV for demand replenishments */
			THEN
				IF (r_ml_pik.pallet_id IS NOT NULL)
				THEN
					OPEN c_inv (r_ml_pik.pallet_id);
					FETCH c_inv INTO r_inv;
					IF (c_inv%FOUND) THEN
						DBMS_OUTPUT.PUT_LINE ('After First Fetch of c_ml_inv. Pallet Id = ' || r_ml_pik.pallet_id);
						UPDATE	inv
						   SET	plogi_loc = g_user_id
						 WHERE	CURRENT OF c_inv;
					END IF;
					CLOSE c_inv;
				END IF;

				IF (r_ml_pik.orig_pallet_id IS NOT NULL)
				THEN
					OPEN c_inv (r_ml_pik.orig_pallet_id);
					FETCH c_inv INTO r_inv;
					IF (c_inv%FOUND) THEN
						DBMS_OUTPUT.PUT_LINE ('After First Fetch of c_ml_inv. Pallet Id = ' || r_ml_pik.orig_pallet_id);
						UPDATE	inv
						   SET	plogi_loc = g_user_id
						 WHERE	CURRENT OF c_inv;
					END IF;
					CLOSE c_inv;
				END IF;
			END IF;

			OPEN c_ml_pik (NULL, r_ml_pik.orig_pallet_id);
			FETCH c_ml_pik INTO r_ml_pik;

			IF (c_ml_pik%FOUND) THEN
			BEGIN
				UPDATE	replenlst
				   SET	status = 'PIK',
					user_id = g_user_id
				 WHERE	CURRENT OF c_ml_pik;
			END;
			END IF;
		END;
		ELSE
		BEGIN
			o_msg := 'Task ' || i_task_id || ' does not exist anymore. ' ||
				' It may have got deleted by Order Processing.';
			o_status := pl_swms_error_codes.NO_MORE_TASK;
		END;
		END IF;
		CLOSE	c_ml_pik;
		o_status := pl_swms_error_codes.NORMAL;
		p_create_txn (
			i_action=>ct_replen_picked,
			i_task_id=>i_task_id,
			i_rpl_task_id=>i_task_id,
			i_scan_method=>i_scan_method,
			i_inv_data=>r_inv,
			o_status=>l_status);
		IF (l_status != 0)
		THEN
			o_status := l_status;
		END IF;
		-- log_message.init_proc (NULL);
		EXCEPTION
			WHEN validation_err THEN
				NULL;
			WHEN OTHERS THEN
				o_msg := SQLERRM;
				o_status := SQLCODE;
	END p_ml_pik;

---------------------------------------------------------------------------
-- Procedure:
--    p_ml_drop
--
-- Description:
--
-- Parameters:
--
-- Exceptions raised:
--
-- Called by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/20/11 prpbcb   Changed to create an expected receipt after
--                      dropping a demand replenishment for cases
--                      to the induction location and the expected receipt
--                      does no exist.  The expected receipt should have been
--                      created when the demand replenishment was
--                      created but there have been situations when it has
--                      not.  In my testing the expected receipt was
--                      created so I was not able to duplicate the issue.
--                      But the issue is happening at the OpCo so this
--                      change will act as a failsafe measure.
--
--    04/15/15 prpbcb   Changed how the drop point is validated.
--                      Just see if the user has tasks for the induction
--                      loc dropped at.  Don't care if the user has a PIK
--                      for another induction location.
--
--                      If the user has no tasks going to the drop point
--                      then raise exception "inv_ind_loc".
---------------------------------------------------------------------------
	PROCEDURE p_ml_drop (
		i_dest_loc	IN	VARCHAR2,
		i_scan_method	IN	VARCHAR2,
		o_fail_task	OUT	tab_fail_task_rec,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2)
	IS
		is_ind_loc	VARCHAR2 (1) := NULL;
		inv_ind_loc	EXCEPTION;
		l_ind_loc	VARCHAR2 (10);
		l_tasks		NUMBER (2) := 0;
		lCntFail	NUMBER (2) := 0;
		blnInvFail	BOOLEAN := FALSE;
		blnRplFail	BOOLEAN := FALSE;
		l_errcd		NUMBER (6);
	BEGIN
		BEGIN
			SELECT	'Y'
			  INTO	is_ind_loc
			  FROM	zone
			 WHERE	induction_loc = i_dest_loc
			   AND	rule_id = 3
			   AND	zone_type = 'PUT'
			   AND	ROWNUM = 1;
			EXCEPTION
			WHEN NO_DATA_FOUND THEN
				RAISE inv_ind_loc;
		END;

		BEGIN
			SELECT	dest_loc
			  INTO	l_ind_loc
			  FROM	replenlst
			 WHERE	user_id = g_user_id
			   AND	status = 'PIK'
			   AND	type = 'MNL'
and replenlst.dest_loc = i_dest_loc                    -- 04/15/2015  Brian Bent Added Just see if the user has tasks for the induction loc droped at.  Don't care if the user has a PIK for another induction location.
			   AND	ROWNUM = 1;

			l_tasks := 1;

			IF (l_ind_loc != i_dest_loc) THEN
				RAISE inv_ind_loc;
			END IF;

			EXCEPTION
			WHEN NO_DATA_FOUND THEN
				-- l_tasks := 0;  -- 04/15/2015  Brian Bent  Comment out
				RAISE inv_ind_loc;  -- 04/15/2015  Brian Bent Added 
		END;

		IF (l_tasks = 0)
		THEN
			o_status := pl_swms_error_codes.NO_TASK;
			o_msg := 'No incomplete tasks for the user ' || g_user_id;
			RAISE skip_rest;
		END IF;

		-- log_message.init_proc ('p_ml_drop');
		o_msg := NULL;
		lCntFail := 0;

		FOR r_ml_drop IN c_ml_drop (i_dest_loc)
		LOOP
		BEGIN
			DBMS_OUTPUT.PUT_LINE ('Inside c_ml_drop loop. Task id = ' || r_ml_drop.task_id);
			SAVEPOINT lCntFail;
			BEGIN
				IF (NVL (r_ml_drop.op_acquire_flag, 'N') = 'Y')
				THEN
					NULL;
				ELSE
				BEGIN
					IF (r_ml_drop.update_inv = 'Y')
					THEN
					BEGIN
						BEGIN
							blnInvFail := FALSE;
							DBMS_OUTPUT.PUT_LINE ('Before Update INV Task id = ' ||
								r_ml_drop.task_id || ', Pallet Id = ' || r_ml_drop.pallet_id);
							o_msg := 'Before Update INV';

                                                        --
                                                        -- Update the destination inventory.
                                                        --
							UPDATE	inv
							   SET	qoh = qty_planned,
								qty_planned = 0,
								plogi_loc = i_dest_loc
							 WHERE	logi_loc = r_ml_drop.pallet_id;

							IF (SQL%ROWCOUNT = 0)
							THEN
								DBMS_OUTPUT.PUT_LINE ('Update INV Failed for pallet=[' ||
									r_ml_drop.pallet_id || ']');
								l_errcd := pl_swms_error_codes.INV_UPDATE_FAIL;
								blnInvFail := TRUE;
							ELSE
								DBMS_OUTPUT.PUT_LINE ('Updated INV for Pallet=[' ||
									r_ml_drop.pallet_id || '], Row Count = ' || sql%ROWCOUNT);
							END IF;
							EXCEPTION
							WHEN OTHERS THEN
								l_errcd := pl_swms_error_codes.INV_UPDATE_FAIL;
								blnInvFail := TRUE;
						END;

						IF (NOT (blnInvFail))
						THEN
						BEGIN
							BEGIN
								blnInvFail := FALSE;
								o_msg := 'Before OPEN c_inv';
								OPEN c_inv (NVL (r_ml_drop.orig_pallet_id, r_ml_drop.src_loc));
								FETCH c_inv INTO r_inv;
								IF (c_inv%FOUND)
								THEN
									o_msg := 'Before UPATE inv 1';

                                                                        --
                                                                        -- Update the inventory at the source location.
                                                                        --
                                                                        -- 3/30/2011 Brian Bent Changed update stmt
                                                                        -- to use r_ml_drop.qty_in_splits
                                                                        --
									UPDATE	inv
									   SET	qoh = qoh - r_ml_drop.qty_in_splits,
										qty_alloc = qty_alloc - r_ml_drop.qty_in_splits,
										plogi_loc =
											DECODE (plogi_loc,
												g_user_id,
												r_ml_drop.src_loc,
												plogi_loc)
									 WHERE	CURRENT OF c_inv;

                                                                        /******  3/30/2011  Brian Bent Was this
									UPDATE	inv
									   SET	qoh = qoh - qty_alloc,
										qty_alloc = 0,
										plogi_loc =
											DECODE (plogi_loc,
												g_user_id,
												r_ml_drop.src_loc,
												plogi_loc)
									 WHERE	CURRENT OF c_inv;
									o_msg := 'Before DELETE inv';
                                                                        ********/

									DELETE	inv
									 WHERE	logi_loc = NVL (r_ml_drop.orig_pallet_id, r_ml_drop.src_loc)
									   AND	qoh = 0
									   AND	qty_alloc = 0
									   AND	qty_planned = 0
									   AND	((logi_loc != plogi_loc)
										OR (logi_loc = plogi_loc AND (
											(r_ml_drop.msi = 'B') OR
											(r_ml_drop.msi = 'S' AND inv_uom = 1))));
								ELSE
									l_errcd := pl_swms_error_codes.INV_UPDATE_FAIL;
									blnInvFail := TRUE;
								END IF;
								CLOSE c_inv;
								EXCEPTION
								WHEN OTHERS THEN
									blnInvFail := TRUE;
							END;

						END;
						END IF;

						BEGIN
							o_msg := '[Before UPDATE replenlst RLP ' ||
								i_dest_loc || ', ' || r_ml_drop.orig_pallet_id ||
								', ' || g_user_id || '] ';
							blnRplFail := FALSE;

							IF (r_ml_drop.orig_pallet_id IS NOT NULL) THEN
							BEGIN
								o_msg := '[orig_pallet_id IS NOT NULL. Length is ' ||
									LENGTH (r_ml_drop.orig_pallet_id) || '] ';
								UPDATE	replenlst
								   SET	src_loc = i_dest_loc
								 WHERE	pallet_id = r_ml_drop.orig_pallet_id
								   AND	user_id = g_user_id
								   AND	type = 'RLP';
								EXCEPTION
								WHEN NO_DATA_FOUND THEN
									NULL;
								WHEN OTHERS THEN
									l_errcd := pl_swms_error_codes.RPL_UPDATE_FAIL;
									blnRplFail := TRUE;
							END;
							END IF;
						END;
					END;
					END IF;  -- end IF (r_ml_drop.update_inv = 'Y')

                                        --
                                        -- 4/10/2011  Brian Bent  
                                        -- Always send expected receipt to the miniloader based on the replenishment qty.
                                        -- This was inside of IF (r_ml_drop.update_inv = 'Y')
                                        -- which would send the expected receipt only when qty
                                        -- remained in inventory after the drop.  For demand
                                        -- replenishments it is possible that order generation
                                        -- brought the inventory qty to 0 thus the inventory was deleted.
                                        -- OpCo 024 is reporting that sometimes the expected 
                                        -- receipt after the drop of a demand replenishment is not created
                                        -- so we will create it regardless if the inventory was deleted.
                                        -- This means two expected receipts will be created for demand
                                        -- replenishments for different quantities.  We will see if this
                                        -- causes any confusion.
                                        --    - One by order generation which will be for the qty dropped to
                                        --      the induction location minus the order qty.  If order
                                        --      generation deleted the inventory then no expected receipt
                                        --      will be created.
                                        --      
                                        --    - One after the drop to the induction location which will be
                                        --      for the replenishment qty.  So this expected receipt
                                        --      will be for more qty than the one created by order
                                        --      generation.  
                                        --
                                        BEGIN
                                           o_msg := 'Before p_send_results ';

                                           --
                                           -- 2/16/2012  Brian Bent Fix bug.
                                           -- Expected receipt created with the wrong item.
                                           -- Changed to use:
                                           --    r_ml_drop.prod_id
                                           --    r_ml_drop.cust_pref_vendor
                                           --    r_ml_drop.exp_date
                                           -- instead of:
                                           --     r_inv.prod_id
                                           --     r_inv.cpv
                                           --     r_inv.exp_date
                                           --
                                           p_send_exp_results
                                                           (i_prod_id=>r_ml_drop.prod_id,
                                                            i_cpv=>r_ml_drop.cust_pref_vendor,
                                                            i_unpack_cd=>r_ml_drop.unpack_code,
                                                            i_pallet_id=>r_ml_drop.pallet_id,
                                                            i_qty=>r_ml_drop.qty_in_splits,
                                                            i_exp_date=>r_ml_drop.exp_date,
                                                            o_message=>o_msg,
                                                            o_status=>o_status);
                                        END;
                                END;
				END IF;  -- end IF (NVL (r_ml_drop.op_acquire_flag, 'N') = 'Y')

				--
				-- This replenishment has to be deleted. But, we will just
				-- change the status to 'DEL' here so that the transaction
				-- creation routine can pick up this record to create the
				-- transactions properly. Once it is done with it, it would
				-- delete the replenishment record.
				--
				-- DELETE replenlst
				IF (NOT (blnInvFail OR blnRplFail))
				THEN
				BEGIN
					o_msg := '[Before UPDATE Replenlst to DEL] ';
					UPDATE	replenlst
					   SET	status = 'DEL'
					 WHERE	task_id = r_ml_drop.task_id;

					EXCEPTION
					WHEN OTHERS THEN
						l_errcd := pl_swms_error_codes.RPL_UPDATE_FAIL;
						blnRplFail := TRUE;
				END;
				END IF;

			END;

			IF (blnInvFail OR blnRplFail)
			THEN
				DBMS_OUTPUT.PUT_LINE ('Task ' || lCntFail || ' Failed. Reason = ' || l_errcd);
				ROLLBACK TO lCntFail;
				lCntFail := lCntFail + 1;
				o_fail_task (lCntFail).status := l_errcd;
				o_fail_task (lCntFail).task_id := r_ml_drop.task_id;
			ELSE
				DBMS_OUTPUT.PUT_LINE ('Task ' || lCntFail || ' Successful. Trying trans insert');
				l_errcd := 0;
				o_msg := '[Before p_create_txn] ';
				p_create_txn (
					i_action=>ct_replen_completed,
					i_task_id=>r_ml_drop.task_id,
					i_rpl_task_id=>r_ml_drop.task_id,
					i_scan_method=>i_scan_method,
					i_inv_data=>r_inv,
					o_status=>l_errcd);
				DBMS_OUTPUT.PUT_LINE ('After trans insert, Error code = ' || l_errcd);
				IF (l_errcd != 0) THEN
					o_fail_task (lCntFail).status := l_errcd;
					o_fail_task (lCntFail).task_id := r_ml_drop.task_id;
				END IF;
			END IF;
			DBMS_OUTPUT.PUT_LINE ('Task ' || lCntFail || ' Successful');
		END;
		END LOOP;

		IF (lCntFail > 0)
		THEN
			o_status := pl_swms_error_codes.MNL_DROP_FAIL;
		ELSE
			o_status := pl_swms_error_codes.NORMAL;
		END IF;


		-- log_message.init_proc (NULL);
		EXCEPTION
			WHEN skip_rest THEN
				NULL;
			WHEN inv_ind_loc THEN
				o_msg := 'Invalid Induction Location';
				o_status := pl_swms_error_codes.INVALID_IND_LOC;
			WHEN OTHERS THEN
				IF (lCntFail != 0) THEN
					ROLLBACK TO lCntFail;
				ELSE
					ROLLBACK ;
				END IF;
				o_msg := o_msg || SQLERRM;
				o_status := pl_swms_error_codes.DATA_ERROR;
	END p_ml_drop;


        ---------------------------------------------------------------------------
        -- Procedure:
        --    p_ml_putback
        --
        -- Modification History:
        --    Date     Designer Comments
        --    -------- -------- ---------------------------------------------------
        --    08/19/11 prpbcb   Activity:
        --                         PBI3328-Miniload_putback_pallet_has_wrong_qty
        --
        --                      The putback pallet is getting the qty dropped
        --                      at the induction location subtracted twice
        --                      from it.  Once when it is put back and once when
        --                      the item is dropped at the induction location.
        --                      Changes made under clearcase activty
        --                      "SWMS12.2_0293_CR20684" may have introduced this
        --                      bug.  To fix this bug changed the update stmt
        --                      to only update the putback LP 
        --                      location and to leave the quantities alone.
        --                      The drop to the induction location will be the
        --                      action updating the putback LP quantities.
        --                      This makes the processing similar to how it is
        --                      for a miniloader case to miniloader split
        --                      replenishment.  The difference being there is no
        --                      putback for the miniloader case to miniloader
        --                      split replenishment.
        --                      Change update stmt:
        --                         UPDATE inv
        --                            SET qoh = qoh - qty_alloc,
        --                                qty_alloc = 0,
        --                                plogi_loc = i_location
        --                         WHERE CURRENT OF c_inv;
        --                      to
        --                         UPDATE inv
        --                            SET plogi_loc = i_location
        --                         WHERE CURRENT OF c_inv;
        --
        ---------------------------------------------------------------------------
	PROCEDURE p_ml_putback (
		i_task_id	IN	NUMBER,
		i_location	IN	VARCHAR2,
		i_scan_method	IN	VARCHAR2,
		o_status	OUT     NUMBER,
		o_msg		OUT	VARCHAR2)
	IS
                lv_fname        VARCHAR2(30) := 'p_ml_putback';
		l_status	NUMBER (6);
		i		NUMBER (2) := 0;
	BEGIN
		-- log_message.init_proc ('p_ml_putback');
		o_status := pl_swms_error_codes.NORMAL;
		o_msg := NULL;

		FOR r_ml_putback IN c_ml_putback (i_task_id)
		LOOP
			i := 1;
			IF (r_ml_putback.dest_loc != i_location)
			THEN
				DBMS_OUTPUT.PUT_LINE ('Before validate Loc. Orig Loc = ' ||
					r_ml_putback.dest_loc || ', Put Back Loc = ' || i_location);

				l_status := f_validate_loc (i_location,
						r_ml_putback.area,
						r_ml_putback.stackable,
						r_ml_putback.pallet_cube,
						r_ml_putback.pallet_height);

				IF (l_status != pl_swms_error_codes.NORMAL)
				THEN
					RAISE skip_rest;
				END IF;
			END IF;

			DBMS_OUTPUT.PUT_LINE ('Before Update INV. Pallet Id = ' ||
				r_ml_putback.pallet_id || ', Put Back Loc = ' || i_location);

                        pl_log.ins_msg('INFO', lv_fname,
                           'Before update of INV to the location the LP was putback to.'
                           || '  i_task_id['     || TO_CHAR(i_task_id) || ']'
                           || '  i_location['    || i_location         || ']'
                           || '  i_scan_method[' || i_scan_method      || ']'
                           || '  r_ml_putback.pallet_id[' || r_ml_putback.pallet_id || ']',
                           NULL, NULL, ct_app_func, gl_pkg_name);

			BEGIN
				OPEN c_inv (r_ml_putback.pallet_id);
				FETCH c_inv INTO r_inv;

				IF (c_inv%FOUND) THEN
					UPDATE	inv
					   SET	plogi_loc = i_location
					 WHERE	CURRENT OF c_inv;
				END IF;

				CLOSE c_inv;
			EXCEPTION
				WHEN OTHERS THEN
					l_status := pl_swms_error_codes.INV_UPDATE_FAIL;

                                        pl_log.ins_msg('FATAL', lv_fname,
                                           'Update of INV to the location the LP was putback to failed.'
                                           || '  i_task_id['     || TO_CHAR(i_task_id) || ']'
                                           || '  i_location['    || i_location         || ']'
                                           || '  i_scan_method[' || i_scan_method      || ']'
                                           || '  r_ml_putback.pallet_id[' || r_ml_putback.pallet_id || ']',
                                           SQLCODE, SQLERRM, ct_app_func, gl_pkg_name);
			END;

			DBMS_OUTPUT.PUT_LINE ('Before Update Replen status to DEL. Task Id = ' ||
				r_ml_putback.putback_task_id );

			UPDATE	replenlst
			   SET	status = 'DEL'
			 WHERE	task_id = r_ml_putback.putback_task_id;

			SELECT	DECODE (r_ml_putback.task_id,
					r_ml_putback.putback_task_id, NULL, r_ml_putback.task_id)
			  INTO	r_ml_putback.task_id
			  FROM	DUAL;

			DBMS_OUTPUT.PUT_LINE ('Before Create Txn. Task Id = ' ||
				r_ml_putback.putback_task_id );

			p_create_txn (
				i_action=>ct_pallet_putback,
				i_task_id=>r_ml_putback.putback_task_id,
				i_rpl_task_id=>r_ml_putback.task_id,
				i_scan_method=>i_scan_method,
				i_inv_data=>r_inv,
				o_status=>l_status);
		END LOOP;

		IF (l_status != 0)
		THEN
			o_status := l_status;
		ELSIF (i = 0)
		THEN
			o_status := pl_swms_error_codes.NO_TASK;
		END IF;

		-- log_message.init_proc (NULL);
		EXCEPTION
		WHEN skip_rest THEN
			o_status := l_status;
			IF (o_status = pl_swms_error_codes.INV_LOCATION)
			THEN
				o_msg := 'Invalid Put Back Location ' || i_location;
			ELSIF (o_status = pl_swms_error_codes.LOC_DAMAGED)
			THEN
				o_msg := 'Put Back Location ' || i_location || ' is damaged ';
			ELSIF (o_status = pl_swms_error_codes.INV_AREA)
			THEN
				o_msg := 'Put Back Location ' || i_location || ' is in the wrong area ';
			ELSIF (o_status = pl_swms_error_codes.QTY_TOO_LARGE)
			THEN
				o_msg := 'Put Back Quantity too large for Location ' || i_location;
			END IF;
		WHEN OTHERS THEN
			o_msg := SQLERRM;
			o_status := pl_swms_error_codes.DATA_ERROR;
	END p_ml_putback;


	PROCEDURE p_ml_get_loc (
		i_pallet_id	IN	VARCHAR2,
		max_locs	IN	NUMBER,
		o_sug_loc_list	OUT	tab_sug_loc_rec,
		o_status	OUT	NUMBER)
	IS
		i		NUMBER (2) := 0;
		l_rec		sug_loc_rec;
		l_ind_loc	VARCHAR2 (10);
		l_put_path	NUMBER   (10);
	BEGIN
		o_status := pl_swms_error_codes.NORMAL;
		BEGIN
			SELECT	put_path, r.dest_loc
			  INTO	l_put_path, l_ind_loc
			  FROM	loc l, replenlst r
			 WHERE	r.orig_pallet_id = i_pallet_id
			   AND	r.type = 'MNL'
			   AND	r.status = 'PIK'
			   AND	l.logi_loc = r.dest_loc;
			EXCEPTION
			WHEN NO_DATA_FOUND THEN
			BEGIN
				SELECT	l.put_path, r.src_loc
				  INTO	l_put_path, l_ind_loc
				  FROM	loc l, replenlst r
				 WHERE	r.pallet_id = i_pallet_id
				   AND	type = 'RLP'
				   AND	r.status = 'PIK'
				   AND	l.logi_loc = r.src_loc;
			END;
		END;
		/*
		**
		** The following code would work only with Oracle version 9.0 and up
		** So, for now, have to use the ugly oracle 8 version
		**
		OPEN c_ml_sugg_loc (i_pallet_id);
		FETCH c_ml_sugg_loc
		 BULK COLLECT
		 INTO o_sug_loc_list LIMIT max_locs;
		CLOSE c_ml_sugg_loc;
		*/
		OPEN c_ml_sugg_loc (i_pallet_id, l_ind_loc, l_put_path);
		FOR i IN 1..max_locs
		LOOP
			FETCH c_ml_sugg_loc INTO l_rec;
			IF (c_ml_sugg_loc%NOTFOUND)
			THEN
				EXIT;
			END IF;
			o_sug_loc_list (i) := l_rec;
		END LOOP;
		CLOSE c_ml_sugg_loc;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				o_status := pl_swms_error_codes.INV_LABEL;
			WHEN OTHERS THEN
				o_status := pl_swms_error_codes.DATA_ERROR;
	END p_ml_get_loc;

BEGIN
	NULL;
	-- log_message.init_pkg ('pl_ml_repl_rf');
END pl_ml_repl_rf;
/
-- CREATE OR REPLACE PUBLIC SYNONYM pl_ml_repl_rf FOR swms.pl_ml_repl_rf
-- /
-- GRANT EXECUTE ON swms.pl_ml_repl_rf TO swms_user
-- /
