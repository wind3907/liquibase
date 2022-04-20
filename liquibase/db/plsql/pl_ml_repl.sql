CREATE OR REPLACE PACKAGE swms.pl_ml_repl
AS
	-- sccs_id=%Z% %W% %G% %I%
	--------------------------------------------------------------------------
	-- Package Name:
	--   pl_ml_repl
	--
	-- Description:
	--    Miniloader Replenishment processing.
	--
	-- Modification History:
	--    Date     Designer Comments
	--    -------- -------- --------------------------------------------------
	--    06/05/09 prppxx   Created.
	--    05/13/11 prpbcb   Activity:
        --                 SWMS12.2_0293_CR20684 Miniload Replenishment Bug Fixes
        --                      Not creating case replenishment from the main
        --                      warehouse to the miniloader when the miniloader
        --                      replies back that it does not have enough qty
        --                      for a case order.  Modified procedure
        --                      p_create_ml_case_rpl changing
        --                      the where clause for ML_SUB_SHP	to not divide by
        --                      v.spc because i_qty_reqd is in
        --                      cases.  This was preventing case replenishments
        --                      from the main warehouse to the miniloader from getting
        --                      created.
        --                      Changed;
        --                         AND v.curr_ml_cases < ' || i_qty_reqd || ' / v.spc
        --                      to
        --                         AND v.curr_ml_cases < ' || i_qty_reqd || '
        --
	--------------------------------------------------------------------------
	
	
	--------------------------------------------------------------------------
	-- Public Constants 
	--------------------------------------------------------------------------
	ct_program_code   CONSTANT VARCHAR2 (50) := 'MLRPL';
	
	--------------------------------------------------------------------------
	-- Public Procedure Declarations
	--------------------------------------------------------------------------
	PROCEDURE p_create_ml_case_rpl (
		i_call_type		IN	VARCHAR2	DEFAULT NULL,
		i_area               	IN      VARCHAR2	DEFAULT NULL,
		i_putzone		IN	VARCHAR2	DEFAULT NULL,
		i_prod_id   		IN      VARCHAR2	DEFAULT NULL,
		i_cust_pref_vendor	IN 	VARCHAR2	DEFAULT NULL,
		i_route_batch_no	IN	NUMBER		DEFAULT NULL,
		i_route_no		IN	VARCHAR2	DEFAULT NULL,
		i_qty_reqd		IN	NUMBER		DEFAULT	NULL,
		i_uom			IN	NUMBER		DEFAULT	2,
		o_status             	OUT     NUMBER);
	
END pl_ml_repl;
/
CREATE OR REPLACE PACKAGE BODY swms.pl_ml_repl
AS
-- sccs_id=%Z% %W% %G% %I%

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
   gl_pkg_name           VARCHAR2 (30) := 'pl_ml_repl';
                                                -- Package name.
                                                --  Used in error messages.
--------------------------------------------------------------------------
-- Private Cursors
--------------------------------------------------------------------------

	CURSOR	c_inv (p_prod_id VARCHAR2,
			p_CPV	 VARCHAR2) IS
	SELECT	l.pik_path, i.logi_loc, plogi_loc, qoh, qty_alloc, exp_date,
		i.parent_pallet_id, i.rec_id, i.lot_id, i.mfg_date, i.rec_date,
		i.qty_planned, i.inv_date, i.min_qty, i.abc, p.spc, i.inv_uom,
		l.slot_type
	  FROM	pm p, zone z, lzone lz, loc l, inv i
	 WHERE	i.prod_id = p_prod_id
	   AND	i.cust_pref_vendor = p_CPV
	   AND	p.prod_id = i.prod_id
	   AND	p.cust_pref_vendor = i.cust_pref_vendor
	   AND	i.status = 'AVL'
	   AND	i.inv_uom IN (0, 2)
	   AND	qoh > 0
	   AND	NVL (qty_alloc, 0) = 0
	   AND	l.logi_loc = i.plogi_loc
	   AND	lz.logi_loc = l.logi_loc
	   AND	z.zone_id = lz.zone_id
	   AND	z.zone_type = 'PUT'
	   AND	z.induction_loc IS NULL
	 ORDER	BY exp_date, qoh, i.logi_loc
	   FOR	UPDATE OF i.qty_alloc NOWAIT;
