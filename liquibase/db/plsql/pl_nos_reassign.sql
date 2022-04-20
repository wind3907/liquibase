rem @(#) File : pl_nos_reassign.sql
rem @(#) Usage: sqlplus USR/PWD pl_nos_reassign.sql

rem ---  Maintenance history  ---
rem 10-OCT-2004 prpakp Initial version
rem                    This will create new batches when batches are reassigned.
rem                    calculates the goal time for reassigned batches and
rem                    short batches. This is called from sosdb.pc
rem 25-FEB-2005 prpakp Added change to calculate cool data collection.
rem 31-OCT-2005 prpakp Corrected the reassign total pallet and cases count for reassigned batch.
rem 26-JUN-2006 prppxx Handle NULL value in parent_batch_no for optimum pull
rem		       batch (MULTI). D#12103.
rem 09/05/07	prplhj D#12279 Added some debug messages. Use BATCH
rem		       instead of SOS_BATCH to count the # of existing parent
rem		       and children batches.
rem 04/22/08    prpakp When an optimum pull batch was reassigned, the system didn't  
rem		       calculate the target time correctly. The target time was set as 0.
rem		       corrected the procedure UpdateTime for this.
rem 05/20/08    prpakp	Corrected to call pl_lm1 after creating new batch for the selected items
rem			so that the breaks and lunches are calculated correctly.
rem 07/10/08    prpakp	Corrected to update sos_short with short_batch_no when reassigned
rem 08/11/09	prplhj	D#12514 Preserved SOS_BATCH.picked_by if value is not
rem			empty when SOS_BATCH.staus is back to Future.
rem
CREATE OR REPLACE PACKAGE swms.pl_nos_reassign IS
/*================================================================================
** @(#) src/schema/plsql/pl_nos_reassign.sql, swms, swms.9, 11.1 8/13/09 1.17
**================================================================================*/
SKIP_REST	EXCEPTION;
lNotSelected	INTEGER := 0;

TYPE BatchRecord IS RECORD (
	num_stops		INTEGER,
	num_zones		INTEGER,
	num_floats		INTEGER,
	num_locs		INTEGER,
	num_splits		INTEGER,
	num_cases		INTEGER,
	num_merges		INTEGER,
	num_data_captures	INTEGER,
	total_cube		FLOAT,
	total_wt		FLOAT,
	num_aisles		INTEGER,
	num_items		INTEGER,
	num_routes		INTEGER,
	num_pieces		INTEGER
);

PROCEDURE sos_reassign ( i_batch_no	IN	batch.batch_no%TYPE,
			o_success	OUT	BOOLEAN);

PROCEDURE Create_ISTOP (pUserId		batch.user_id%TYPE,
			pBatchNo	batch.batch_no%TYPE);

PROCEDURE	CreateIRASGN (i_batch_no	batch.batch_no%TYPE);

PROCEDURE	SelectKVIShort (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			o_Batch		OUT	BatchRecord,
			o_success	OUT	BOOLEAN);

PROCEDURE	SelectKVISelected (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			o_Batch		OUT	BatchRecord,
			o_success	OUT	BOOLEAN);

PROCEDURE	SelectKVINew (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			o_Batch		OUT	BatchRecord,
			o_success	OUT	BOOLEAN);

PROCEDURE	CreateNewBatch (i_user_id	VARCHAR2,
				i_batch_no	VARCHAR2,
				i_Count		NUMBER,
				i_batch_rec	BatchRecord,
				o_success	OUT	BOOLEAN);

PROCEDURE	ReassignShort (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			i_lbr_active		VARCHAR2,
			o_success	OUT 	BOOLEAN);

PROCEDURE	ReassignSelected (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			i_lbr_active		VARCHAR2,
			o_success	OUT 	BOOLEAN);

PROCEDURE	UpdateTime (
			i_batch_no batch.batch_no%TYPE,
			i_Count		NUMBER DEFAULT 0);

PROCEDURE	CreateNewSOSBatch (
			i_user_id		VARCHAR2,
			i_batch_no		VARCHAR2,
			i_Count			NUMBER,
			i_batch_rec		BatchRecord,
			o_success	OUT	BOOLEAN);

PROCEDURE	UpdateFloatHist (
			i_batch_from VARCHAR2,
			i_batch_to VARCHAR2);

PROCEDURE	UpdateBatch (
			i_batch_no	VARCHAR2,
			i_batch_rec	BatchRecord,
			o_success	OUT	BOOLEAN);

PROCEDURE InitializeBatch (o_Batch OUT BatchRecord);

END pl_nos_reassign;
/
/*====================================================================================*/
CREATE OR REPLACE PACKAGE BODY swms.pl_nos_reassign IS
/* ========================================================================== */

PROCEDURE	CreateIRASGN (i_batch_no	batch.batch_no%TYPE) IS
BEGIN
	INSERT	INTO batch (batch_no, batch_date, jbcd_job_code, status,
			ref_no,actl_start_time, actl_stop_time,
			actl_time_spent, user_id, user_supervsr_ID,
			kvi_doc_time,kvi_cube,kvi_wt,kvi_no_piecE,
			kvi_no_pallet,kvi_no_item,kvi_no_data_caPTURE,
			kvi_no_po,kvi_no_stop,kvi_no_zone,kvi_no_LOC,
			kvi_no_case,kvi_no_split,kvi_no_merge,kvI_NO_AISLE,
			kvi_no_drop,kvi_order_time,no_lunches, no_breaks,damage)
	SELECT	'I' || TO_CHAR (seq1.NEXTVAL), batch_date, 'IRASGN', 'C',
		i_batch_no, actl_start_time, SYSDATE,
		(SYSDATE - actl_start_time) * 1440, user_id, user_supervsr_id,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  FROM	batch
	 WHERE	batch_no = 'S' || i_batch_no;
	DBMS_OUTPUT.PUT_LINE('CreateIRASGN: Insert IRASGN batch[' ||
		i_batch_no || ']: ' || TO_CHAR(SQL%ROWCOUNT));
	UPDATE	batch
	   SET	status = 'F',
		user_id = NULL,
		user_supervsr_ID = NULL,
		actl_start_time = NULL,
		actl_time_spent = NULL
	 WHERE	batch_no = 'S'||i_batch_no;
	DBMS_OUTPUT.PUT_LINE('CreateIRASGN: Reset to F for batch[' ||
		i_batch_no || ']: ' || TO_CHAR(SQL%ROWCOUNT));
	UPDATE	batch
	   SET	user_id = NULL,
		user_supervsr_ID = NULL,
		actl_start_time = NULL,
		actl_time_spent = NULL
	 WHERE	batch_no LIKE 'S'||i_batch_no || '%'
	   AND  status = 'M';
	DBMS_OUTPUT.PUT_LINE('CreateIRASGN: Reset merge for batch[' ||
		i_batch_no || ']: ' || TO_CHAR(SQL%ROWCOUNT));
END CreateIRASGN;

PROCEDURE	SelectKVIShort (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			o_Batch		OUT	BatchRecord,
			o_success	OUT	BOOLEAN) IS
	i_Batch		BatchRecord;
BEGIN
	DBMS_OUTPUT.PUT_LINE('SelectKVIShort: ' || i_user_id || '/' ||
		i_batch_no);
	o_success := TRUE;
	SELECT	1, 0, 1, v_kvi_locs, v_kvi_splits, v_kvi_cases, 0,
		v_kvi_data_captures, v_kvi_cube, v_kvi_wt, v_kvi_aisles,
		v_kvi_items, NULL, v_kvi_splits + v_kvi_cases
	  INTO	i_Batch
	  FROM	v_kvi_short
	 WHERE	short_batch_no = i_batch_no
	   AND	((i_user_id IS NULL AND flag_picked = 'N') OR
		(i_user_id IS NOT NULL AND flag_picked = 'Y'));
	DBMS_OUTPUT.PUT_LINE('SelectKVIShort #cse/spl[' ||
		TO_CHAR(i_Batch.num_cases) || '/' ||
		TO_CHAR(i_Batch.num_splits) || '] #loc[' || 
		TO_CHAR(i_Batch.num_locs) || '] #ai[' || 
		TO_CHAR(i_Batch.num_aisles) || '] #items[' || 
		TO_CHAR(i_Batch.num_items) || '] #datcap[' ||
		TO_CHAR(i_Batch.num_data_captures) || '] cub[' ||
		TO_CHAR(i_Batch.total_cube) || '] wt[' ||
		TO_CHAR(i_Batch.total_wt) || ']');
	o_Batch := i_Batch;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('SelectKVIShort batch[' ||
				i_batch_no || '] user[' || i_user_id ||
				']: no data found');
			InitializeBatch(o_Batch);
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('SelectKVIShort error: ' ||
				TO_CHAR(SQLCODE));
			o_success := FALSE;
END SelectKVIShort;

PROCEDURE	SelectKVISelected (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			o_Batch		OUT	BatchRecord,
			o_success	OUT	BOOLEAN) IS
	i_Batch	BatchRecord;
BEGIN
	o_success := TRUE;
	SELECT	v_kvi_stops, v_kvi_zones, v_kvi_floats, v_kvi_locs,
		v_kvi_splits, v_kvi_cases, v_kvi_merges,
		v_kvi_data_capture, v_kvi_split_cube + v_case_cube,
		v_kvi_split_wt + v_kvi_case_wt,
		v_kvi_aisle, v_kvi_item,
		v_kvi_route, v_kvi_splits + v_kvi_cases + v_kvi_merges
	  INTO	i_Batch
	  FROM	v_kvi_selected
	 WHERE	batch_no = i_batch_no
	   AND	selector_id = i_user_id;
	DBMS_OUTPUT.PUT_LINE('SelectKVISelected: ' || i_batch_no ||
		'/' || i_user_id || ' #cse/spl[' ||
		TO_CHAR(i_Batch.num_cases) || '/' ||
		TO_CHAR(i_Batch.num_splits) || '] #loc[' || 
		TO_CHAR(i_Batch.num_locs) || '] #zn[' || 
		TO_CHAR(i_Batch.num_zones) || '] #fl[' || 
		TO_CHAR(i_Batch.num_floats) || '] #merg[' || 
		TO_CHAR(i_Batch.num_merges) || '] #route[' || 
		TO_CHAR(i_Batch.num_routes) || '] #ai[' || 
		TO_CHAR(i_Batch.num_aisles) || '] #items[' || 
		TO_CHAR(i_Batch.num_items) || '] #datcap[' ||
		TO_CHAR(i_Batch.num_data_captures) || '] cub[' ||
		TO_CHAR(i_Batch.total_cube) || '] wt[' ||
		TO_CHAR(i_Batch.total_wt) || ']');
	o_Batch := i_Batch;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('SelectKVISelected batch[' ||
				i_batch_no || '] user[' || i_user_id ||
				']: no data found');
			InitializeBatch(o_Batch);
		WHEN OTHERS THEN
			o_success := FALSE;
END SelectKVISelected;

PROCEDURE	SelectKVINew (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			o_Batch		OUT	BatchRecord,
			o_success	OUT	BOOLEAN) IS
	i_Batch	BatchRecord;
BEGIN
	o_success := TRUE;
	SELECT	v_kvi_stops, v_kvi_zones, v_kvi_floats, v_kvi_locs,
		v_kvi_splits, v_kvi_cases, v_kvi_merges,
		v_kvi_data_capture, v_kvi_split_cube + v_kvi_case_cube,
		v_kvi_split_wt + v_kvi_case_wt,
		v_kvi_aisle, v_kvi_item,
		v_kvi_route, v_kvi_splits + v_kvi_cases + v_kvi_merges
	  INTO	i_Batch
	  FROM	v_kvi_new
	 WHERE	batch_no = i_batch_no;
	DBMS_OUTPUT.PUT_LINE('SelectKVINew: ' || i_batch_no ||
		'/' || i_user_id || ': #stp[' || TO_CHAR(i_Batch.num_stops) ||
		'] #cse[' || TO_CHAR(i_Batch.num_cases) || '] #spl[' ||
		TO_CHAR(i_Batch.num_splits) || '] #zn[' ||
		TO_CHAR(i_Batch.num_zones) || '] #fl[' ||
		TO_CHAR(i_Batch.num_floats) || '] #loc[' ||
		TO_CHAR(i_Batch.num_locs) || '] #merg[' ||
		TO_CHAR(i_Batch.num_merges) || '] #dacp[' ||
		TO_CHAR(i_Batch.num_data_captures) || '] cub[' ||
		TO_CHAR(i_Batch.total_cube) || '] wt[' ||
		TO_CHAR(i_Batch.total_wt) || '] #ai[' ||
		TO_CHAR(i_Batch.num_aisles) || '] #items[' ||
		TO_CHAR(i_Batch.num_items) || '] #route[' ||
		TO_CHAR(i_Batch.num_routes) || '] #pc[' ||
		TO_CHAR(i_Batch.num_pieces) || ']');
	o_Batch := i_Batch;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('SelectKVINew batch[' ||
				i_batch_no || '] user[' || i_user_id ||
				']: no data found');
			InitializeBatch(o_Batch);
		WHEN OTHERS THEN
			o_success := FALSE;
END SelectKVINew;

PROCEDURE	CreateNewBatch (i_user_id	VARCHAR2,
				i_batch_no	VARCHAR2,
				i_Count		NUMBER,
				i_batch_rec	BatchRecord,
				o_success	OUT	BOOLEAN) IS
BEGIN
	DBMS_OUTPUT.PUT_LINE('CreateNewBatch u: ' || i_user_id ||
		', b: ' || i_batch_no || TO_CHAR(i_Count));
	INSERT INTO BATCH ( batch_no, batch_date, status,
		jbcd_job_code, ref_no,actl_start_time,
		actl_stop_time,actl_time_spent,
		user_id,user_supervsr_id,kvi_cube, kvi_wt,
		kvi_no_piece, kvi_no_case, kvi_no_split,
		kvi_no_merge, kvi_no_item, kvi_no_stop,
		kvi_no_zone, kvi_no_loc, kvi_no_aisle,
		kvi_no_data_capture, kvi_no_pallet,
		parent_batch_no)
	SELECT	'S' || i_batch_no || i_Count, batch_date, 'C', jbcd_job_code,
		ref_no, actl_start_time, SYSDATE,
		(SYSDATE - actl_start_time) * 1440, user_id, user_supervsr_id,
		i_batch_rec.total_cube, i_batch_rec.total_wt,
		i_batch_rec.num_pieces, i_batch_rec.num_cases, i_batch_rec.num_splits,
		i_batch_rec.num_merges, i_batch_rec.num_items, i_batch_rec.num_stops,
		i_batch_rec.num_zones, i_batch_rec.num_locs, i_batch_rec.num_aisles,
		i_batch_rec.num_data_captures, i_batch_rec.num_floats,
		NULL
	  FROM	batch
	 WHERE	batch_no = 'S' || i_batch_no;
	IF SQL%ROWCOUNT = 0 THEN
		DBMS_OUTPUT.PUT_LINE('CreateNewBatch: No new batch is inserted');
	END IF;
	UpdateTime ('S' || i_batch_no, i_Count);
	o_success := TRUE;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE('CreateNewBatch failed: ' ||
				TO_CHAR(SQLCODE));
			o_success := FALSE;
END CreateNewBatch;

PROCEDURE	UpdateBatch (
			i_batch_no	VARCHAR2,
			i_batch_rec	BatchRecord,
			o_success	OUT	BOOLEAN) IS
	sRefNo		batch.ref_no%TYPE := NULL;
	CURSOR c_get_batch_kvis(csBatch batch.batch_no%TYPE) IS
		SELECT	SUM(NVL(kvi_no_piece,0)) kvi_no_piece,
			SUM(NVL(kvi_no_case,0)) kvi_no_case,
			SUM(NVL(kvi_no_split,0)) kvi_no_split,
			SUM(NVL(kvi_no_merge,0)) kvi_no_merge,
			SUM(NVL(kvi_no_aisle,0)) kvi_no_aisle,
			SUM(NVL(kvi_no_loc,0)) kvi_no_loc,
			SUM(NVL(kvi_no_stop,0)) kvi_no_stop,
			SUM(NVL(kvi_no_zone,0)) kvi_no_zone,
			SUM(NVL(kvi_no_item,0)) kvi_no_item,
			SUM(NVL(kvi_no_data_capture,0)) kvi_no_data_capture,
			SUM(NVL(kvi_no_pallet,0)) kvi_no_pallet
		FROM batch b
		WHERE parent_batch_no = 'S' || i_batch_no
		AND   batch_no <> parent_batch_no;
--		AND   add_date <> (SELECT MAX(add_date)
--				   FROM batch
--				   WHERE parent_batch_no = b.parent_batch_no
--				   AND   batch_no <> parent_batch_no);
BEGIN
	UPDATE	BATCH
	   SET	kvi_cube 	= i_batch_rec.total_cube,
    		kvi_wt 		= i_batch_rec.total_wt,
		kvi_no_piece 	= i_batch_rec.num_pieces, 
		kvi_no_case 	= i_batch_rec.num_cases, 
		kvi_no_split 	= i_batch_rec.num_splits,
		kvi_no_merge 	= i_batch_rec.num_merges, 
		kvi_no_item 	= i_batch_rec.num_items, 
		kvi_no_stop 	= i_batch_rec.num_stops,
		kvi_no_zone 	= i_batch_rec.num_zones, 
		kvi_no_loc 	= i_batch_rec.num_locs, 
		kvi_no_aisle 	= i_batch_rec.num_aisles,
		kvi_no_data_capture = i_batch_rec.num_data_captures, 
		kvi_no_pallet	= i_batch_rec.num_floats,
		user_id = NULL,
		user_supervsr_id = NULL,
		actl_start_time = NULL,
		actl_stop_time = NULL,
		actl_time_spent = NULL,
		status = 'F',
		sos_reserved = 1
	 WHERE	batch_no = 'S' || i_batch_no;
	DBMS_OUTPUT.PUT_LINE('UpdateBatch: Reset parent S' || i_batch_no ||
		' #pc[' || TO_CHAR(i_batch_rec.num_pieces) || '] #cse/spl[' ||
		TO_CHAR(i_batch_rec.num_cases) || '/' ||
		TO_CHAR(i_batch_rec.num_splits) || '] #merge[' ||
		TO_CHAR(i_batch_rec.num_merges) || '] #item[' ||
		TO_CHAR(i_batch_rec.num_items) || '] #stp[' ||
		TO_CHAR(i_batch_rec.num_stops) || '] #zn[' ||
		TO_CHAR(i_batch_rec.num_zones) || '] #loc[' ||
		TO_CHAR(i_batch_rec.num_locs) || '] #ai[' ||
		TO_CHAR(i_batch_rec.num_aisles) || '] #datac[' ||
		TO_CHAR(i_batch_rec.num_data_captures) || '] #fl[' ||
		TO_CHAR(i_batch_rec.num_floats) || '] cub[' ||
		TO_CHAR(i_batch_rec.total_cube) || '] wt[' ||
		TO_CHAR(i_batch_rec.total_wt) || '] ' ||
		'#rows: ' || TO_CHAR(SQL%ROWCOUNT));
	UPDATE	sos_batch
	   SET	reserved_by = REPLACE(USER, 'OPS$', '')
	 WHERE	batch_no = i_batch_no;
	DBMS_OUTPUT.PUT_LINE('UpdateBatch: Reserve SOS_BATCH: ' || i_batch_no ||
		', #rows: ' || TO_CHAR(SQL%ROWCOUNT));
	BEGIN
		SELECT ref_no INTO sRefNo
		FROM batch
		WHERE batch_no = 'S' || i_batch_no;
	EXCEPTION
		WHEN OTHERS THEN
			sRefNo := NULL;
	END;
--	DBMS_OUTPUT.PUT_LINE('Ref: ' || sRefNo);
	IF sRefNo = 'MULTI' THEN
		FOR cgbk IN c_get_batch_kvis(i_batch_no) LOOP
			DBMS_OUTPUT.PUT_LINE('UpdateBatch chkMULTI batch[' ||
				i_batch_no ||
				'] #pc[' || TO_CHAR(cgbk.kvi_no_piece) ||
				'] #cse/spl[' || TO_CHAR(cgbk.kvi_no_case) ||
				'/' || TO_CHAR(cgbk.kvi_no_split) ||
				'] #merge[' || TO_CHAR(cgbk.kvi_no_merge) ||
				'] #item[' || TO_CHAR(cgbk.kvi_no_item) ||
				'] #stp[' || TO_CHAR(cgbk.kvi_no_stop) ||
				'] #zn[' || TO_CHAR(cgbk.kvi_no_zone) ||
				'] #loc[' || TO_CHAR(cgbk.kvi_no_loc) ||
				'] #ai[' || TO_CHAR(cgbk.kvi_no_aisle) ||
				'] #datac[' ||
				TO_CHAR(cgbk.kvi_no_data_capture) || '] #pl[' ||
				TO_CHAR(cgbk.kvi_no_pallet) || ']');
			UPDATE BATCH
			SET kvi_cube = 0.0,
			    kvi_wt = 0.0,
			    kvi_no_piece = kvi_no_piece - cgbk.kvi_no_piece,
			    kvi_no_case  = kvi_no_case - cgbk.kvi_no_case,
			    kvi_no_split = kvi_no_split - cgbk.kvi_no_split,
			    kvi_no_merge = kvi_no_merge - cgbk.kvi_no_merge,
			    kvi_no_aisle = kvi_no_aisle - cgbk.kvi_no_aisle,
			    kvi_no_loc   = kvi_no_loc - cgbk.kvi_no_loc,
			    kvi_no_stop  = kvi_no_stop - cgbk.kvi_no_stop,
			    kvi_no_zone  = kvi_no_zone - cgbk.kvi_no_zone,
			    kvi_no_item  = kvi_no_item - cgbk.kvi_no_item,
			    kvi_no_data_capture = kvi_no_data_capture
				- cgbk.kvi_no_data_capture,
			    kvi_no_pallet = kvi_no_pallet - cgbk.kvi_no_pallet
			WHERE batch_no = 'S' || i_batch_no;
			DBMS_OUTPUT.PUT_LINE('UpdateBatch MULTI: ' ||
				i_batch_no ||
				' #stp[' ||
				TO_CHAR(i_batch_rec.num_stops - cgbk.kvi_no_stop) ||
				'] #cse[' || TO_CHAR(i_batch_rec.num_cases - cgbk.kvi_no_case) || '] #spl[' ||
				TO_CHAR(i_batch_rec.num_splits - cgbk.kvi_no_split) || '] #zn[' ||
				TO_CHAR(i_batch_rec.num_zones - cgbk.kvi_no_zone) || '] #fl[' ||
				TO_CHAR(i_batch_rec.num_floats) || '] #loc[' ||
				TO_CHAR(i_batch_rec.num_locs - cgbk.kvi_no_loc) || '] #merg[' ||
				TO_CHAR(i_batch_rec.num_merges - cgbk.kvi_no_merge) || '] #dacp[' ||
				TO_CHAR(i_batch_rec.num_data_captures - cgbk.kvi_no_data_capture) || '] cub[' ||
				TO_CHAR(i_batch_rec.total_cube) || '] wt[' ||
				TO_CHAR(i_batch_rec.total_wt) || '] #ai[' ||
				TO_CHAR(i_batch_rec.num_aisles - cgbk.kvi_no_aisle) || '] #items[' ||
				TO_CHAR(i_batch_rec.num_items - cgbk.kvi_no_item) || '] #route[' ||
				TO_CHAR(i_batch_rec.num_routes) || '] #pc[' ||
				TO_CHAR(i_batch_rec.num_pieces - cgbk.kvi_no_piece) || ']');
		END LOOP;
	END IF;
	UPDATE	BATCH
	   SET	user_id = NULL,
		user_supervsr_id = NULL,
		actl_start_time = NULL,
		actl_stop_time = NULL,
		actl_time_spent = NULL,
		sos_reserved = 0
	 WHERE	batch_no LIKE 'S' || i_batch_no || '%'
	   AND  status = 'M';
	DBMS_OUTPUT.PUT_LINE('UpdateBatch: Reset children S' || i_batch_no ||
		', #rows: ' || TO_CHAR(SQL%ROWCOUNT));
	o_success := TRUE;
	EXCEPTION
		WHEN OTHERS THEN
			o_success := FALSE;

END UpdateBatch;

PROCEDURE	UpdateSOSBatch (
			i_batch_no		VARCHAR2,
			i_batch_rec		BatchRecord,
			o_success	OUT	BOOLEAN) IS
BEGIN
	DBMS_OUTPUT.PUT_LINE('Update SOS_BATCH to F for ' || i_batch_no ||
		' #stp[' || TO_CHAR(i_batch_rec.num_stops) || '] #cse/spl[' ||
		TO_CHAR(i_batch_rec.num_cases) || '/' ||
		TO_CHAR(i_batch_rec.num_splits) || '] #itm[' ||
		TO_CHAR(i_batch_rec.num_items) || '] #aisles[' ||
		TO_CHAR(i_batch_rec.num_aisles) || '] #fl[' ||
		TO_CHAR(i_batch_rec.num_floats) || '] #merge[' ||
		TO_CHAR(i_batch_rec.num_merges) || '] #zon[' ||
		TO_CHAR(i_batch_rec.num_zones) || '] #loc[' ||
		TO_CHAR(i_batch_rec.num_locs) || '] #cub[' ||
		TO_CHAR(i_batch_rec.total_cube) || ']');
	BEGIN
		UPDATE	sos_batch
		   SET	status = 'F',
			no_of_floats = i_batch_rec.num_floats,
			no_of_stops = i_batch_rec.num_stops,
			no_of_cases = i_batch_rec.num_cases,
			no_of_splits = i_batch_rec.num_splits,
			no_of_merges = i_batch_rec.num_merges,
			no_of_items = i_batch_rec.num_items,
			no_of_aisles = i_batch_rec.num_aisles,
			no_of_zones = i_batch_rec.num_zones,
			no_of_locns = i_batch_rec.num_locs,
			batch_cube = i_batch_rec.total_cube,
			picked_by = DECODE(reserved_by, NULL, NULL, picked_by),
			last_pik_loc = NULL,
			orig_batch_no = NULL,
			start_time = NULL,
			end_time = NULL
		 WHERE	batch_no = i_batch_no;
		o_success := TRUE;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE ('UpdateSOSBatch:' || SQLERRM);
			o_success := FALSE;
	END;
END UpdateSOSBatch;

PROCEDURE	ReassignShort (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			i_lbr_active		VARCHAR2,
			o_success	OUT 	BOOLEAN) IS
	lShtSelected 		BatchRecord;
	lShtNotSelected 	BatchRecord;
	lTime			NUMBER (12, 2);
	l_batch_noS		NUMBER (2);
BEGIN
	o_success := FALSE;
	DBMS_OUTPUT.PUT_LINE ('ReassignShort, Lbr Active = ' || i_lbr_active);
	SelectKVIShort (i_user_id, i_batch_no, lShtSelected, o_success);
	DBMS_OUTPUT.PUT_LINE('ReassignShort Selected: ' || i_batch_no ||
		', #: ' || TO_CHAR(lShtSelected.num_cases) ||
		'/' || TO_CHAR(lShtSelected.num_splits) || ', cu: ' ||
		TO_CHAR(lShtSelected.total_cube));
	IF (o_success = FALSE) THEN
		RAISE SKIP_REST;
	END IF;
	SelectKVIShort (NULL, i_batch_no, lShtNotSelected, o_success);
	DBMS_OUTPUT.PUT_LINE('ReassignShort NOT Selected: ' || i_batch_no ||
		', #: ' || TO_CHAR(lShtNotSelected.num_cases) ||
		'/' || TO_CHAR(lShtNotSelected.num_splits) || ', cu: ' ||
		TO_CHAR(lShtNotSelected.total_cube));
	IF (o_success = FALSE) THEN
		RAISE SKIP_REST;
	END IF;
	IF (lShtSelected.num_locs = 0) THEN -- Nothing Selected. Reset the batch status to F
	BEGIN
		DBMS_OUTPUT.PUT_LINE ('ReassignShort, Nothing Selected on batch ' || i_batch_no);
		UPDATE	sos_batch
		   SET	status = 'F',
			picked_by = DECODE(reserved_by, NULL, NULL, picked_by),
			last_pik_loc = null,
			picked_time = null
		 WHERE	batch_no = i_batch_no;
		UpdateFloatHist (i_batch_no, NULL);
	END;
	ELSIF (lShtNotSelected.num_locs = 0) THEN -- All Selected. Set the batch status to C
	BEGIN
		DBMS_OUTPUT.PUT_LINE ('ReassignShort: All Selected on batch ' || i_batch_no);
		UPDATE	sos_batch
		   SET	status = 'C',
			end_time = SYSDATE
		 WHERE	batch_no = i_batch_no;
	END;
	ELSE -- The batch is partially selected. Split the batch into 2.
	BEGIN 
		DBMS_OUTPUT.PUT_LINE ('ReassignShort: Batch ' || i_batch_no || ', ' ||
			lShtSelected.num_locs || ' records selected');
		SELECT	COUNT (0)
		  INTO	l_batch_noS
--		  FROM	sos_batch
		  FROM	batch
		 WHERE	batch_no LIKE 'S' || i_batch_no || '%';
		DBMS_OUTPUT.PUT_LINE ('ReassignShort: Num Batches ' || l_batch_noS);
		DBMS_OUTPUT.PUT_LINE ('ReassignShort: calling CreateNewSOSBatch ( ' ||
			i_user_id || ', ' || i_batch_no || ', ' || l_batch_noS ||
			', lShtSelected , o_success)');
		CreateNewSOSBatch (i_user_id, i_batch_no, l_batch_noS, lShtSelected, o_success);
		IF (o_success = TRUE) THEN
			DBMS_OUTPUT.PUT_LINE ('ReassignShort: UpdateSOSBatch ');
			UpdateSOSBatch (i_batch_no, lShtNotSelected, o_success);
		END IF;
		IF (o_success = TRUE) THEN
			DBMS_OUTPUT.PUT_LINE ('ReassignShort: UpdateFloatHist ');
			UpdateFloatHist (i_batch_no, i_batch_no || l_batch_noS);
		END IF;
	END;
	END IF;
	IF (i_lbr_active = 'Y') THEN
	BEGIN
		IF (lShtSelected.num_locs = 0) THEN -- Nothing Selected. Reset the batch status to F
		BEGIN
			CreateIRASGN (i_batch_no);
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			UPDATE	batch
			   SET	status = 'F',
				user_id = NULL,
				actl_start_time = NULL,
				actl_stop_time = NULL
			 WHERE	batch_no = 'S' || i_batch_no;
			-- Handle MULTI children batches
			UPDATE	batch
			   SET	user_id = NULL,
				actl_start_time = NULL,
				actl_stop_time = NULL
			 WHERE	batch_no LIKE 'S' || i_batch_no || '%'
			 AND    status = 'M';
			o_success := TRUE;
			RAISE SKIP_REST;
		END;
		ELSIF (lShtNotSelected.num_locs = 0) THEN -- All Selected. Complete batch and get out.
		BEGIN
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			pl_lm1.create_schedule ('S' || i_batch_no, SYSDATE, lTime);
			UpdateTime ('S' || i_batch_no, 0);
			UPDATE	batch
			   SET	actl_stop_time = SYSDATE
			 WHERE	batch_no = 'S' || i_batch_no
			   AND	status = 'A';
			UPDATE	batch
			   SET	actl_stop_time = SYSDATE
			 WHERE	parent_batch_no = 'S' || i_batch_no
			   AND	status = 'M'
			   AND	actl_stop_time IS NULL;
			o_success := TRUE;
		END;
		ELSE -- The batch is partially selected. Split the batch into 2.
		BEGIN
			DBMS_OUTPUT.PUT_LINE ('ReassignShort, KVISelected Success');
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			CreateNewBatch (i_user_id, i_batch_no, l_batch_noS, lShtNotSelected, o_success);
			pl_lm1.create_schedule ('S' || i_batch_no||to_char(l_batch_noS), SYSDATE, lTime);
			IF (o_success = TRUE) THEN
				DBMS_OUTPUT.PUT_LINE ('ReassignShort CreateNewBatch Success');
				UpdateBatch (i_batch_no, lShtSelected, o_success);
				IF o_success = TRUE THEN
					DBMS_OUTPUT.PUT_LINE ('ReassignShort UpdateBatch Success');
				ELSE
					DBMS_OUTPUT.PUT_LINE ('ReassignShort UpdateBatch NOT Success');
				END IF;
				UpdateTime ('S' || i_batch_no, 0);
			END IF;
		END;
		END IF;
	END;
	END IF;
	EXCEPTION
		WHEN SKIP_REST THEN
			NULL;
END ReassignShort;

PROCEDURE ReassignAction (
	
	i_user_id		VARCHAR2,
	i_batch_no		batch.batch_no%TYPE,
	i_lbr_active		VARCHAR2,
	o_success	OUT 	BOOLEAN) IS
	lSelected 	BatchRecord;
	lNotSelected 	BatchRecord;
	lTime		NUMBER (12, 2) := 0;
	l_batch_noS	NUMBER (2) := 0;
BEGIN
	o_success := FALSE;
	DBMS_OUTPUT.PUT_LINE ('ReassignAction, Batch [' || i_batch_no || ']' ||
		' User [' || i_user_id || ']' ||
		' Lbr Active [' || i_lbr_active || ']');

	IF i_batch_no LIKE 'S%' THEN
		SelectKVIShort (i_user_id, i_batch_no, lSelected, o_success);
	ELSE
		SelectKVISelected (i_user_id, i_batch_no, lSelected, o_success);
	END IF;
	DBMS_OUTPUT.PUT_LINE('ReassignAction Selected: ' || i_batch_no ||
		', # cse/spl: ' || TO_CHAR(lSelected.num_cases) ||
		'/' || TO_CHAR(lSelected.num_splits) || ', cu: ' ||
		TO_CHAR(lSelected.total_cube) || ' #loc[' ||
		TO_CHAR(lSelected.num_locs) || ']');
	IF (o_success = FALSE) THEN
		RAISE	SKIP_REST;
	END IF;

	IF i_batch_no LIKE 'S%' THEN
		SelectKVIShort (NULL, i_batch_no, lNotSelected, o_success);
	ELSE
		SelectKVINew (NULL, i_batch_no, lNotSelected, o_success);
	END IF;
	DBMS_OUTPUT.PUT_LINE('ReassignAction NOT Selected: ' || i_batch_no ||
		', #: ' || TO_CHAR(lNotSelected.num_cases) ||
		'/' || TO_CHAR(lNotSelected.num_splits) || ', cu: ' ||
		TO_CHAR(lNotSelected.total_cube));
	IF (o_success = FALSE) THEN
		RAISE	SKIP_REST;
	END IF;

	IF (lSelected.num_locs = 0) THEN
	-- Nothing got selected. Reset batch status to F
	BEGIN
		UPDATE	sos_batch
		   SET	status = 'F',
			picked_by = DECODE(reserved_by, NULL, NULL, picked_by),
			last_pik_loc = null,
			picked_time = null
		 WHERE	batch_no = i_batch_no;
		DBMS_OUTPUT.PUT_LINE('ReassignAction Nothing Selected SOS_BATCH to F updated #rows: ' || TO_CHAR(SQL%ROWCOUNT));
		UpdateFloatHist (i_batch_no, NULL);
	END;
	ELSIF (lNotSelected.num_locs = 0) THEN
	-- Everything selected. Set batch status to C.
	BEGIN
		UPDATE	sos_batch
		   SET	status = 'C',
			end_time = SYSDATE
		 WHERE	batch_no = i_batch_no;
		DBMS_OUTPUT.PUT_LINE('ReassignAction All Selected SOS_BATCH to C: ' || TO_CHAR(SQL%ROWCOUNT));
	END;
	ELSE -- Partially selected. Split the Batch
	BEGIN
		SELECT	COUNT (DISTINCT batch_no)
		  INTO	l_batch_noS
		  FROM	batch
		 WHERE	batch_no LIKE 'S' || i_batch_no || '%';
		DBMS_OUTPUT.PUT_LINE('ReassignAction Partially Selected next batch ' ||
			i_batch_no || TO_CHAR(l_batch_noS) ||
			' #loc[' || TO_CHAR(lSelected.num_locs) || ']');
		CreateNewSOSBatch (i_user_id, i_batch_no, l_batch_noS, lSelected, o_success);
		IF (o_success = TRUE) THEN
		BEGIN
			DBMS_OUTPUT.PUT_LINE('ReassignAction Create new batch ' || i_batch_no || l_batch_noS || ' for Selected');
			UpdateSOSBatch (i_batch_no, lNotSelected, o_success);
			IF o_success THEN
				DBMS_OUTPUT.PUT_LINE('ReassignAction SOS_BATCH update ok for NOT Selected');
			ELSE
				DBMS_OUTPUT.PUT_LINE('ReassignAction SOS_BATCH update NOT ok for NOT Selected');
			END IF;
		END;
		ELSE
			DBMS_OUTPUT.PUT_LINE('ReassignAction Error Create new batch for Selected');
		END IF;
		IF (o_success = TRUE) THEN
			UpdateFloatHist (i_batch_no, i_batch_no || l_batch_noS);
			DBMS_OUTPUT.PUT_LINE('ReassignAction FLOAT_HIST updated');
		END IF;
	END;
	END IF;

	IF (i_lbr_active = 'Y') THEN
	BEGIN
		IF (lSelected.num_locs = 0) THEN
		-- Nothing got selected. Reset batch status to F
		BEGIN
			CreateIRASGN (i_batch_no);
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			DBMS_OUTPUT.PUT_LINE('ReassignAction Created IRASGN and ISTOP for batch ' || i_batch_no);

			UPDATE	batch
			   SET	status = 'F',
				user_id = NULL,
				actl_start_time = NULL,
				actl_stop_time = NULL
			 WHERE	batch_no = 'S' || i_batch_no;
			DBMS_OUTPUT.PUT_LINE('ReassignAction BATCH update to F for parent batch [' || i_batch_no || ']: ' || TO_CHAR(SQL%ROWCOUNT));

			-- Handle MULTI children batches
			UPDATE	batch
			   SET	user_id = NULL,
				actl_start_time = NULL,
				actl_stop_time = NULL
			 WHERE	batch_no LIKE 'S' || i_batch_no || '%'
			 AND    status = 'M';
			DBMS_OUTPUT.PUT_LINE('ReassignAction BATCH children reset for batch [' || i_batch_no || ']: ' || TO_CHAR(SQL%ROWCOUNT));
		END;
		ELSIF (lNotSelected.num_locs = 0) THEN
		-- All got selected. Set batch status to C
		BEGIN
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			pl_lm1.create_schedule ('S' || i_batch_no, SYSDATE, lTime);
			DBMS_OUTPUT.PUT_LINE('ReassignAction Created ISTOP and finish batch for batch ' || i_batch_no || ' and update goal time');
			UpdateTime ('S' || i_batch_no, 0);
			UPDATE	batch
			   SET	actl_stop_time = SYSDATE
			 WHERE	parent_batch_no = 'S' || i_batch_no
			   AND	status = 'M';
			DBMS_OUTPUT.PUT_LINE('ReassignAction BATCH children done for batch [' || i_batch_no || ']: ' || TO_CHAR(SQL%ROWCOUNT));
		END;
		ELSE
		BEGIN
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			CreateNewBatch (i_user_id, i_batch_no, l_batch_noS, lSelected, o_success);
			pl_lm1.create_schedule ('S' || i_batch_no|| to_char(l_batch_noS), SYSDATE, lTime);
			DBMS_OUTPUT.PUT_LINE('ReassignAction Created ISTOP and new batch [' || i_batch_no || TO_CHAR(l_batch_noS) || ']');
			IF (o_success = TRUE) THEN
				UpdateBatch (i_batch_no, lNotSelected, o_success);
				UpdateTime ('S' || i_batch_no, 0);
				DBMS_OUTPUT.PUT_LINE('ReassignAction Update BATCH NOT Selected for batch ' || i_batch_no || ' and goal time');
			END IF;
		END;
		END IF;
	END;
	END IF;
EXCEPTION
	WHEN SKIP_REST THEN
		NULL;
END ReassignAction;

PROCEDURE	ReassignSelected (
			i_user_id		VARCHAR2,
			i_batch_no		batch.batch_no%TYPE,
			i_lbr_active		VARCHAR2,
			o_success	OUT 	BOOLEAN) IS
	lSelected 	BatchRecord;
	lNotSelected 	BatchRecord;
	lTime		NUMBER (12, 2) := 0;
	l_batch_noS	NUMBER (2) := 0;
BEGIN
	o_success := FALSE;
	DBMS_OUTPUT.PUT_LINE ('ReassignSelected, Lbr Active = ' || i_lbr_active);
	SelectKVISelected (i_user_id, i_batch_no, lSelected, o_success);
	DBMS_OUTPUT.PUT_LINE('ReassignSelected Selected: ' || i_batch_no ||
		', #: ' || TO_CHAR(lSelected.num_cases) ||
		'/' || TO_CHAR(lSelected.num_splits) || ', cu: ' ||
		TO_CHAR(lSelected.total_cube));
	IF (o_success = FALSE) THEN
		RAISE	SKIP_REST;
	END IF;
	SelectKVINew (NULL, i_batch_no, lNotSelected, o_success);
	DBMS_OUTPUT.PUT_LINE('ReassignSelected NOT Selected: ' || i_batch_no ||
		', #: ' || TO_CHAR(lNotSelected.num_cases) ||
		'/' || TO_CHAR(lNotSelected.num_splits) || ', cu: ' ||
		TO_CHAR(lNotSelected.total_cube));
	IF (o_success = FALSE) THEN
		RAISE	SKIP_REST;
	END IF;
	IF (lSelected.num_locs = 0) THEN -- Nothing got selected. Reset batch status to F
	BEGIN
		UPDATE	sos_batch
		   SET	status = 'F',
			picked_by = DECODE(reserved_by, NULL, NULL, picked_by),
			last_pik_loc = null,
			picked_time = null
		 WHERE	batch_no = i_batch_no;
		UpdateFloatHist (i_batch_no, NULL);
	END;
	ELSIF (lNotSelected.num_locs = 0) THEN -- Everything selected. Set batch status to C.
	BEGIN
		UPDATE	sos_batch
		   SET	status = 'C',
			end_time = SYSDATE
		 WHERE	batch_no = i_batch_no;
	END;
	ELSE -- Partially selected. Split the Batch
	BEGIN
		SELECT	TO_CHAR (COUNT (batch_no))
		  INTO	l_batch_noS
--		  FROM	sos_batch
		  FROM	batch
		 WHERE	batch_no LIKE 'S' || i_batch_no || '%';
		DBMS_OUTPUT.PUT_LINE('ReassignSelected: next batch ' ||
			i_batch_no || TO_CHAR(l_batch_noS) || ', u: ' ||
			i_user_id);
		CreateNewSOSBatch (i_user_id, i_batch_no, l_batch_noS, lSelected, o_success);
		IF (o_success = TRUE) THEN
		BEGIN
			UpdateSOSBatch (i_batch_no, lNotSelected, o_success);
		END;
		END IF;
		UpdateFloatHist (i_batch_no, i_batch_no || l_batch_noS);
	END;
	END IF;
	IF (i_lbr_active = 'Y') THEN
	BEGIN
		IF (lSelected.num_locs = 0) THEN -- Nothing got selected. Reset batch status to F
		BEGIN
			CreateIRASGN (i_batch_no);
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			UPDATE	batch
			   SET	status = 'F',
				user_id = NULL,
				actl_start_time = NULL,
				actl_stop_time = NULL
			 WHERE	batch_no = 'S' || i_batch_no;
			-- Handle MULTI children batches
			UPDATE	batch
			   SET	user_id = NULL,
				actl_start_time = NULL,
				actl_stop_time = NULL
			 WHERE	batch_no LIKE 'S' || i_batch_no || '%'
			 AND    status = 'M';
		END;
		ELSIF (lNotSelected.num_locs = 0) THEN -- All got selected. Set batch status to C
		BEGIN
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			pl_lm1.create_schedule ('S' || i_batch_no, SYSDATE, lTime);
			UpdateTime ('S' || i_batch_no, 0);
			UPDATE	batch
			   SET	actl_stop_time = SYSDATE
			 WHERE	parent_batch_no = 'S' || i_batch_no
			   AND	status = 'M';
		END;
		ELSE
		BEGIN
			DBMS_OUTPUT.PUT_LINE ('ReassignSelected, KVISelected Success');
			Create_ISTOP (i_user_id, 'S' || i_batch_no);
			CreateNewBatch (i_user_id, i_batch_no, l_batch_noS, lSelected, o_success);
			pl_lm1.create_schedule ('S' || i_batch_no || to_char(l_batch_noS), SYSDATE, lTime);
			IF (o_success = TRUE) THEN
				UpdateBatch (i_batch_no, lNotSelected, o_success);
				UpdateTime ('S' || i_batch_no, 0);
			END IF;
		END;
		END IF;
	END;
	END IF;
	EXCEPTION
		WHEN SKIP_REST THEN
			NULL;
END ReassignSelected;

PROCEDURE sos_reassign (
		i_batch_no	IN	batch.batch_no%TYPE,
		o_success	OUT	BOOLEAN) IS
	lSuccess	VARCHAR2 (1) := 'Y';
	lLbrActive	VARCHAR2 (1);
	lUserId		sos_batch.picked_by%TYPE;
	lSupervisor	usr.suprvsr_user_id%TYPE := NULL;
	lLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
	e_bad_user	EXCEPTION;
BEGIN
	BEGIN
		SELECT	DECODE (s.config_flag_val, 'Y',
				l.create_batch_flag, 'N'),
			picked_by
		  INTO	lLbrActive, lUserId
		  FROM	sys_config s, lbr_func l, job_code j, sos_batch sb
		 WHERE	sb.batch_no = i_batch_no
		   AND	j.jbcd_job_code = sb.job_code
		   AND	l.lfun_lbr_func = j. lfun_lbr_func
		   AND	s.config_flag_name = 'LBR_MGMT_FLAG';
		EXCEPTION
			WHEN OTHERS THEN
				lLbrActive := 'N';
	END;
	DBMS_OUTPUT.PUT_LINE('LBR flag: ' || lLbrActive || ', u: ' ||
		lUserId || ', bat: ' || i_batch_no);
	IF lLbrActive = 'Y' THEN
		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	lSupervisor, lLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || lUserId;
			DBMS_OUTPUT.PUT_LINE('sos_reassign for u ' || lUserId ||
				' get supervisor: ' || lSupervisor ||
				' lbrgrp: ' || lLbrGrp);
			IF lSupervisor IS NULL OR lLbrGrp IS NULL THEN
				lSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				IF lUserId IS NULL THEN
					-- User has no active batch
					NULL;
				ELSE
					DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor for ' || lUserId);
					o_success := FALSE;
					lSuccess := 'N';
				END IF;
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				': Cannot find supervisor for ' || lUserId);
				o_success := FALSE;
				lSuccess := 'N';
		END;
		IF lSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;
	END IF;
	IF (i_batch_no LIKE 'S%') THEN
		DBMS_OUTPUT.PUT_LINE ('ReassignShort');
		ReassignAction (lUserId, i_batch_no, lLbrActive, o_success);
	ELSE
		DBMS_OUTPUT.PUT_LINE ('ReassignSelected');
		ReassignAction (lUserId, i_batch_no, lLbrActive, o_success);
	END IF;
EXCEPTION
	WHEN e_bad_user THEN
		o_success := FALSE;
		RAISE_APPLICATION_ERROR(pl_exc.ct_lm_bad_user,
			'User ' || lUserId ||
			' is not set up in Labor Management');
	WHEN OTHERS THEN
		RAISE;
END sos_reassign;

PROCEDURE Create_ISTOP (pUserId		batch.user_id%TYPE,
			pBatchNo	batch.batch_no%TYPE) IS
	lSupervisor	usr.suprvsr_user_id%TYPE;
	lDuration	INTEGER;
BEGIN
	DBMS_OUTPUT.PUT_LINE('CreateISTOP for b/u ' || pBatchNo || '/' ||
		pUserId);
	BEGIN
	SELECT	suprvsr_user_id 
	  INTO	lSupervisor
	  FROM	usr
	 WHERE	user_id = 'OPS$' || pUserId;
	DBMS_OUTPUT.PUT_LINE('CreateISTOP for b/u ' || pBatchNo || '/' ||
		pUserId || ' (get supervisor)');
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			IF pUserId IS NULL THEN
				-- User has no active batch
				NULL;
			END IF;
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				': Cannot find supervisor for ' || pUserId);
	END;

	BEGIN
		SELECT	NVL ( st.stop_dur, 0 ) 
		  INTO	lDuration
		  FROM	sched_type st, sched s, usr u, batch b, job_code jc
		 WHERE	st.sctp_sched_type = s.sched_type            
		   AND	s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp        
		   AND	s.sched_jbcl_job_class = jc.jbcl_job_class   
		   AND	s.sched_actv_flag = 'Y'                      
		   AND	u.user_id = 'OPS$' || pUserId
		   AND	jc.jbcd_job_code = b.jbcd_job_code           
		   AND	b.batch_no = pBatchNo;

		DBMS_OUTPUT.PUT_LINE('CreateISTOP for b/u ' || pBatchNo || '/' ||
			pUserId || ' duration [' || TO_CHAR(lDuration) || ']');
	EXCEPTION
		WHEN OTHERS THEN
			lDuration := 0;
	END;

	IF (lDuration > 0) THEN
	BEGIN
		INSERT INTO batch (batch_no, batch_date, jbcd_job_code, status,
			actl_start_time, actl_stop_time,
			actl_time_spent, user_id, user_supervsr_id,
			kvi_doc_time, kvi_cube, kvi_wt, kvi_no_piece,
			kvi_no_pallet, kvi_no_item, kvi_no_data_capture,
			kvi_no_po, kvi_no_stop, kvi_no_zone, kvi_no_loc,
			kvi_no_case, kvi_no_split, kvi_no_merge, kvi_no_aisle,
			kvi_no_drop, kvi_order_time, no_lunches,  no_breaks, damage)
		VALUES ('I' || TO_CHAR (seq1.NEXTVAL), TRUNC (SYSDATE), 'IWASH', 'C',
			SYSDATE, ( SYSDATE + (lDuration / 1440 ) ),
			lDuration, pUserId, lSupervisor, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
	END;
	END IF;

	INSERT INTO BATCH (
		batch_no, batch_date, jbcd_job_code, status,
		actl_start_time, actl_stop_time,
		actl_time_spent, user_id, user_supervsr_id,
		kvi_doc_time, kvi_cube, kvi_wt, kvi_no_piece,
		kvi_no_pallet, kvi_no_item, kvi_no_data_capture,
		kvi_no_po, kvi_no_stop, kvi_no_zone, kvi_no_loc,
		kvi_no_case, kvi_no_split, kvi_no_merge, kvi_no_aisle,
		kvi_no_drop, kvi_order_time, no_lunches,  no_breaks, damage)
	VALUES	('I' || TO_CHAR (seq1.NEXTVAL), TRUNC (SYSDATE), 'ISTOP', 'C',
		(SYSDATE + (lDuration / 1440 ) ), ( SYSDATE + (lDuration / 1440 ) ),
		0, pUserId, lSupervisor, 0, 0, 0, 0, 0, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
	DBMS_OUTPUT.PUT_LINE('CreateISTOP for b/u ' || pBatchNo || '/' ||
		pUserId || ' done');

END Create_ISTOP;

PROCEDURE   UpdateTime (
		i_batch_no batch.batch_no%TYPE,
		i_Count	NUMBER DEFAULT 0) IS

	sRefNo		batch.ref_no%TYPE := NULL;
	sEngStdFlag	job_code.engr_std_flag%TYPE := 'N';
	iMergeTotTime	NUMBER := 0;

	CURSOR c_get_time(csBatch batch.batch_no%TYPE, ciCount NUMBER) IS
		SELECT engr_std_flag, l_total_time
		FROM v_calc_time_total
		WHERE batch_no = csBatch || DECODE(ciCount, 0, NULL,
						TO_CHAR(ciCount));

	CURSOR c_get_time2(csBatch batch.batch_no%TYPE, ciCount NUMBER) IS
		SELECT goal_time, target_time, ref_no,
			total_count, total_pallet, total_piece
		FROM batch
		WHERE batch_no = csBatch || DECODE(ciCount, 0, NULL,
						TO_CHAR(ciCount));
BEGIN
	DBMS_OUTPUT.PUT_LINE('UpdateTime for batch ' || i_batch_no || '*' || TO_CHAR(i_Count));

	FOR cgt IN c_get_time(i_batch_no, i_Count) LOOP
		sEngStdFlag := cgt.engr_std_flag;
		DBMS_OUTPUT.PUT_LINE('UpdateTime flag[' || cgt.engr_std_flag ||
			'] totTime[' || TO_CHAR(cgt.l_total_time) || ']');
	END LOOP;

	FOR cgt IN c_get_time2(i_batch_no, i_Count) LOOP
		sRefNo := cgt.ref_no;
		DBMS_OUTPUT.PUT_LINE('UpdateTime bf goal[' ||
			i_batch_no || '*' || TO_CHAR(i_Count) || '] goal[' ||
			TO_CHAR(cgt.goal_time) || '] tgt[' ||
			TO_CHAR(cgt.target_time) || '] ref[' || cgt.ref_no ||
			']');
	END LOOP;


        BEGIN

		UPDATE	batch
	   	SET	(goal_time, target_time) =
			(SELECT	DECODE (engr_std_flag, 'Y', l_total_time, 0),
				DECODE (engr_std_flag, 'Y', 0, l_total_time)
			   FROM	v_calc_time_total
	 		  WHERE	batch_no = i_batch_no || DECODE (i_Count, 0, NULL, TO_CHAR (i_Count)))
	 	WHERE	batch_no = i_batch_no || DECODE (i_Count, 0, NULL, TO_CHAR (i_Count));

		DBMS_OUTPUT.PUT_LINE('UpdateTime: Update batch[' ||
			i_batch_no || '*' || TO_CHAR(i_Count) ||
			'] goal/target #row[' || TO_CHAR(SQL%ROWCOUNT) || ']');

		FOR cgt IN c_get_time2(i_batch_no, i_Count) LOOP
			DBMS_OUTPUT.PUT_LINE('UpdateTime af batch[' ||
				i_batch_no || '*' || TO_CHAR(i_Count) || '] goal[' ||
				TO_CHAR(cgt.goal_time) || '] tgt[' ||
				TO_CHAR(cgt.target_time) || ']');
		END LOOP;
		EXCEPTION
			WHEN OTHERS THEN
				NULL;
        END;
	/*IF (i_Count = 0) THEN*/
	BEGIN

		UPDATE	batch
		   SET	(total_count, total_pallet, total_piece) = 
			(SELECT	1,
				SUM (NVL (kvi_no_pallet, 0)),
				SUM (NVL (kvi_no_piece, 0))
			   FROM	batch
			  WHERE	NVL (parent_batch_no, batch_no) = i_batch_no || DECODE (i_Count, 0, NULL, TO_CHAR (i_Count)))
	 	WHERE	batch_no = i_batch_no || DECODE (i_Count, 0, NULL, TO_CHAR (i_Count));
		/* WHERE	batch_no = i_batch_no; */

		FOR cgt IN c_get_time2(i_batch_no, i_Count) LOOP
			DBMS_OUTPUT.PUT_LINE('UpdateTime af totcnt[' ||
				TO_CHAR(cgt.total_count) || '] totpal[' ||
				TO_CHAR(cgt.total_pallet) || '] totpc[' ||
				TO_CHAR(cgt.total_piece) || ']');
		END LOOP;
		EXCEPTION
			WHEN OTHERS THEN
				NULL;
	END;
/*	END IF;*/

	IF i_Count = 0 AND sRefNo = 'MULTI' THEN
	BEGIN
		BEGIN
			SELECT SUM(NVL(l_total_time, 0)) INTO iMergeTotTime
			FROM v_calc_time_total
			WHERE batch_no LIKE i_batch_no || '%'
			AND   l_status = 'M';
		EXCEPTION
			WHEN OTHERS THEN
				iMergeTotTime := 0;
		END;

		DBMS_OUTPUT.PUT_LINE('UpdateTime: Merge total time[' || TO_CHAR(iMergeTotTime) || ']');

		UPDATE batch
		   SET	goal_time = DECODE(sEngStdFlag, 
					'Y', iMergeTotTime + DECODE(SIGN(NVL(goal_time, 0) - 0),
								-1, NVL(goal_time, 0),
								    (-1) * NVL(goal_time, 0)),
				         0),
			target_time = DECODE(sEngStdFlag,
					'Y', 0,
				            iMergeTotTime + DECODE(SIGN(NVL(target_time, 0) - 0),
								-1, NVL(target_time, 0),
								    (-1) * NVL(target_time,0)))
		 WHERE	batch_no = i_batch_no;

		DBMS_OUTPUT.PUT_LINE('UpdateTime: batch[' ||
			i_batch_no || ']: update goal/target #rows[' ||
			TO_CHAR(SQL%ROWCOUNT) || ']');
		FOR cgt IN c_get_time2(i_batch_no, i_Count) LOOP
			DBMS_OUTPUT.PUT_LINE('UpdateTime af recal batch[' ||
				i_batch_no || '*' || TO_CHAR(i_Count) ||
				'] goal[' ||
				TO_CHAR(cgt.goal_time) || '] tgt[' ||
				TO_CHAR(cgt.target_time) || ']');
		END LOOP;
	END;
	END IF;

	EXCEPTION
		WHEN OTHERS THEN
			NULL;
END UpdateTime;

PROCEDURE	CreateNewSOSBatch (
			i_user_id		VARCHAR2,
			i_batch_no		VARCHAR2,
			i_Count			NUMBER,
			i_batch_rec		BatchRecord,
			o_success	OUT	BOOLEAN) IS
BEGIN
	INSERT	INTO sos_batch (batch_no, batch_date, status, job_code,
		no_of_floats, no_of_stops, no_of_cases, no_of_splits,
		no_of_merges, no_of_fdtls, no_of_fdqty, no_of_items,
		no_of_aisles, no_of_zones, no_of_locns, is_unitized,
		is_optimum, ship_date, batch_cube, picked_by,
		last_pik_loc, orig_batch_no, start_time, end_time,
		area, route_no, truck_no)
		SELECT	i_batch_no || i_Count, batch_date, 'C',
			job_code, 1, i_batch_rec.num_stops,
			i_batch_rec.num_cases, 
			i_batch_rec.num_splits, i_batch_rec.num_merges,
			0, 0, i_batch_rec.num_items, i_batch_rec.num_aisles,
			i_batch_rec.num_zones, i_batch_rec.num_locs, 'N',
			'N', ship_date, i_batch_rec.total_cube,
			i_user_id, null, i_batch_no, start_time, SYSDATE,
			area, route_no, truck_no
		  FROM	sos_batch
		 WHERE	batch_no = i_batch_no;
	DBMS_OUTPUT.PUT_LINE('CreateNewSOSBatch: bat[' || i_batch_no ||
		TO_CHAR(i_Count) || '] status[C] u[' || i_user_id ||
		'] #stp[' || TO_CHAR(i_batch_rec.num_stops) || '] #cse[' ||
		TO_CHAR(i_batch_rec.num_cases) || '] #spl[' ||
		TO_CHAR(i_batch_rec.num_splits) || '] #merg[' ||
		TO_CHAR(i_batch_rec.num_merges) || '] #item[' ||
		TO_CHAR(i_batch_rec.num_items) || '] #ai[' ||
		TO_CHAR(i_batch_rec.num_aisles) || '] #zn[' ||
		TO_CHAR(i_batch_rec.num_zones) || '] #loc[' ||
		TO_CHAR(i_batch_rec.num_locs) || '] cub[' ||
		TO_CHAR(i_batch_rec.total_cube) || ']');
	o_success := TRUE;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE ('CreateNewSOSBatch:' || SQLERRM);
			o_success := FALSE;
END CreateNewSOSBatch;

PROCEDURE UpdateFloatHist (i_batch_from VARCHAR2, i_batch_to VARCHAR2) IS
BEGIN
	DBMS_OUTPUT.PUT_LINE('UpdateFloatHist batch from[' ||
		i_batch_from || ']  to[' || i_batch_to || ']');
	IF (i_batch_from LIKE 'S%') THEN
	BEGIN
		UPDATE	float_hist
		   SET	short_batch_no = i_batch_to
		 WHERE	short_batch_no = i_batch_from
		   AND	short_picktime IS NOT NULL;
		
		UPDATE SOS_SHORT
                        SET SHORT_BATCH_NO = i_batch_to
                        WHERE SHORT_BATCH_NO= i_batch_from
                        AND   ORDERSEQ IN (SELECT v.ORDERSEQ
                                           FROM V_SOS_SHORT v,FLOAT_HIST h
                                           WHERE v.BATCH_NO = h.BATCH_NO
                                           AND   v.INVOICENO= h.ORDER_ID
                                           AND   v.ORDER_LINE_ID = h.ORDER_LINE_ID
                                           AND   v.ITEM = h.PROD_ID
                                           AND   h.SHORT_BATCH_NO = i_batch_to);
	END;
	ELSE
	BEGIN
		UPDATE	float_hist
		   SET	batch_no = i_batch_to
		 WHERE	batch_no = i_batch_from
		   AND	picktime IS NOT NULL;
	END;
	END IF;
	DBMS_OUTPUT.PUT_LINE('UpdateFloatHist batch from[' ||
		i_batch_from || ']  to[' || i_batch_to || '] #rows[' ||
		TO_CHAR(SQL%ROWCOUNT) || ']');
END UpdateFloatHist;

PROCEDURE InitializeBatch(o_Batch OUT BatchRecord) IS
BEGIN
	o_Batch.num_stops := 0;
	o_Batch.num_zones := 0;
	o_Batch.num_floats := 0;
	o_Batch.num_locs := 0;
	o_Batch.num_splits := 0;
	o_Batch.num_cases := 0;
	o_Batch.num_merges := 0;
	o_Batch.num_data_captures := 0;
	o_Batch.total_cube := 0;
	o_Batch.total_wt := 0;
	o_Batch.num_aisles := 0;
	o_Batch.num_items := 0;
	o_Batch.num_routes := 0;
	o_Batch.num_pieces := 0;
END InitializeBatch;

END pl_nos_reassign;
/