--------------------------------------------------------------------------
-- Private Records
--------------------------------------------------------------------------
	TYPE	t_ml_record IS RECORD(
		prod_id		pm.prod_id%TYPE,
		cpv		pm.cust_pref_vendor%TYPE,
		spc		pm.spc%TYPE,
		split_trk	pm.split_trk%TYPE,
		ship_split_only	pm.auto_ship_flag%TYPE,
		cs_per_carr	NUMBER,
		max_tr_per_itm  NUMBER,
		zone_id		pm.zone_id%TYPE,
		ind_loc		zone.induction_loc%TYPE,
		max_ml_cases	NUMBER,
		curr_ml_cases	NUMBER,
		curr_ml_trays	NUMBER,
		curr_resv_cases NUMBER,
		curr_repl_cases NUMBER,
		curr_qty_reqd	NUMBER);

	r_ml_rpl		t_ml_record;

--------------------------------------------------------------------------
-- Private SQL Statements
--------------------------------------------------------------------------
	ML_MAIN_SQL	VARCHAR2 (512) := 
			'SELECT	v.prod_id, v.cust_pref_vendor, v.spc, v.split_trk,
				v.ship_split_only, v.case_per_carrier,
				v.max_tray_per_item, v.zone_id, v.induction_loc,
				v.max_ml_cases, v.curr_ml_cases, v.curr_ml_trays,
				v.curr_resv_cases, v.curr_repl_cases ';
	ML_MAIN_SQL2	VARCHAR2 (24) := ', 0 qty_reqd';
	ML_MAIN_SQL3	VARCHAR2 (26) := ', fd. qty_order qty_reqd';

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------
	-- Application function for the log messages.
   	ct_app_func	CONSTANT VARCHAR2 (9)  := 'ML REPL';

	SHP_PRI_CD	CONSTANT VARCHAR2 (3) := 'HGH';
	DMD_PRI_CD	CONSTANT VARCHAR2 (3) := 'URG';
	NDM_PRI_CD	CONSTANT VARCHAR2 (3) := 'LOW';
--------------------------------------------------------------------------
-- Private Procedures and Functions
--------------------------------------------------------------------------

	PROCEDURE AcquireNDMReplen (
			i_prod_id  IN	VARCHAR2,
			i_cpv	   IN	VARCHAR2,
			o_qty	   OUT	NUMBER)
	IS
		CURSOR c_ndm_rpl IS
			SELECT	r.type, r.pallet_id, r.src_loc, r.dest_loc,
				(p.spc * r.qty) rpl_qty, r.user_id,
				r.orig_pallet_id
			  FROM	pm p, priority_code pc, replenlst r
			 WHERE	r.prod_id = i_prod_id
			   AND	r.cust_pref_vendor = i_cpv
			   AND	p.prod_id = r.prod_id
			   AND	p.cust_pref_vendor = r.cust_pref_vendor
			   AND	r.type in ('MNL', 'RLP')
			   AND	r.priority IN (18, 48)
			   AND	r.status = 'PIK'
			   AND	pc.priority_value = r.priority
			   AND	pc.priority_code != 'URG'
			   AND	pc.unpack_code = 'N'
			   FOR	UPDATE OF r.op_acquire_flag NOWAIT;
	BEGIN
		pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'Enter AcquireNDMReplen', NULL, NULL);
		o_qty := 0;
		FOR r_ndm_rpl IN c_ndm_rpl
		LOOP
			pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'AcquireNDMReplen: Update Replenlst', NULL, NULL);
			UPDATE	replenlst
			   SET	op_acquire_flag = 'Y',
					priority = DECODE (uom, 2, 12, 15)
			 WHERE	CURRENT OF c_ndm_rpl;
			IF (r_ndm_rpl.type = 'MNL')
			THEN
				o_qty := o_qty + r_ndm_rpl.rpl_qty;
			END IF;
			pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'AcquireNDMReplen: Update Inv 1', NULL, NULL);
			UPDATE	inv
			   SET	qoh = qty_planned,
				qty_planned = 0,
				plogi_loc = r_ndm_rpl.src_loc
			 WHERE	logi_loc = r_ndm_rpl.pallet_id
			   AND	plogi_loc = r_ndm_rpl.user_id
			   AND	r_ndm_rpl.type = 'MNL';
			pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'AcquireNDMReplen: Update Inv 2', NULL, NULL);
			UPDATE	inv
			   SET	qoh = qoh - qty_alloc,
				qty_alloc = 0,
				plogi_loc = r_ndm_rpl.dest_loc
			 WHERE	logi_loc = r_ndm_rpl.pallet_id
			   AND	plogi_loc = r_ndm_rpl.user_id
			   AND	r_ndm_rpl.type = 'RLP';
		END LOOP;
		pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'Exit AcquireNDMReplen', NULL, NULL);
	END AcquireNDMReplen;

	PROCEDURE DeleteNDMRepl (
			i_prod_id  IN	VARCHAR2,
			i_cpv	   IN	VARCHAR2,
			o_qty	   OUT	NUMBER)
	IS
		CURSOR c_ndm_rpl IS
			SELECT	r.type, r.pallet_id, r.src_loc, r.dest_loc,
				(p.spc * r.qty) rpl_qty, r.user_id,
				r.orig_pallet_id
			  FROM	pm p, replenlst r
			 WHERE	r.prod_id = i_prod_id
			   AND	r.cust_pref_vendor = i_cpv
			   AND	p.prod_id = r.prod_id
			   AND	p.cust_pref_vendor = r.cust_pref_vendor
			   AND	r.type in ('MNL', 'RLP')
			   AND	r.status = 'NEW'
			   AND	r.priority IN (18, 48)
			   FOR	UPDATE OF r.op_acquire_flag NOWAIT;
	BEGIN
		pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'Enter DeleteNDMReplen', NULL, NULL);
		o_qty := 0;
		FOR r_ndm_rpl IN c_ndm_rpl
		LOOP
			pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'DeleteNDMReplen: Delete Replenlst', NULL, NULL);
			DELETE	replenlst
			 WHERE	CURRENT OF c_ndm_rpl;
			IF (r_ndm_rpl.type = 'MNL')
			THEN
				o_qty := o_qty + r_ndm_rpl.rpl_qty;
				pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'DeleteNDMReplen: Update Inv', NULL, NULL);
				UPDATE	inv
				   SET	qty_alloc = 0,
					plogi_loc = r_ndm_rpl.src_loc
				 WHERE	logi_loc = r_ndm_rpl.orig_pallet_id;
				pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'DeleteNDMReplen: Delete Inv', NULL, NULL);
				DELETE	inv
				 WHERE	logi_loc = r_ndm_rpl.pallet_id;
			END IF;
		END LOOP;
		pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'Exit DeleteNDMReplen', NULL, NULL);
	END DeleteNDMRepl;

	PROCEDURE GenMLCaseReplen (
			i_rb_no		NUMBER,
			i_route_no	VARCHAR2,
			i_prod_id	VARCHAR2,
			i_cpv		VARCHAR2,
			i_rpl_qty	NUMBER,
			i_priority	NUMBER,
			i_ind_loc	VARCHAR2,
			i_call_type	VARCHAR2,
			i_cs_per_carr	NUMBER,
			i_spc		NUMBER)
	IS
		l_rpl_qty	NUMBER;
		l_remaining	NUMBER;
		l_pallet_seq	NUMBER;
		l_task_id	NUMBER;
		l_status	NUMBER;
		l_inv_rec	pl_ml_repl_rf.inv_rec;
	BEGIN
		l_remaining := i_rpl_qty;

		FOR r_inv IN c_inv (i_prod_id, i_cpv)
		LOOP
			l_rpl_qty := LEAST (l_remaining, r_inv.qoh);
			IF (((r_inv.qoh - l_rpl_qty) / NVL (i_spc, 1)) BETWEEN 1 AND i_cs_per_carr)
			THEN
				l_rpl_qty := r_inv.qoh;
			END IF;

			SELECT	ml_pallet_id_seq.NEXTVAL
			  INTO	l_pallet_seq
			  FROM	DUAL;

			INSERT	INTO replenlst (
				task_id, prod_id, cust_pref_vendor, uom, qty, type, status,
				src_loc, pallet_id, dest_loc, gen_uid, gen_date, exp_date,
				route_no, route_batch_no, priority, parent_pallet_id, add_date,
				rec_id, lot_id, mfg_date, s_pikpath, orig_pallet_id)
			VALUES (repl_id_seq.NEXTVAL, i_prod_id, i_cpv, 2,
				l_rpl_qty / NVL (r_inv.spc, 1), 'MNL',
				DECODE (i_call_type, 'NDS', 'PRE', 'NEW'), r_inv.plogi_loc,
				r_inv.plogi_loc || l_pallet_seq, i_ind_loc, REPLACE (USER, 'OPS$'),
				SYSDATE, r_inv.exp_date, i_route_no, i_rb_no, i_priority,
				r_inv.parent_pallet_id, SYSDATE, r_inv.rec_id, r_inv.lot_id,
				r_inv.mfg_date, r_inv.pik_path,
				DECODE (r_inv.plogi_loc, r_inv.logi_loc, NULL,
					DECODE (r_inv.slot_type, 'MLS', NULL, r_inv.logi_loc)));
			IF (r_inv.qoh - l_rpl_qty > 0)
			THEN
				INSERT	INTO replenlst (
					task_id, prod_id, cust_pref_vendor, uom, qty, type, status,
					src_loc, pallet_id, dest_loc, gen_uid, gen_date, exp_date,
					route_no, route_batch_no, priority, parent_pallet_id, add_date,
					rec_id, lot_id, mfg_date, orig_pallet_id, s_pikpath)
				VALUES (repl_id_seq.NEXTVAL, i_prod_id, i_cpv, 2,
					(r_inv.qoh - l_rpl_qty) / NVL (r_inv.spc, 1), 'RLP',
					DECODE (i_call_type, 'NDS', 'PRE', 'NEW'), r_inv.plogi_loc,
					r_inv.logi_loc, r_inv.plogi_loc, REPLACE (USER, 'OPS$'),
					SYSDATE, r_inv.exp_date, i_route_no, i_rb_no, i_priority,
					r_inv.parent_pallet_id, SYSDATE, r_inv.rec_id, r_inv.lot_id,
					r_inv.mfg_date, r_inv.logi_loc, r_inv.pik_path)
				RETURNING task_id INTO l_task_id;

			END IF;
			IF (i_call_type = 'DMD')
			THEN
				l_inv_rec.prod_id	:= i_prod_id;
				l_inv_rec.rec_id	:= r_inv.rec_id;
				l_inv_rec.mfg_date	:= r_inv.mfg_date;
				l_inv_rec.rec_date	:= r_inv.rec_date;
				l_inv_rec.exp_date	:= r_inv.exp_date;
				l_inv_rec.inv_date	:= r_inv.inv_date;
				l_inv_rec.logi_loc	:= r_inv.logi_loc;
				l_inv_rec.plogi_loc	:= r_inv.plogi_loc;
				l_inv_rec.qoh		:= r_inv.qoh;
				l_inv_rec.qty_alloc	:= r_inv.qty_alloc;
				l_inv_rec.qty_planned	:= r_inv.qty_planned;
				l_inv_rec.lot_id	:= r_inv.lot_id;
				l_inv_rec.cpv		:= i_cpv;
				l_inv_rec.parent_lp	:= r_inv.parent_pallet_id;
				l_inv_rec.inv_uom	:= r_inv.inv_uom;
				pl_ml_repl_rf.p_create_txn (
					i_action=>pl_ml_repl_rf.ct_dmd_generation,
                			i_task_id=>l_task_id,
					i_inv_data=>l_inv_rec,
                			o_status=>l_status);
				IF (r_inv.qoh = l_rpl_qty)
				THEN
					DELETE	inv
					 WHERE	CURRENT OF c_inv;
				ELSE
					UPDATE	inv
					   SET	qoh = qoh - l_rpl_qty
					 WHERE	CURRENT OF c_inv;
				END IF;
			ELSE
				UPDATE	inv
				   SET	qty_alloc = l_rpl_qty
				 WHERE	CURRENT OF c_inv;
			END IF;
			INSERT	INTO inv (logi_loc, plogi_loc, prod_id, cust_pref_vendor,
				status, qoh, qty_alloc, qty_planned, min_qty, abc, inv_date,
				exp_date, inv_uom, add_date, add_user)
			VALUES	(r_inv.plogi_loc || l_pallet_seq, i_ind_loc, i_prod_id, i_cpv,
				'AVL', DECODE (i_call_type, 'DMD', l_rpl_qty, 0), 0,
				DECODE (i_call_type, 'DMD', 0, l_rpl_qty), r_inv.min_qty,
				r_inv.abc, r_inv.inv_date,
				r_inv.exp_date, 2, SYSDATE, REPLACE (USER, 'OPS$'));
			l_remaining := l_remaining - l_rpl_qty;
			IF (l_remaining <= 0) THEN
				EXIT;
			END IF;
		END LOOP;

	END GenMLCaseReplen;
-------------------------------------------------------------------------
-- Procedure:
--    p_create_ml_case_rpl
--
-- Description:
--     The procedure to create replenishment tasks for miniload cases. Called
--     when user generates rpl task from PN1SB for MiniLoad items. It can also 
--     be called when the cron job runs to create repl for ML items.
--
-- Parameters:
--    i_prod_id  
--    i_cust_pref_vendor 
--    i_area
--    o_status - return value
--          0  - No errors.
--          1  - Error occured.
--
-- Exceptions Raised:
--    e_fail - If an error occurs then 1 will be returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    05/12/11 prpbcb   Changed the where clause for ML_SUB_SHP	
--                      to not divide by v.spc because i_qty_reqd is in
--                      cases.  This was preventing case replenishments
--                      from the main warehouse to the miniloader from getting
--                      created.
--                      Changed:
--                         AND v.curr_ml_cases < ' || i_qty_reqd || ' / v.spc
--                      to
--                         AND v.curr_ml_cases < ' || i_qty_reqd || '
-------------------------------------------------------------------------

	PROCEDURE p_create_ml_case_rpl (
		i_call_type		IN	VARCHAR2	DEFAULT NULL,
		i_area               	IN      VARCHAR2	DEFAULT NULL,
		i_putzone		IN	VARCHAR2	DEFAULT NULL,
		i_prod_id   		IN      VARCHAR2	DEFAULT NULL,
		i_cust_pref_vendor	IN 	VARCHAR2	DEFAULT NULL,
		i_route_batch_no	IN	NUMBER		DEFAULT NULL,
		i_route_no		IN	VARCHAR2	DEFAULT NULL,
		i_qty_reqd		IN	NUMBER		DEFAULT	NULL,
		i_uom			IN	NUMBER		DEFAULT	2,
		o_status             	OUT     NUMBER)
	IS
	lv_miniload_storage_ind   VARCHAR2 (1);
	lv_fname                  VARCHAR2 (50)       := 'p_create_ml_case_rpl';
	lv_msg_text               VARCHAR2 (512);
	sql_stmt		  VARCHAR2 (2048);
	i			  NUMBER (6);
	e_fail                    EXCEPTION;
		TYPE refRPL IS		REF CURSOR;
		curRPL			refRPL;
		id_curRPL		NUMBER;
		l_result		NUMBER;
	
	-- This cursor is for creation of non-demand repl from MiniLoad reserve location.
	-- There is no split items in such locations.
	
		ML_SUB_DMD	VARCHAR2 (512) :=
				' FROM float_detail fd, v_ml_reserve_info v ' ||
				' WHERE	fd.route_no = ''' || i_route_no || '''' ||
				'   AND	fd.prod_id = v.prod_id ' ||
				'   AND	fd.cust_pref_vendor = v.cust_pref_vendor ' ||
				'   AND	v.curr_ml_cases < fd.qty_order / v.spc' ||
				'   AND v.curr_resv_cases > 0';

		ML_SUB_NDM	VARCHAR2 (512) :=
				' FROM v_ml_reserve_info v ' ||
				' WHERE	v.curr_ml_cases < v.case_per_carrier
				    AND	NVL (v.curr_ml_trays, 0) <= 1
				    AND NVL (v.curr_resv_cases, 0) > 0
				    AND v.area = NVL (''' || i_area || ''', v.area)
				    AND v.zone_id = NVL (''' || i_putzone || ''', v.zone_id)
				    AND v.prod_id = NVL (''' || i_prod_id || ''', v.prod_id)
				    AND v.cust_pref_vendor = NVL (''' || i_cust_pref_vendor ||
					''', v.cust_pref_vendor)';
		ML_SUB_SHP	VARCHAR2 (512) :=
				' FROM v_ml_reserve_info v 
				  WHERE	v.prod_id = ''' || i_prod_id || '''
				    AND	v.cust_pref_vendor = ''' || i_cust_pref_vendor || '''
				    AND	v.curr_ml_cases < ' || i_qty_reqd || '
				    AND v.curr_resv_cases > 0';

		CURSOR	cFD (pRouteNo VARCHAR2) IS
		SELECT	fd.prod_id, fd.cust_pref_vendor
		  FROM	pm p, float_detail fd
		 WHERE	fd.route_no = pRouteNo
		   AND	p.prod_id = fd.prod_id
		   AND	p.cust_pref_vendor = fd.cust_pref_vendor
		   AND	p.miniload_storage_ind = 'B';

		l_pri_cd	VARCHAR2 (3);
		l_priority	INTEGER;
		rpl_qty		NUMBER;
		l_num_trays	NUMBER;
		l_qty		NUMBER := 0;
		acquired_qty	NUMBER := 0;
		deleted_qty 	NUMBER := 0;
	BEGIN

	o_status := pl_miniload_processing.ct_success;


         --
         -- Log a message if the replenishment is for the 
         -- miniloader not having enough qty for an order.
         --
         IF (i_call_type = 'SHP') THEN
            pl_log.ins_msg('INFO', lv_fname,
                'i_call_type[' || i_call_type || ']'
                || '  Create case replenishment from main'
                || ' warehouse to the miniloader for item ['
                || i_prod_id || ']'
                || ' CPV[' || i_cust_pref_vendor || ']'
                || ' for ' ||  TO_CHAR(i_qty_reqd)
                || ' cases.',
                NULL, NULL, ct_app_func, gl_pkg_name);
         END IF;
	
		-- Generate NDM repl from ML reserve locations to MiniLoad.
		DBMS_OUTPUT.PUT_LINE ('Starting');
		IF (i_call_type NOT IN ('NDS', 'NDC', 'DMD', 'SHP')) THEN
			lv_msg_text := 'Invalid Call Type. ' || i_call_type;
			RAISE e_fail;
		END IF;	
		DBMS_OUTPUT.PUT_LINE ('good call type ' || i_call_type);
	
		pl_text_Log.ins_msg('I', ct_PROGRAM_CODE,
			'Generate ML Repl for call type = ' || i_call_type, NULL, NULL);
	
		SELECT	ML_MAIN_SQL ||
			DECODE (i_call_type,
				'DMD', ML_MAIN_SQL3,
				 ML_MAIN_SQL2) ||
			DECODE (i_call_type,
				'NDS', ML_SUB_NDM,
				'NDC', ML_SUB_NDM,
				'DMD', ML_SUB_DMD,
				'SHP', ML_SUB_SHP),
			DECODE (i_call_type,
				'NDS', NDM_PRI_CD,
				'NDC', NDM_PRI_CD,
				'DMD', DMD_PRI_CD,
				'SHP', SHP_PRI_CD)
		  INTO	sql_stmt, l_pri_cd
		  FROM	DUAL;

		DBMS_OUTPUT.PUT_LINE ('After Select');
		pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'After Select', NULL, NULL);

		BEGIN
			SELECT	priority_value
			  INTO	l_priority
			  FROM	priority_code
			 WHERE	priority_code = l_pri_cd
			   AND	unpack_code = 'N';
			EXCEPTION
				WHEN NO_DATA_FOUND
				THEN
					l_priority := 99;
		END;
		DBMS_OUTPUT.PUT_LINE ('After Select Priority');
		pl_text_Log.ins_msg('I', ct_PROGRAM_CODE, 'After Select Priority', NULL, NULL);
			
		IF (i_call_type = 'DMD')
		THEN
			FOR rFD in cFD (i_route_no)
			LOOP
				AcquireNDMReplen (
					rFD.prod_id,
					rFD.cust_pref_vendor,
					acquired_qty);
				DeleteNDMRepl (
					rFD.prod_id,
					rFD.cust_pref_vendor,
					deleted_qty);
			END LOOP;
		END IF;

		DBMS_OUTPUT.PUT_LINE ('sql is ');

		i := 1;
		LOOP
			DBMS_OUTPUT.PUT_LINE (LTRIM (SUBSTR (sql_stmt, i, 50)));
			IF ((i + 50) < LENGTH (sql_stmt)) THEN
				i := i + 50;
			ELSE
				EXIT;
			END IF;
		END LOOP;

		Pl_Text_Log.ins_msg ('I', ct_PROGRAM_CODE,
			'SQL IS ' || sql_stmt, NULL, NULL);

		OPEN curRPL FOR sql_stmt;
		LOOP
			FETCH curRPL INTO r_ml_rpl;
			IF (curRPL%NOTFOUND)
			THEN
				EXIT;
			END IF;

			l_num_trays := r_ml_rpl.max_tr_per_itm - NVL (r_ml_rpl.curr_ml_trays, 0);

			IF (( r_ml_rpl.max_tr_per_itm = 1 AND l_num_trays = 0) AND
			    (r_ml_rpl.curr_repl_cases < r_ml_rpl.cs_per_carr)) THEN
				l_num_trays := 1;
			END IF;

			rpl_qty := (l_num_trays *
					r_ml_rpl.cs_per_carr -
					NVL (r_ml_rpl.curr_repl_cases, 0)) *
					r_ml_rpl.spc + NVL (r_ml_rpl.curr_qty_reqd, 0);

			IF (i_call_type = 'DMD')
			THEN
				rpl_qty := rpl_qty - l_qty;
			END IF;

			Pl_Text_Log.ins_msg ('I', ct_PROGRAM_CODE,
				'Create ML Replen For Item ' || r_ml_rpl.prod_id ||
				', Qty = ' || rpl_qty, NULL, NULL);

			IF (rpl_qty > 0) THEN
DBMS_OUTPUT.PUT_LINE ('PROD ID = ' || r_ml_rpl.prod_id || ', No Trays = ' || l_num_trays ||
	', Case/Carr = ' || NVL (r_ml_rpl.cs_per_carr, 0) || ', Qty Req = ' || NVL (i_qty_reqd, 0));
				GenMLCaseReplen (i_route_batch_no, i_route_no, r_ml_rpl.prod_id,
					 r_ml_rpl.cpv, rpl_qty, l_priority,
					 r_ml_rpl.ind_loc, i_call_type, r_ml_rpl.cs_per_carr,
					 r_ml_rpl.spc);
			END IF;
		END LOOP;
		
		CLOSE curRPL;
	
		EXCEPTION
		WHEN e_fail
		THEN
			Pl_Text_Log.ins_msg ('FATAL', lv_fname, lv_msg_text, NULL, NULL);
			o_status := pl_miniload_processing.ct_failure;
		WHEN OTHERS
		THEN
			lv_msg_text := 'Prog Code: ' || lv_fname
				|| ' Error in executing p_create_ndm_rpl.';
			Pl_Text_Log.ins_msg('FATAL',ct_PROGRAM_CODE,lv_msg_text,SQLCODE,SQLERRM);
			o_status := pl_miniload_processing.ct_failure;
	END p_create_ml_case_rpl;

END pl_ml_repl;
/
-- CREATE OR REPLACE PUBLIC SYNONYM pl_ml_repl FOR swms.pl_ml_repl
-- /
-- GRANT EXECUTE ON swms.pl_ml_repl TO swms_user
-- /
