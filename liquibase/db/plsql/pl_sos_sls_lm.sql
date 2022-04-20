CREATE OR REPLACE PACKAGE swms.pl_sos_sls_lm IS

-- *********************** <Package Specifications> ****************************

-- ************************* <Prefix Documentations> ***************************

--  This package specification is used to do SLS processing.

--  @(#) src/schema/plsql/pl_sos_sls_lm.sql, swms, swms.9, 11.2 4/26/10 1.5

--  Modification History
--  Date      User      Defect  Comment
--  07/31/06  prfxa000  12402   Initial creation
--  10/24/08  prplhj    12430   Added swms qualifier to package spec and body.
--  09/01/09  prplhj    12516   Fixed exit_float_label() to update the correct
--				                las_pallet record.
--  01/26/10  tsow0456    12554      212 Enh - SCE017 - Move Entire Stop
--                              Added procedures for stop related functions 
--				las_pallet record.
--  04/26/10  prplhj    12578   Fixed exit_float_label() to replace 'L10:13:45' with
--				'L%U_' and 'L%U__' to bypass CMVC variable
--				substitution problems. Fixed CreateISTART()
--				to not include 'L' for batch query during
--				duration time retrieval.
--  11/01/11  jluo5859	PBI3275/CR29306	Change LoadStop() batch creation to
--			separate float # and stop # into 2 different columns.
--  04/30/13 avij3336    CRQ#42225  - inserted a query in loadpallet,exit_case_label,exit_zone_label and exit_stop 
--                                         to fetch the stop time of the last completed  batch and passed this value to call the 'create_ilexit' procedure. 
--  01/17/14 bgul2852   CRQ49071 Changed kvi_no_pallet for batch to 0 instead of 1.
--  05/19/14 bgul2852   Charm 6000001433 : Loader indirect time is off-job assignments not running consecutively with each other.
--  11/27/15 aklu6632   Activity: Charm600003040_DML_IChange_Function
--                      Project:  Charm600003040
--                      modify function exit_float_label called by SOS_logout.pc
--                      to remove the code for ISTOP and Complete current batch since it is did in SOS_logout
-- ******************** <End of Prefix Documentations> *************************

-- ************************* <Constant Definitions> ****************************

	ERR_LM_BATCH_UPD_FAIL	NUMBER := 145;
	ERR_NO_LM_BATCH		NUMBER := 146;
	ERR_LM_JOBCODE_NOT_FOUND	NUMBER := 150;
	ERR_LM_SCHED_NOT_FOUND	NUMBER := 151;
	ERR_LM_BAD_USER		NUMBER := 156;
	ERR_LM_INS_ISTOP_FAIL	NUMBER := 158;
	ERR_LM_INV_LBR_GRP	NUMBER := 274;
	ERR_INVALID_FLOAT_ID	NUMBER := 402;
	ERR_NO_CASE_DROP_INFO	NUMBER := 443;

        ORA_NORMAL              NUMBER := 0;

	DO_NOTHING		EXCEPTION;
	NO_LM_BATCH_FOUND	EXCEPTION;
	LM_BATCH_UPDATE_ERROR	EXCEPTION;
	INVALID_FLOAT_ID	EXCEPTION;

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

	PROCEDURE LoadPallet (	psTruck	las_pallet.truck%TYPE,
				psFloat	las_pallet.palletno%TYPE,
				psTrlr	las_truck.trailer%TYPE,
				pStatus IN OUT INTEGER);

	PROCEDURE UnloadPallet (psTruck	las_pallet.truck%TYPE,
				psFloat	las_pallet.palletno%TYPE,
				pStatus IN OUT INTEGER);

	PROCEDURE UnloadTruck  (psTruck	las_pallet.truck%TYPE,
				psFloat	las_pallet.palletno%TYPE,
				pStatus IN OUT INTEGER);

	PROCEDURE CreateISTART (pUserId		batch.user_id%TYPE,
				pBatchNo	batch.batch_no%TYPE,
				pError		OUT INTEGER);

	FUNCTION CompletePreviousBatch(pdtStop OUT DATE)
	RETURN NUMBER;

        PROCEDURE LoadCase (psTruck      las_pallet.truck%type,
                            psOrderSeq   las_case.order_seq%type,
                            pStatus      OUT INTEGER);
--                          pStatus      IN OUT INTEGER);

	FUNCTION CreateIRASGN (psBatch batch.batch_no%TYPE,
			pdtStartTime	batch.actl_start_time%TYPE DEFAULT NULL,
			psUser		batch.user_id%TYPE DEFAULT NULL)
	RETURN NUMBER;

	PROCEDURE sls_reassign (poiError    OUT INTEGER,
				poiLoaded   OUT NUMBER,
				posSelBatch OUT batch.batch_no%TYPE,
				psUser	    IN  batch.user_id%TYPE DEFAULT NULL,
				psBatch	    IN  batch.batch_no%TYPE DEFAULT NULL);

	PROCEDURE create_istop (
		psUser		IN  batch.user_id%TYPE,
		psBatch		IN  batch.batch_no%TYPE,
		poiStatus	OUT NUMBER,
		pdtStart	IN  batch.actl_start_time%TYPE DEFAULT NULL);

	PROCEDURE create_ilexit (
		psJobCode	IN  batch.jbcd_job_code%TYPE,
		psUser		IN  batch.user_id%TYPE,
		psBatch		IN  batch.batch_no%TYPE,
		pdtStartTime	IN  batch.actl_start_time%TYPE,
		poiStatus	OUT NUMBER,
		psExtra		IN  VARCHAR2 DEFAULT NULL);

	PROCEDURE exit_float_label (
		psUser	  IN  batch.user_id%TYPE,
		poiError  OUT NUMBER);

	PROCEDURE exit_float_label2 (
		psUser	  IN  batch.user_id%TYPE,
		poiError  OUT NUMBER);

	PROCEDURE exit_zone_label (
		psUser	  IN  batch.user_id%TYPE,
		psData1	  IN  VARCHAR2,
		psData2	  IN  VARCHAR2,
		poiError  OUT NUMBER);

	PROCEDURE exit_case_label (
		psUser	  IN  batch.user_id%TYPE,
		psData1	  IN  VARCHAR2,
		poiError  OUT NUMBER);
        
--     02/25/10  - 12554 - tsow0456  - 
--    Added for 212 Enh - SCE017 -  Begin    
--    Procedures for movestop related functions
    PROCEDURE LoadStop (psTruck      las_pallet.truck%type,
                        psOrderSeq   las_case.order_seq%type,
                        pStatus      OUT INTEGER);
                        
    PROCEDURE exit_stop (
              psUser      IN  batch.user_id%TYPE,
              psData1      IN  VARCHAR2,
              poiError  OUT NUMBER);
--     02/25/10  - 12554 - tsow0456  - 
--    Added for 212 Enh - SCE017 -  End  

END pl_sos_sls_lm;
/
SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY swms.pl_sos_sls_lm IS
	FUNCTION f_GetFloatNo (	psTruck las_pallet.truck%TYPE,
				psFloat las_pallet.palletno%TYPE)
	RETURN	INTEGER IS
		lFloatNo	INTEGER;
	BEGIN
		SELECT	float_no
		  INTO	lFloatNo
		  FROM	floats f
		 WHERE	truck_no = ltrim(rtrim(psTruck))
		   AND	float_seq = ltrim(rtrim(psFloat));
--		   AND  EXISTS (SELECT 1
--				FROM route
--				WHERE route_no = f.route_no
--				AND   truck_no = f.truck_no
--				AND   status <> 'CLS');

		pl_text_log.ins_msg('I', 'f_GetFloatNo',
			'Found Truck [' || psTruck || '] float[' || psFloat ||
			'] float#[' || TO_CHAR(lFloatNo) || ']', NULL, NULL);
		RETURN lFloatNo;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				pl_text_log.ins_msg('I', 'f_GetFloatNo',
					'GetFloatNo NO_DATA_FOUND Truck [' ||
					psTruck || '] float[' ||
					psFloat || ']', NULL, NULL);
				RAISE INVALID_FLOAT_ID;
	END;
  
        FUNCTION f_GetFloatNo_2 (psTruck  las_pallet.truck%type,
                                 psOrderSeq las_case.ORDER_SEQ%type)
        RETURN INTEGER IS
               lFloatNo     INTEGER;

        BEGIN
              select nvl(f.float_no, 0)
                into lFloatNo
                from floats f, float_detail fd
               where f.truck_no    = psTruck
                 and f.float_no    = fd.float_no
                 and f.pallet_pull IN ('N', 'B', 'Y')
                 and fd.order_seq  = psOrderSeq
                 and rownum = 1;

             pl_text_log.ins_msg('I', 'f_GetFloatNo_2',
                        'Found Truck [' || psTruck || '] OrderSeq[' || psOrderSeq ||
                        '] float#[' || TO_CHAR(lFloatNo) || ']', NULL, NULL);

		RETURN lFloatNo;
                EXCEPTION
                        WHEN OTHERS THEN
				lFloatNo := 0;
                                pl_text_log.ins_msg('I', 'f_GetFloatNo_2',
                                        'GetFloatNo NO_DATA_FOUND Truck [' ||
                                        psTruck || '] OrderSeq[' ||
                                        psOrderSeq || ']', NULL, NULL);
                                  RETURN lFloatNo; 
--                                RAISE INVALID_FLOAT_ID;
        END;


	PROCEDURE LoadCase (psTruck      las_pallet.truck%type,
                            psOrderSeq   las_case.order_seq%type,
                            pStatus      OUT INTEGER) IS

         sSupervisor    usr.SUPRVSR_USER_ID%type;
         lFloatNo       floats.float_no%type;
         lBatchNo       batch.batch_no%type;
         iError         number := 0;
         seqnumber      number := 0;
         exist_case     number := 0;
	 dtStop		DATE := NULL;
	 sJobCode	batch.jbcd_job_code%TYPE := NULL;
	 iCube		NUMBER := 0.0;
	 iWeight	NUMBER := 0.0;
	 iStatus	NUMBER := 0;

         BEGIN
	   pStatus := 0;

	   BEGIN
	     SELECT NVL (REPLACE (suprvsr_user_id, 'OPS$', ''), 'NOMGR')
	     INTO sSupervisor
	     FROM usr
	     WHERE REPLACE (user_id, 'OPS$', '') = REPLACE (USER, 'OPS$', '');
	   EXCEPTION
	     WHEN OTHERS THEN
	       sSupervisor := 'NOMGR';
	   END;

	   lFloatNo := f_GetFloatNo_2 (psTruck, psOrderSeq);

	   IF ((lFloatNo = 0) OR (lFloatNo IS NULL)) THEN
	     pStatus := ERR_NO_CASE_DROP_INFO;
	     RETURN;
	   END IF;

	   CreateISTART(REPLACE(USER, 'OPS$', ''),
		'L' || TO_CHAR(lFloatNo), iError);
	   dbms_output.put_line(' Inside load case = '||
		' Float number = '||lFloatNo||' OrderSeq = '||
		psOrderSeq ||' Truck = '|| psTruck);
	   pl_text_log.ins_msg('I', 'LoadCase',
		'After CreateISTART Truck [' || psTruck ||
		'] OrderSeq[' || psOrderSeq ||
		'] float#[' || TO_CHAR(lFloatNo) || '] error[' ||
		TO_CHAR(iError) || ']', NULL, NULL);
	   iStatus := CompletePreviousBatch(dtStop);
	   IF iStatus <> 0 THEN
		DBMS_OUTPUT.PUT_LINE('LoadCase: CompletePreviousBatch error[' ||  TO_CHAR(iStatus) || ']');
		pl_text_log.ins_msg('E', 'LoadCase',
			'CompletePreviousBatch error[' || TO_CHAR(iStatus) ||
			']', NULL, NULL);
		pStatus := ERR_LM_SCHED_NOT_FOUND;
		RETURN;
	   END IF;

	   BEGIN
	     SELECT m.load_job_code,
		SUM(d.cube / DECODE(d.uom, 2, (d.qty_alloc / p.spc),
					d.qty_alloc)),
		SUM(DECODE(d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE(uom,
				2, d.qty_alloc * (p.g_weight / NVL(p.spc, 1)),
				NULL, d.qty_alloc * (p.g_weight / NVL(p.spc,1)),
				0)))
	     INTO sJobCode, iCube, iWeight
	     FROM sel_method m, floats f, float_detail d, route r, pm p
	     WHERE m.method_id = r.method_id
	     AND   m.group_no = f.group_no
	     AND   f.float_no = d.float_no
	     AND   d.order_seq = psOrderSeq
	     AND   f.pallet_pull IN ('B', 'N', 'Y')
	     AND   f.route_no = r.route_no
	     AND   d.prod_id = p.prod_id
	     AND   d.cust_pref_vendor = p.cust_pref_vendor
	     GROUP BY m.load_job_code;
	   EXCEPTION
	     WHEN OTHERS THEN
	       sJobCode := NULL;
	       iCube := 0.0;
	       iWeight := 0.0;
	   END;

	   BEGIN
	     INSERT INTO batch
	       (batch_no, batch_date, status, user_id, user_supervsr_id,
		jbcd_job_code, ref_no, actl_start_time, goal_time, target_time,
		kvi_cube, kvi_wt, kvi_no_piece, kvi_no_case, kvi_no_split,
		kvi_no_merge, kvi_no_item, kvi_no_stop,
		kvi_no_pallet, kvi_no_pallet_piece, kvi_no_cart,
		kvi_no_cart_piece, total_count, total_pallet, total_piece,
		cmt)
	       VALUES (
		'LC' || TO_CHAR(seq1.nextval), TRUNC(SYSDATE), 'A',
		REPLACE(USER, 'OPS$', ''), sSupervisor,
		sJobCode, psOrderSeq, NVL(dtStop, SYSDATE),
		0, 0,
		iCube, iWeight, 1 , 1, 0,
		0, 1, 1,
		0, 0, 0,
		0, 1, 0, 1,
		TO_CHAR(lFloatNo));

	     IF (SQL%ROWCOUNT = 0) THEN
	       RAISE NO_LM_BATCH_FOUND;
	     END IF;

	   EXCEPTION
	     WHEN NO_DATA_FOUND THEN
	       pStatus := ERR_NO_LM_BATCH;
	     WHEN OTHERS THEN
	       dbms_output.put_line(' sqlcode = '|| to_char(sqlcode));
	       pl_text_log.ins_msg('I', 'LoadCase', ' Error code  = '||
		to_char(sqlcode), NULL, NULL);
	       pStatus := ERR_LM_BATCH_UPD_FAIL;
	   END;

        END LoadCase;

       FUNCTION  InsertBatch (psFloat_No       floats.float_no%TYPE,
                                psBatch_No       batch.batch_no%TYPE,
                                psSupervisor     usr.suprvsr_user_id%type,
                                psUnloadSyspar   VARCHAR2,
				pdtStop		DATE)
       RETURN INTEGER IS
	sFloatSeq	floats.float_seq%TYPE := NULL;
       BEGIN
	BEGIN
		SELECT float_seq INTO sFloatSeq
		FROM floats
		WHERE float_no = psFloat_No
		AND   pallet_pull IN ('Y', 'N', 'B')
		AND   ROWNUM = 1;
	EXCEPTION
		WHEN OTHERS THEN
			sFloatSeq := NULL;
	END;
                  INSERT  INTO batch
                               (batch_no, batch_date, status, user_id, user_supervsr_id,
                               jbcd_job_code, ref_no,actl_start_time,goal_time,target_time,
                               kvi_cube, kvi_wt,
                               kvi_no_piece, kvi_no_case, kvi_no_split,
                               kvi_no_merge, kvi_no_item, kvi_no_stop,
                               kvi_no_pallet, kvi_no_pallet_piece, kvi_no_cart,
                               kvi_no_cart_piece, total_count,total_pallet,
				total_piece, cmt )
                  SELECT psBatch_No,
                               TRUNC (SYSDATE), 'A', REPLACE (USER, 'OPS$', ''), psSupervisor,
                               jbcd_job_code,  ref_no, NVL(pdtStop, SYSDATE),
                               DECODE (psUnloadSyspar, 'N', 0, goal_time),
                               DECODE (psUnloadSyspar, 'N', 0, target_time),
                               kvi_cube, kvi_wt,
                               kvi_no_piece, kvi_no_case, kvi_no_split,
                               kvi_no_merge, kvi_no_item, kvi_no_stop,
                               kvi_no_pallet, kvi_no_pallet_piece, kvi_no_cart,
                               kvi_no_cart_piece,total_count,total_pallet,
				total_piece, sFloatSeq
                    FROM  batch
                   WHERE  batch_no = 'L' || psFloat_No;

                   IF (SQL%ROWCOUNT = 0) THEN
                          RETURN   ERR_NO_LM_BATCH;
                   ELSE
                          RETURN ORA_NORMAL;
                   END IF;

       EXCEPTION
             WHEN NO_DATA_FOUND THEN
                  RETURN   ERR_NO_LM_BATCH;
             WHEN OTHERS THEN
                  RETURN  ERR_LM_BATCH_UPD_FAIL;

       END InsertBatch;

       PROCEDURE LoadPallet (	psTruck	las_pallet.truck%TYPE,
				psFloat	las_pallet.palletno%TYPE,
				psTrlr	las_truck.trailer%TYPE,
				pStatus IN OUT INTEGER) IS
		sLMActive	VARCHAR2 (1);
		sSLSActive	VARCHAR2 (1);
		sLDBatchByFltNo	VARCHAR2 (1);
		lFloatNo	INTEGER := 0;
		lRouteNo	route.route_no%TYPE;
		iError		NUMBER := 0;
                sFound          NUMBER := 0;
                sSupervisor     usr.suprvsr_user_id%TYPE;
                sBatchR         batch.Batch_no%type;
		sBatch		batch.batch_no%TYPE := NULL;
		dtStop		DATE := NULL;
                sUnloadSyspar   VARCHAR2 (1);
		iStatus		NUMBER := 0;
		sBStatus	batch.status%TYPE := NULL;
		sBLckStatus	batch.status%TYPE := NULL;
	BEGIN
		DBMS_OUTPUT.PUT_LINE('LoadPallet truck[' || psTruck ||
			'], float[' || psFloat || '] for user [' ||
			REPLACE(USER, 'OPS$', '') || ']');
		pl_text_log.ins_msg('I', 'LoadPallet',
			'Truck [' || psTruck || '] float[' || psFloat ||
			']', NULL, NULL);
		sLMActive := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');
		IF (sLMActive = 'N') THEN
			RAISE DO_NOTHING;
		END IF;

		sSLSActive := pl_common.f_get_syspar('LAS_ACTIVE', 'N');
		IF (sSLSActive = 'N') THEN
			RAISE DO_NOTHING;
		END IF;

                sUnloadSyspar := pl_common.f_get_syspar(
                        'LAS_CALC_UNLOAD_GOAL_TIME', 'N');

                dbms_output.put_Line(' Unload Syspar = '||sUnloadSyspar);

		sLDBatchByFltNo := pl_common.f_get_syspar(
			'LD_BAT_BY_FLT_NO', 'N');
		lFloatNo := f_GetFloatNo (psTruck, psFloat);
		DBMS_OUTPUT.PUT_LINE('Active: ' || sLMActive || '/' ||
			sSLSActive || ', LDBatchByFl: ' || sLDBatchByFltNo);
		pl_text_log.ins_msg('I', 'LoadPallet',
			'Truck [' || psTruck || '] float[' || psFloat ||
			'] float#[' || TO_CHAR(lFloatNo) ||
			'] LD_BAT_BY_FLT_NO[' || sLDBatchByFltNo || ']',
			NULL, NULL);
		BEGIN
			SELECT	route_no
			  INTO	lRouteNo
			  FROM	floats
			 WHERE	float_no = lFloatNo;
		END;

		DBMS_OUTPUT.PUT_LINE('route [' || lRouteNo || '] status[' ||
			TO_CHAR(SQLCODE) || ']');

		BEGIN
	       	      SELECT	NVL (REPLACE (suprvsr_user_id, 'OPS$', ''), 'NOMGR')
		        INTO	sSupervisor
		        FROM	usr
	  	       WHERE	REPLACE (user_id, 'OPS$', '') = REPLACE (USER, 'OPS$', '');
	        EXCEPTION
		      WHEN OTHERS THEN
			    sSupervisor := 'NOMGR';
                END;

		CreateISTART(REPLACE(USER, 'OPS$', ''),
			'L' || TO_CHAR(lFloatNo), iError);

		pl_text_log.ins_msg('I', 'LoadPallet',
			'After CreateISTART Truck [' || psTruck ||
			'] float[' || psFloat ||
			'] float#[' || TO_CHAR(lFloatNo) || '] error[' ||
			TO_CHAR(iError) || ']', NULL, NULL);

		IF iError = 0 THEN
			DBMS_OUTPUT.PUT_LINE('ISTART Created');
		ELSE
			DBMS_OUTPUT.PUT_LINE('ISTART NOT Created: ' ||
				TO_CHAR(iError));
		END IF;

		IF (sLDBatchByFltNo = 'Y') THEN
		BEGIN
			DBMS_OUTPUT.PUT_LINE('Ready to complete prev batch');
			iStatus := CompletePreviousBatch(dtStop);
			IF iStatus <> 0 THEN
				DBMS_OUTPUT.PUT_LINE('LoadPallet: CompletePreviousBatch error[' || TO_CHAR(iStatus) || ']');
				pl_text_log.ins_msg('E', 'LoadPallet',
					'CompletePreviousBatch error[' || TO_CHAR(iStatus) ||
					']', NULL, NULL);
				pStatus := ERR_LM_SCHED_NOT_FOUND;
				RETURN;
			END IF;
			DBMS_OUTPUT.PUT_LINE('Completed prev batch');
			pl_text_log.ins_msg('I', 'LoadPallet',
				'Complete previous batch Truck [' || psTruck ||
				'] float[' || psFloat ||
				']', NULL, NULL);
				
				-- CRQ#42225 avij3336  - Added the below query to fetch the stop time of last completed batch
				                    IF  dtStop is null THEN
                        BEGIN 
                            SELECT b.actl_stop_time
                            INTO dtStop
                            FROM batch b
                            WHERE b.user_id = REPLACE (USER, 'OPS$', '')
                            AND b.status = 'C'
                            AND b.actl_stop_time =
                                (SELECT MAX (actl_stop_time)
                                    FROM batch b2
                                    WHERE b2.user_id = REPLACE (USER, 'OPS$', '')
                                    AND b2.status = 'C');
                        EXCEPTION
                        WHEN OTHERS THEN
                        dbms_output.put_line ('there is no completed batch found for the user');                   
                        END;
                    END IF; 

                        BEGIN
                             SELECT batch_no, status
                               into sBatchR, sBStatus
                               from batch
                              where batch_no like 'L'||lFloatNo||'%'
                                and nvl(actl_start_time,sysdate) = (select max(nvl(actl_start_time,sysdate))
                                                                      from batch
                                                                     where batch_no like 'L'||lFloatNo||'%');
                        dbms_output.put_line('Selected batch[' || sBatchR ||
				'] status[' || sBStatus || ']');

                        pl_text_log.ins_msg('I', 'LoadPallet',
                                          'Select Latest Batch[' || sBatchR ||
                                          '] status[' || sBStatus || ']',
					NULL, NULL);
                       EXCEPTION
                             when others then
                                  pStatus := ERR_NO_LM_BATCH;
                                  dbms_output.put_line(' NO Data Found Load Pallet  batch = '|| sBatchR);
			          pl_text_log.ins_msg('I', 'LoadPallet',
				          'When Others : Select Latest Batch FloatNumber [' || sBatchR ||
				          ']' , NULL, NULL);
				  sBatch := 'L' || lFloatNo;
				  RAISE NO_LM_BATCH_FOUND;
                       END;


                       IF ((sBatchR NOT LIKE 'L' || lFloatNo || 'U%') AND 
			   (sBatchR NOT LIKE 'L' || lFloatNo || 'R%') AND
			   (sBStatus <> 'C')) THEN
                          dbms_output.put_line(' In the IF  part batch has U or R'|| sBatchR); 
			  BEGIN
			    SELECT status INTO sBLckStatus
			    FROM batch
			    WHERE   batch_no like 'L' || lFloatNo
			    AND   user_id IS NULL
			    AND   status = 'F'
			    FOR UPDATE OF status NOWAIT;
			  EXCEPTION
			    WHEN OTHERS THEN
				RAISE LM_BATCH_UPDATE_ERROR;
			  END;
                            
                          BEGIN
			    UPDATE   batch
			       SET   status = 'A',
			       	     user_id = REPLACE (USER, 'OPS$', ''),
				     actl_start_time = NVL(dtStop, SYSDATE),
				     user_supervsr_id = sSupervisor
			     WHERE   batch_no like 'L' || lFloatNo
			       AND   status = 'F'
			       AND   user_id IS NULL;

			    DBMS_OUTPUT.PUT_LINE('Update BATCH to A for ' ||
				'L' || lFloatNo || '%, #rows[' ||
				TO_CHAR(SQL%ROWCOUNT) || ']');
			    pl_text_log.ins_msg('I', 'LoadPallet',
				'Activate batch Truck [' || psTruck ||
				'] float[' || psFloat || '] #rows[' ||
				TO_CHAR(SQL%ROWCOUNT) || ']',
				NULL, NULL);
			    IF (SQL%ROWCOUNT = 0) THEN
				sBatch := 'L' || lFloatNo;
				RAISE	NO_LM_BATCH_FOUND;
                            ELSE 
                                pStatus := 0;  
			    END IF;
                          END;

                       ELSE
                          dbms_output.put_line(' In the Else part batch has U or R'|| sBatchR); 
                          BEGIN
                              select batch_no
                                into sBatchR
                                from batch 
                               where batch_no like 'L'||lFloatNo||'R%'
                                 and nvl(actl_start_time,sysdate) = (select max(nvl(actl_start_time,sysdate))
                                                                       from batch 
                                                                      where batch_no like 'L'||lFloatNo||'R%');
                              sFound := 1;
                          EXCEPTION
                              when others then
                                   sBatchR := 'L'||to_char(lFloatNo)||'R1';
                                   pStatus := InsertBatch(lFloatNo, sBatchR, sSupervisor, sUnloadSyspar, dtStop);
                                   sFound := 0;
                          END;

                          if sFound = 1 THEN
                            sBatchR := substr(sBatchR, 1, instr(sBatchR ,'R') -1)||'R'||
                                       to_char(to_number(substr( sBatchR, instr(sBatchR,'R') + 1)) + 1);
                            pStatus := InsertBatch(lFloatNo, sBatchR, sSupervisor, sUnloadSyspar, dtStop);
                          END if;
                       END IF;
        

--			INSERT	INTO sls_load_detail
--				(batch_no, route_no, float_seq, trailer_no, trailer_zone)
--			VALUES	('L' || lFloatNo, lRouteNo, psFloat, PsTrlr, psZone);
--			EXCEPTION
--				WHEN NO_DATA_FOUND THEN
--					RAISE	NO_LM_BATCH_FOUND;
--				WHEN OTHERS THEN
--					pStatus := SQLCODE;
--					RAISE LM_BATCH_UPDATE_ERROR;

		END;
		END IF;
		EXCEPTION
			WHEN DO_NOTHING THEN
				DBMS_OUTPUT.PUT_LINE('Exception: Do nothing');
				pl_text_log.ins_msg('I', 'LoadPallet',
					'In DO_NOTHING Truck [' || psTruck ||
					'] float[' || psFloat || ']',
					NULL, NULL);
				pStatus := 0;
			WHEN NO_LM_BATCH_FOUND THEN
				DBMS_OUTPUT.PUT_LINE('Exception: Batch 1403');
				pStatus := ERR_NO_LM_BATCH;
				pl_text_log.ins_msg('I', 'LoadPallet',
					'In NO_LM_BATCH_FOUND Truck [' ||
					psTruck || '] float[' || psFloat ||
					']', NULL, NULL);
				-- CRQ#42225 avij3336 calling 'create_ilexit' with the stop time of last completed batch if not with the sysdate
                create_ilexit('ILBNFD',
                    REPLACE(USER, 'OPS$', ''),
                    sBatch,
                    NVL (dtStop, SYSDATE), iStatus);

				IF iStatus = 0 THEN
					pStatus := ERR_NO_LM_BATCH;
				ELSE
					pStatus := iStatus;
				END IF;
			WHEN LM_BATCH_UPDATE_ERROR THEN
				DBMS_OUTPUT.PUT_LINE('Exception: Batch upd fail');
				pStatus := ERR_LM_BATCH_UPD_FAIL;
				pl_text_log.ins_msg('I', 'LoadPallet',
					'In LM_BATCH_UPDATE_ERROR Truck [' ||
					psTruck || '] float[' || psFloat ||
					']', NULL, NULL);
			WHEN INVALID_FLOAT_ID THEN
				DBMS_OUTPUT.PUT_LINE('Exception: Invalid float');
				pStatus := ERR_INVALID_FLOAT_ID;
				pl_text_log.ins_msg('I', 'LoadPallet',
					'In INVALID_FLOAT_ID Truck [' ||
					psTruck || '] float[' || psFloat ||
					']', NULL, NULL);
	END LoadPallet;

        PROCEDURE UnloadTruck (psTruck las_pallet.truck%TYPE,
                                psFloat las_pallet.palletno%TYPE,
                                pStatus IN OUT INTEGER) IS

		lFloatNo	INTEGER := 0;
		sLDBatchByFltNo	VARCHAR2 (1);
		iError		NUMBER := 0;
                sSupervisor     usr.SUPRVSR_USER_ID%TYPE;
                sLaborGroup     usr.LGRP_LBR_GRP%TYPE;
                lDuration       batch.actl_time_spent%TYPE;
		dtStop		DATE := NULL;
		iStatus		NUMBER := 0;
        BEGIN

		sLDBatchByFltNo := pl_common.f_get_syspar(
			'LD_BAT_BY_FLT_NO', 'N');

		lFloatNo := f_GetFloatNo (psTruck, psFloat);
		pl_text_log.ins_msg('I', 'UnloadTruck',
			'In After getfloatno [' ||
			psTruck || '] float[' || psFloat ||
			']', NULL, NULL);
                dbms_output.put_line(' Float number = '|| to_char(lFloatNo) ); 
 
                BEGIN
                     SELECT  NVL (REPLACE (suprvsr_user_id, 'OPS$', ''), 'NOMGR'),
                             NVL (lgrp_lbr_grp, 'NG')
                       INTO  sSupervisor, sLaborGroup
                       FROM  usr
                      WHERE  REPLACE (user_id, 'OPS$', '') = REPLACE (USER, 'OPS$', '');
                EXCEPTION
                      WHEN OTHERS THEN
                           BEGIN
                                 sSupervisor := 'NOMGR';
                                 sLaborGroup := 'NG';
                           END;
                END;

		CreateISTART(REPLACE(USER, 'OPS$', ''),
			'L' || TO_CHAR(lFloatNo), iError);
		IF iError = 0 THEN
			DBMS_OUTPUT.PUT_LINE('IUNLOAD Created');
		ELSE
			DBMS_OUTPUT.PUT_LINE('IUNLOAD NOT Created: ' ||
				TO_CHAR(iError));
		END IF;
              
		IF (sLDBatchByFltNo = 'Y') THEN
			iStatus := CompletePreviousBatch(dtStop);
			IF iStatus <> 0 THEN
				DBMS_OUTPUT.PUT_LINE('UnloadTruck: CompletePreviousBatch error[' || TO_CHAR(iStatus) || ']');
				pl_text_log.ins_msg('E', 'UnloadTruck',
					'CompletePreviousBatch error[' || TO_CHAR(iStatus) ||
					']', NULL, NULL);
				pStatus := ERR_LM_SCHED_NOT_FOUND;
				RETURN;
			END IF;
		        pl_text_log.ins_msg('I', 'UnloadTruck',
			        ' After CompletePreviousBatch [' ||
			        sLDBatchByFltNo || '] float[' || psFloat ||
			        ']', NULL, NULL);

                    BEGIN
                        SELECT  /*+ RULE +*/ NVL ( st.start_dur, 0 )
                          INTO  lDuration
                          FROM  sched_type st, sched s, usr u, batch b,
                                job_code jc
                         WHERE  st.sctp_sched_type = s.sched_type
                           AND  s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp
                           AND  s.sched_jbcl_job_class = jc.jbcl_job_class
                           AND  s.sched_actv_flag = 'Y'
                           AND  u.user_id = REPLACE(USER, 'OPS$', '')
                           AND  jc.jbcd_job_code = b.jbcd_job_code
                           AND  b.batch_no = 'L' || lFloatNo;
                        EXCEPTION
                                WHEN OTHERS THEN
                                        lDuration := 0;
                    END;

                     DBMS_OUTPUT.PUT_LINE('Duration ' || TO_CHAR(lDuration) );
		        pl_text_log.ins_msg('I', 'UnloadTruck',
			        ' Before Inserting to BATCH [' ||
			        lDuration || '] float[' || psFloat ||
			        ']', NULL, NULL);

		    BEGIN
		        INSERT INTO batch (batch_no, batch_date, jbcd_job_code,
			                   status, actl_start_time, actl_stop_time, user_id,
			                   user_supervsr_id,actl_time_spent,kvi_doc_time,
			                   kvi_cube, kvi_wt, kvi_no_piece,
			                   kvi_no_pallet, kvi_no_item,
			                   kvi_no_data_capture, kvi_no_po,
			                   kvi_no_stop, kvi_no_zone, kvi_no_loc,
			                   kvi_no_case, kvi_no_split,
			                   kvi_no_merge, kvi_no_aisle,
			                   kvi_no_drop, kvi_order_time,
			                   no_lunches, no_breaks, damage, ref_no)
                                   VALUES
                                           ('I' || TO_CHAR (seq1.NEXTVAL ), TRUNC (SYSDATE),
                                           'ILULTK',
                                           'A', (NVL(dtStop, SYSDATE) - (NVL (lDuration, 0) / 1440)), NULL,
                                           REPLACE (USER, 'OPS$', ''), sSupervisor, lDuration, 
                                           0, 0, 0, 0, 0, 0, 0, 0, 0,
                                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
						psTruck);
                    pStatus := 0;
                    EXCEPTION
                        WHEN OTHERS THEN
                                DBMS_OUTPUT.PUT_LINE('Insert BATCH Error: ' ||
                                        TO_CHAR(SQLCODE));
		                pl_text_log.ins_msg('I', 'UnloadTruck',
			        ' OTHERS [' ||
			        to_char(sqlcode) || '] float[' || psFloat ||
			        ']', NULL, NULL);
                                pStatus := SQLCODE;

                    END;
		END IF;

        END UnloadTruck;

	PROCEDURE UnloadPallet (psTruck	las_pallet.truck%TYPE,
				psFloat	las_pallet.palletno%TYPE,
				pStatus IN OUT INTEGER) IS
		sLMActive	VARCHAR2 (1);
		sUnloadSyspar	VARCHAR2 (1);
		sSLSActive	VARCHAR2 (1);
		sSOSActive	VARCHAR2 (1);
		sLDBatchByFltNo	VARCHAR2 (1);
		sSupervisor	usr.suprvsr_user_id%TYPE;
		sLaborGroup	usr.lgrp_lbr_grp%TYPE;
		NextSeq		INTEGER := 0;
		lFloatNo	INTEGER := 0;
		iError		NUMBER := 0;
                sBatchU         batch.batch_no%TYPE;
                sStatus         INTEGER := 0;
                sFound          INTEGER := 0;
		dtStop		DATE := NULL;
                iStatus         NUMBER := 0;
	BEGIN
		sLMActive := pl_common.f_get_syspar('LBR_MGMT_FLAG', 'N');
		IF (sLMActive = 'N') THEN
			RAISE DO_NOTHING;
		END IF;

		sSLSActive := pl_common.f_get_syspar('LAS_ACTIVE', 'N');
		IF (sSLSActive = 'N') THEN
			RAISE DO_NOTHING;
		END IF;
		sUnloadSyspar := pl_common.f_get_syspar(
			'LAS_CALC_UNLOAD_GOAL_TIME', 'N');
		sLDBatchByFltNo := pl_common.f_get_syspar(
			'LD_BAT_BY_FLT_NO', 'N');
		BEGIN
			SELECT	NVL (REPLACE (suprvsr_user_id, 'OPS$', ''), 'NOMGR'),
				NVL (lgrp_lbr_grp, 'NG')
			  INTO	sSupervisor, sLaborGroup
			  FROM	usr
			 WHERE	REPLACE (user_id, 'OPS$', '') = REPLACE (USER, 'OPS$', '');
			EXCEPTION
				WHEN OTHERS THEN
				BEGIN
					sSupervisor := 'NOMGR';
					sLaborGroup := 'NG';
				END;
		END;
		lFloatNo := f_GetFloatNo (psTruck, psFloat);
                dbms_output.put_line(' Float number = '|| to_char(lFloatNo) ); 

		CreateISTART(REPLACE(USER, 'OPS$', ''),
			'L' || TO_CHAR(lFloatNo), iError);
		IF iError = 0 THEN
			DBMS_OUTPUT.PUT_LINE('ISTART Created');
		ELSE
			DBMS_OUTPUT.PUT_LINE('ISTART NOT Created: ' ||
				TO_CHAR(iError));
		END IF;
		IF (sLDBatchByFltNo = 'Y') THEN
		BEGIN
			iStatus := CompletePreviousBatch(dtStop);
			IF iStatus <> 0 THEN
				DBMS_OUTPUT.PUT_LINE('UnloadPallet: CompletePreviousBatch error[' || TO_CHAR(iStatus) || ']');
				pl_text_log.ins_msg('E', 'UnloadPallet',
					'CompletePreviousBatch error[' || TO_CHAR(iStatus) ||
					']', NULL, NULL);
				pStatus := ERR_LM_SCHED_NOT_FOUND;
				RETURN;
			END IF;
                        BEGIN
                             select batch_no
                               into sBatchU
                               from batch b
                              where batch_no like 'L'||lFloatno||'U%'
                                and nvl(actl_start_time, sysdate)  = (select max(nvl(actl_start_time, sysdate))
                                                                        from batch
                                                                       where batch_no like 'L'||lFloatno||'U%');
                              sFound := 1;

                              dbms_output.put_Line(' BATCH U inside select '|| sBatchU);
                        EXCEPTION
                            WHEN OTHERS THEN
                                 sBatchU := 'L'|| to_char(lFloatno) ||'U1';

                              dbms_output.put_Line(' BATCH U No Data Found creating new batch = '|| sBatchU);

                                 pStatus := InsertBatch(lFloatno, sBatchU, sSupervisor,sUnloadSyspar, dtStop ) ; 
                   
                              dbms_output.put_Line(' pSTatus first select to sBatchU = '|| pStatus);
--                               pStatus := sStatus;
                                 sFound := 0;
                        END; 

                        IF (sFound = 1) THEN
                            sBatchU := substr(sBatchU, 1, instr(sBatchU ,'U') -1)||'U'||
                                       to_char(to_number(substr( sBatchU, instr(sBatchU,'U') + 1)) + 1);

                              dbms_output.put_Line(' If SFOUND = 1  new batch = '|| sBatchU);

                            pStatus := InsertBatch(lFloatno, sBatchU, sSupervisor, sUnloadSyspar, dtStop);

                              dbms_output.put_Line(' pSTatus 2nd  select to sBatchU = '|| pStatus);

/*                          pStatus := sStatus;  */
                        END IF;

--			BEGIN
--				DELETE	sls_load_detail
--				 WHERE	batch_no = 'L' || lFloatNo;
--			END;
	
		END;
		END IF;
		EXCEPTION
			WHEN DO_NOTHING THEN
				pStatus := 0;
			WHEN NO_LM_BATCH_FOUND THEN
				pStatus := ERR_NO_LM_BATCH;
			WHEN LM_BATCH_UPDATE_ERROR THEN
				pStatus := ERR_LM_BATCH_UPD_FAIL;
			WHEN INVALID_FLOAT_ID THEN
				pStatus := ERR_INVALID_FLOAT_ID;
	END UnloadPallet;

	PROCEDURE CreateISTART (pUserId		batch.user_id%TYPE,
				pBatchNo	batch.batch_no%TYPE,
				pError		OUT INTEGER) IS
		lSuperId	usr.suprvsr_user_id%TYPE;
		lDuration	NUMBER;
		SKIP_REST	EXCEPTION;
		lTemp		batch.batch_no%TYPE;
		dtStartTime	batch.actl_start_time%TYPE := NULL;
	BEGIN
		pError := 0;
		BEGIN
			SELECT	batch_no, actl_start_time
			  INTO	lTemp, dtStartTime
			  FROM	batch b1
			 WHERE	user_id = pUserId
			   AND	jbcd_job_code = 'ISTART'
			   AND	actl_start_time = 
					(SELECT MAX(actl_start_time)
					 FROM batch
					 WHERE jbcd_job_code = b1.jbcd_job_code
					 AND   user_id = b1.user_id);
/*			pl_log.ins_msg('WARN', 'CreateISTART',
				'U:' || pUserId || ', b: ' || lTemp ||
				', D: ' ||
				TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
				NULL, NULL);*/

			DBMS_OUTPUT.PUT_LINE('Get previous ISTART: ' ||
				lTemp || '-(start)' ||
				TO_CHAR(dtStartTime, 'MM/DD/RR HH24:MI:SS'));
--			IF TRUNC(dtStartTime) = TRUNC(SYSDATE) THEN
				RAISE SKIP_REST;
--			END IF;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
/*					pl_log.ins_msg('WARN', 'CreateISTART',
					'1403- U:' || pUserId || ', D: ' ||
					TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
					NULL, NULL);*/
					DBMS_OUTPUT.PUT_LINE('No ISTART found');
				WHEN SKIP_REST THEN
/*					pl_log.ins_msg('WARN', 'CreateISTART',
					'SKIP_REST- U:' || pUserId || ', D: ' ||
					TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
					NULL, NULL);*/
					lTemp := -1;
					DBMS_OUTPUT.PUT_LINE(
					'Get previous ISTART SKIP_REST');
					RETURN;
				WHEN TOO_MANY_ROWS THEN
/*					pl_log.ins_msg('WARN', 'CreateISTART',
					'TOO_MANY_ROWS- U:' || pUserId ||
					', D: ' ||
					TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
					NULL, NULL);*/
					DBMS_OUTPUT.PUT_LINE(
					'Get previous ISTART TOO_MANY_ROWS');
					RAISE SKIP_REST;
				WHEN OTHERS THEN
/*					pl_log.ins_msg('WARN', 'CreateISTART',
					'OTHERS- U:' || pUserId ||
					', E: ' || TO_CHAR(SQLCODE) ||
					', D: ' ||
					TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
					NULL, NULL);*/
					pError := SQLCODE;
					DBMS_OUTPUT.PUT_LINE(
					'Get previous ISTART Error: ' ||
					TO_CHAR(SQLCODE));
					RAISE SKIP_REST;
		END;
/*		IF (lTemp = -1) THEN
			RAISE SKIP_REST;
		END IF;
*/
		BEGIN
			SELECT	suprvsr_user_id
			  INTO	lSuperId
			  FROM	usr
			 WHERE	user_id = 'OPS$' || pUserId;
			EXCEPTION
				WHEN OTHERS THEN NULL;
		END;
		DBMS_OUTPUT.PUT_LINE('Supervisor ' || lSuperId ||
			' for user ' || pUserId || ' bat[' || pBatchNo || ']');
		BEGIN
			SELECT	/*+ RULE +*/ NVL ( st.start_dur, 0 )
			  INTO	lDuration
			  FROM	sched_type st, sched s, usr u, batch b,
				job_code jc
			 WHERE	st.sctp_sched_type = s.sched_type
			   AND	s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp
			   AND	s.sched_jbcl_job_class = jc.jbcl_job_class
			   AND	s.sched_actv_flag = 'Y'
			   AND	u.user_id = 'OPS$' || pUserId
			   AND	jc.jbcd_job_code = b.jbcd_job_code
			   AND	b.batch_no = pBatchNo;
			EXCEPTION
				WHEN OTHERS THEN
					lDuration := 0;
		END;
		DBMS_OUTPUT.PUT_LINE('Duration ' || TO_CHAR(lDuration) ||
			' for user ' || pUserId);
		INSERT INTO batch (batch_no, batch_date, jbcd_job_code,
			status, actl_start_time, actl_stop_time, user_id,
			user_supervsr_id,actl_time_spent,kvi_doc_time,
			kvi_cube, kvi_wt, kvi_no_piece,
			kvi_no_pallet, kvi_no_item,
			kvi_no_data_capture, kvi_no_po,
			kvi_no_stop, kvi_no_zone, kvi_no_loc,
			kvi_no_case, kvi_no_split,
			kvi_no_merge, kvi_no_aisle,
			kvi_no_drop, kvi_order_time,
			no_lunches, no_breaks, damage)
		VALUES
			('I' || TO_CHAR (seq1.NEXTVAL ), TRUNC (SYSDATE),
			'ISTART',
			'C', (SYSDATE - (NVL (lDuration, 0) / 1440)), SYSDATE,
			pUserId, lSuperId, lDuration, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
		EXCEPTION
			WHEN SKIP_REST THEN
				DBMS_OUTPUT.PUT_LINE('Insert BATCH SKIP_REST');
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE('Insert BATCH Error: ' ||
					TO_CHAR(SQLCODE));
				pError := SQLCODE;
	END CreateISTART;

	FUNCTION CompletePreviousBatch (pdtStop OUT DATE)
	RETURN NUMBER IS
		lBatchNo	batch.batch_no%TYPE;
		lTimeSpent	batch.actl_time_spent%TYPE;
		lStopTime	DATE := NULL;
	BEGIN
		pdtStop := NULL;		

		SELECT	batch_no
		  INTO	lBatchNo
		  FROM	batch
		 WHERE	user_id = REPLACE (USER, 'OPS$', '')
		   AND	status = 'A';

                dbms_output.put_line(' l batchno = '|| lBatchNo);

		BEGIN
			pl_lm1.create_schedule (lBatchNo, SYSDATE, lTimeSpent);
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE('CompletePreviousBatch error[' || TO_CHAR(SQLCODE) || ']');				
				RETURN ERR_LM_SCHED_NOT_FOUND;
		END;

                if lBatchNo is not null then

		     SELECT actl_stop_time INTO lStopTime
		     FROM batch
		     WHERE batch_no = lBatchNo;
		     pdtStop := lStopTime;
                end if;

		RETURN ORA_NORMAL;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			DBMS_OUTPUT.PUT_LINE('No previous active batch for user');
			RETURN ORA_NORMAL;
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				': Error getting previous active batch for user'||
                               ' sql errm '|| sqlerrm);
			RETURN SQLCODE;
	END CompletePreviousBatch;

	FUNCTION CreateIRASGN (psBatch	batch.batch_no%TYPE,
			pdtStartTime	batch.actl_start_time%TYPE DEFAULT NULL,
			psUser		batch.user_id%TYPE DEFAULT NULL)
	RETURN NUMBER IS
	BEGIN
		INSERT INTO batch (
			batch_no, batch_date, jbcd_job_code,
			status, ref_no, actl_start_time, actl_stop_time,
			actl_time_spent, user_id,
			user_supervsr_ID,
			kvi_doc_time, kvi_cube, kvi_wt, kvi_no_piece,
			kvi_no_pallet, kvi_no_item, kvi_no_data_capture,
			kvi_no_po, kvi_no_stop, kvi_no_zone, kvi_no_loc,
			kvi_no_case, kvi_no_split, kvi_no_merge, kvi_no_aisle,
			kvi_no_drop, kvi_order_time,
			no_lunches, no_breaks, damage)
		SELECT	'I' || TO_CHAR (seq1.NEXTVAL), batch_date, 'IRASGN',
			'C', psBatch,
			NVL(pdtStartTime, actl_start_time),
			NVL(pdtStartTime, actl_start_time),
			(NVL(pdtStartTime, SYSDATE) -
				NVL(pdtStartTime, actl_start_time)) * 1440,
			DECODE(psUser, NULL, user_id, psUser),
			user_supervsr_id,
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0
		  FROM	batch
		 WHERE	batch_no = psBatch;

		DBMS_OUTPUT.PUT_LINE('CreateIRASGN: Insert IRASGN for batch[' ||
			psBatch || ']: ' || TO_CHAR(SQL%ROWCOUNT));
		IF SQL%ROWCOUNT > 0 THEN
			RETURN 0;
		ELSE
			RETURN 1;
		END IF;
	EXCEPTION
		WHEN OTHERS THEN
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) || ': Error ' ||
				' creating IRASGN for batch ' || psBatch);
			RETURN SQLCODE;
	END CreateIRASGN;

	PROCEDURE sls_reassign (poiError    OUT INTEGER,
				poiLoaded   OUT NUMBER,
				posSelBatch OUT batch.batch_no%TYPE,
				psUser	    IN  batch.user_id%TYPE DEFAULT NULL,
				psBatch	    IN  batch.batch_no%TYPE DEFAULT NULL)
	IS
		sUser		batch.user_id%TYPE := NVL(psUser,
					REPLACE(USER, 'OPS$', ''));
		lSuccess	VARCHAR2 (1) := 'Y';
		lLbrActive	VARCHAR2 (1) := NULL;
		lCrtBatch	VARCHAR2 (1) := NULL;
		lUserId		batch.user_id%TYPE := psUser;
		sBatch		batch.batch_no%TYPE := psBatch;
		lSupervisor	usr.suprvsr_user_id%TYPE := NULL;
		lLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
		e_bad_user	EXCEPTION;
		skip_rest	EXCEPTION;
		lStatus		batch.status%TYPE := NULL;
		lLoaded		BatchRecord;
		lNotLoaded	BatchRecord;
		lGetStatus	NUMBER := 0;
		iTimeSpent	NUMBER := 0;
		dtStartTime	DATE := NULL;
		iStatus		NUMBER := 0;
		sTmpBatch	batch.batch_no%TYPE := NULL;
		sRefNo		batch.ref_no%TYPE := NULL;
		sPallet		floats.float_seq%TYPE := NULL;
		sSelBatch	batch.batch_no%TYPE := NULL;
		sLoaderStatus	las_pallet.loader_status%TYPE := NULL;
		dtComplete	batch.actl_stop_time%TYPE := NULL;
		blnDelete	BOOLEAN := FALSE;
		sTruck		floats.truck_no%TYPE := NULL;
		iLoaded		NUMBER := 0;
		sCmt		batch.cmt%TYPE := NULL;
		sOrdSeq		float_detail.order_seq%TYPE := NULL;
	BEGIN
		poiError := 0;
		poiLoaded := 0;
		posSelBatch := NULL;

		DBMS_OUTPUT.PUT_LINE('u[' || sUser || '] bat[' ||
			psBatch || ']');

		BEGIN
			SELECT	NVL(s.config_flag_val, 'N')
			  INTO	lLbrActive
			  FROM sys_config s
			 WHERE s.config_flag_name = 'LBR_MGMT_FLAG';
		EXCEPTION
			WHEN  OTHERS THEN
				lLbrActive := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('LM flag[' || lLbrActive || ']');

		BEGIN
			SELECT	NVL(s.create_batch_flag, 'N')
			  INTO	lCrtBatch
			  FROM lbr_func s
			 WHERE s.lfun_lbr_func = 'LD';
		EXCEPTION
			WHEN  OTHERS THEN
				lCrtBatch := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('CrtBatch flag[' || lCrtBatch || ']');

		IF lLbrActive = 'N' OR lCrtBatch = 'N' THEN
			RAISE skip_rest;
		END IF;

		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	lSupervisor, lLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || sUser;

			DBMS_OUTPUT.PUT_LINE('Supervisor[' || lSupervisor ||
				'] lbrGrp[ ' || lLbrGrp || ']');
			IF lSupervisor IS NULL OR lLbrGrp IS NULL THEN
				lSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor ' ||
					'for ' || sUser);
				lSuccess := 'N';
		END;
		IF lSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;

		-- Retrieve active batch for user
		BEGIN
			SELECT	b.batch_no, b.user_id, b.status,
				b.actl_start_time, b.ref_no, b.cmt
			  INTO	sBatch, lUserId, lStatus, dtStartTime, sRefNo,
				sCmt
			  FROM	batch b
			 WHERE  (((psBatch IS NULL) AND
				  (b.user_id = sUser) AND
				  (b.status = 'A')) OR 
				 ((psBatch IS NOT NULL) AND
				  (b.batch_no = psBatch)))
			   AND	batch_date = (SELECT MAX(batch_date)
					FROM batch b2
		 			WHERE  (((psBatch IS NULL) AND
					         (b2.user_id = sUser) AND
						 (b2.status = 'A')) OR 
						((psBatch IS NOT NULL) AND
						 (b2.batch_no = psBatch))));
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Error getting active batch for ' ||
					'bat/user[' || psBatch || '/' ||
					sUser || ']');
				lStatus := 'F';
		END;
		DBMS_OUTPUT.PUT_LINE('Loader batch [' || sBatch || '] user[' ||
			lUserId || ' status[' || lStatus || ']');
		DBMS_OUTPUT.PUT_LINE('Ref[' || sRefNo || '] cmt[' || sCmt || ']');
		dtComplete := dtStartTime;

		-- No batch is active for user. Do nothing.
		IF lStatus <> 'A' THEN
			RAISE skip_rest;
		END IF;

		IF lUserId IS NULL THEN
			-- There is no active batch for input user
			lUserId := NVL(psUser, REPLACE(USER, 'OPS$', ''));
		END IF;

		-- Create ISTART if needed
		CreateISTART(lUserId, sBatch, iStatus);

		-- Reset, delete or complete batch according to batch condition
		IF iStatus = 0 AND SUBSTR(sBatch, 1, 1) = 'L' THEN
			sTmpBatch := SUBSTR(sBatch, 2);
			IF INSTR(sTmpBatch, 'R') <> 0 OR
				INSTR(sTmpBatch, 'U') <> 0 THEN
				-- Reload or unload loader batch
				IF INSTR(sTmpBatch, 'R') <> 0 THEN
					sTmpBatch := SUBSTR(sTmpBatch, 1,
						INSTR(sTmpBatch, 'R') - 1);
				ELSE
					sTmpBatch := SUBSTR(sTmpBatch, 1,
						INSTR(sTmpBatch, 'U') - 1);
				END IF;
			ELSIF INSTR(sTmpBatch, 'C') <> 0 THEN
				-- Loader case batch
				sTmpBatch := sRefNo;
			END IF;
			DBMS_OUTPUT.PUT_LINE('sBat[' || sBatch || '] sTmpB[' ||
				sTmpBatch || ']');
			BEGIN
				SELECT TO_CHAR(f.batch_no), f.float_seq,
					f.truck_no, d.order_seq
				INTO sSelBatch, sPallet, sTruck, sOrdSeq
				FROM floats f, float_detail d
				WHERE f.float_no = d.float_no
				AND   (((sBatch LIKE 'LC%') AND
					(((d.order_seq = sTmpBatch) OR
					  (d.stop_no = sTmpBatch)) AND
					  (f.float_no = sCmt))) OR
				       ((sBatch NOT LIKE 'LC%') AND
					(f.float_no = TO_NUMBER(sTmpBatch))))
				AND   f.pallet_pull IN ('N', 'B', 'Y')
				AND   ROWNUM = 1;
			EXCEPTION
				WHEN OTHERS THEN
					sSelBatch := NULL;
					sPallet := NULL;
					sTruck := NULL;
					sOrdSeq := NULL;
			END;
			posSelBatch := sSelBatch;
			DBMS_OUTPUT.PUT_LINE('selB[' || sSelBatch ||
				'] float[ ' || sPallet || '] truck[' ||
				sTruck || '] ordSq[' || sOrdSeq || ']');
			IF sBatch LIKE 'LC%' THEN
				-- Case loader batch. Check loaded status
				-- from LAS_CASE
				BEGIN
					SELECT DECODE(LTRIM(RTRIM(float_seq)),
						NULL,
						DECODE(LTRIM(RTRIM(location)),
							NULL, 0, 3),
						2)
					INTO iLoaded
					FROM las_case
					WHERE LTRIM(RTRIM(truck)) = sTruck
					AND   order_seq = sOrdSeq
					AND   ROWNUM = 1;
				EXCEPTION
					WHEN OTHERS THEN
						iLoaded := 0;
				END;
			ELSE
				-- Not case loader batch. Get loader status
				-- directly
				BEGIN
					SELECT LTRIM(RTRIM(loader_status))
					INTO sLoaderStatus
					FROM las_pallet
					WHERE LTRIM(RTRIM(batch)) = sSelBatch
					AND   LTRIM(RTRIM(truck)) = sTruck
					AND   LTRIM(RTRIM(palletno)) = sPallet;
				EXCEPTION
					WHEN OTHERS THEN
						sLoaderStatus := NULL;
				END;
				IF NVL(sLoaderStatus, ' ') = '*' THEN
					iLoaded := 1;
				END IF;
			END IF;
			poiLoaded := iLoaded;
			DBMS_OUTPUT.PUT_LINE('Selection batch[' ||
				sSelBatch || '] loaderstatus[' ||
				TO_CHAR(iLoaded) || ']');
			IF (INSTR(sBatch, 'R') = 0 AND
				INSTR(sBatch, 'U') = 0) OR
				INSTR(sBatch, 'LC') <> 0 THEN
				IF iLoaded > 0 THEN
				-- Active regular loader batch and after
				-- zone is scanned or active case loader batch
				-- and after float/zone is scanned
				BEGIN
					DBMS_OUTPUT.PUT_LINE('Active ' ||
						'regular/case loader batch ' ||
						'after float/zone scanned : ' ||
						'Complete it');
					pl_lm1.create_schedule (sBatch,
						SYSDATE, iTimeSpent);
					BEGIN
						SELECT actl_stop_time
						INTO dtComplete
						FROM batch
						WHERE batch_no = sBatch;
					EXCEPTION
						WHEN OTHERS THEN
							dtComplete :=
								dtStartTime;
					END;
				EXCEPTION
					WHEN OTHERS THEN
						DBMS_OUTPUT.PUT_LINE(
							TO_CHAR(SQLCODE) ||
						': Error completing batch ' ||
							sBatch);
						iStatus := ERR_LM_BATCH_UPD_FAIL;
						poiError := ERR_LM_BATCH_UPD_FAIL;
						RAISE skip_rest;
				END;
				ELSE
				-- Active regular loader batch and before
				-- zone is scanned or active case loader batch
				-- and before float/zone is scanned
				BEGIN
					DBMS_OUTPUT.PUT_LINE('Active ' ||
						'regular/case loader batch ' ||
						'before' || ' float/zone ' ||
						'scanned : To Future/Delete');
					dtComplete := dtStartTime;
					IF sBatch LIKE 'LC%' THEN
						blnDelete := TRUE;
					ELSE
						UPDATE batch
						SET status = 'F',
							user_id = NULL,
							actl_start_time = NULL,
							user_supervsr_ID = NULL,
							actl_time_spent = NULL
						WHERE batch_no = sBatch;
						DBMS_OUTPUT.PUT_LINE(
							TO_CHAR(SQL%ROWCOUNT) ||
							' record(s) for ' ||
							'batch ' || sBatch ||
							' updated to F');
					END IF;
				EXCEPTION
					WHEN OTHERS THEN
						DBMS_OUTPUT.PUT_LINE(
						TO_CHAR(SQLCODE) ||
						': Error updating/deleting ' ||
						'batch ' || sBatch ||
						' (to F)');
				END;
				END IF;
			ELSIF INSTR(sBatch, 'U') <> 0 OR
				(INSTR(sBatch, 'R') <> 0 AND
				 NVL(sLoaderStatus, ' ') = '*') THEN
				-- Active unload loader batch or active
				-- reloaded loader batch after zone is scanned
				DBMS_OUTPUT.PUT_LINE('Active unload or ' ||
					'reload with scanned zone loader ' ||
					'batch: Complete it');
				BEGIN
					pl_lm1.create_schedule (sBatch,
						SYSDATE, iTimeSpent);
					BEGIN
						SELECT actl_stop_time
						INTO dtComplete
						FROM batch
						WHERE batch_no = sBatch;
					EXCEPTION
						WHEN OTHERS THEN
							dtComplete :=
								dtStartTime;
					END;
				EXCEPTION
					WHEN OTHERS THEN
						DBMS_OUTPUT.PUT_LINE(
							TO_CHAR(SQLCODE) ||
						': Error completing batch ' ||
							sBatch);
						poiError := ERR_LM_BATCH_UPD_FAIL;
						iStatus := ERR_LM_BATCH_UPD_FAIL;
						RAISE skip_rest;
				END;
			ELSE
				-- Include reload and loader case batch
				DBMS_OUTPUT.PUT_LINE('Active reload or case ' ||
					'loader batch: Delete it');
				blnDelete := TRUE;
			END IF;
		ELSIF iStatus = 0 THEN
			-- Not loader batch
			DBMS_OUTPUT.PUT_LINE('Not loader batch: Complete it');
			BEGIN
				pl_lm1.create_schedule (sBatch,
					SYSDATE, iTimeSpent);
				BEGIN
					SELECT actl_stop_time
					INTO dtComplete
					FROM batch
					WHERE batch_no = sBatch;
				EXCEPTION
					WHEN OTHERS THEN
						dtComplete := dtStartTime;
				END;
			EXCEPTION
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
						': Error completing batch ' ||
						sBatch);
					poiError := ERR_LM_BATCH_UPD_FAIL;
					iStatus := ERR_LM_BATCH_UPD_FAIL;
					RAISE skip_rest;
			END;
		END IF;

		IF iStatus = 0 THEN
			-- Create IRASGN and ISTOP
			iStatus := CreateIRASGN(sBatch, dtComplete, lUserId);
			DBMS_OUTPUT.PUT_LINE('CreateIRASGN status[' ||
				TO_CHAR(istatus) || ']');
			IF iStatus = 0 THEN
				create_istop(lUserId, sBatch, iStatus,
					dtComplete);
			END IF;
			DBMS_OUTPUT.PUT_LINE('create_istop status[' ||
				TO_CHAR(istatus) || ']');
		END IF;

		IF iStatus = 0 AND blnDelete THEN
			BEGIN
				DELETE batch
				WHERE batch_no = sBatch;

				DBMS_OUTPUT.PUT_LINE(
					TO_CHAR(SQL%ROWCOUNT) ||
					' record(s) for batch ' ||
					sBatch || ' deleted');
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					NULL;
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE(
						TO_CHAR(SQLCODE) ||
						': Error deleting ' ||
						'batch ' || sBatch);
					iStatus := ERR_LM_BATCH_UPD_FAIL;
			END;
		END IF;

		poiError := iStatus;

	EXCEPTION
		WHEN e_bad_user THEN
			poiError := ERR_LM_BAD_USER;
			RAISE_APPLICATION_ERROR(pl_exc.ct_lm_bad_user,
				'User ' || lUserId ||
				' is not set up in Labor Management');
		WHEN skip_rest THEN
			NULL;
		WHEN OTHERS THEN
			RAISE;
	END sls_reassign;

	PROCEDURE create_istop (
		psUser		IN  batch.user_id%TYPE,
		psBatch		IN  batch.batch_no%TYPE,
		poiStatus	OUT NUMBER,
		pdtStart	IN  batch.actl_start_time%TYPE DEFAULT NULL)
	IS
		sSuccess	VARCHAR2 (1) := 'Y';
		sSupervisor	usr.suprvsr_user_id%TYPE;
		sLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
		iDuration	NUMBER := 0;
		e_bad_user	EXCEPTION;
		skip_rest	EXCEPTION;
	BEGIN
		poiStatus := 0;

		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	sSupervisor, sLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || psUser;
			IF sSupervisor IS NULL OR sLbrGrp IS NULL THEN
				sSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor ' ||
					'for ' || psUser);
				sSuccess := 'N';
		END;
		IF sSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;

		BEGIN
			SELECT	NVL (st.stop_dur, 0) 
			  INTO	iDuration
			  FROM	sched_type st, sched s, usr u, batch b,
				job_code jc
			 WHERE	st.sctp_sched_type = s.sched_type            
			   AND	s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp        
			   AND	s.sched_jbcl_job_class = jc.jbcl_job_class   
			   AND	s.sched_actv_flag = 'Y'                      
			   AND	u.user_id = 'OPS$' || psUser
			   AND	jc.jbcd_job_code = b.jbcd_job_code           
			   AND	b.batch_no = psBatch;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot calculate duration for ' ||
					'batch ' || psBatch || ' and user ' ||
					psUser);
				iDuration := 0;
		END;

		IF iDuration > 0 THEN
		BEGIN


			INSERT INTO batch (batch_no, batch_date, jbcd_job_code,
				status, actl_start_time, actl_stop_time,
				actl_time_spent, user_id, user_supervsr_id,
				kvi_doc_time, kvi_cube, kvi_wt, kvi_no_piece,
				kvi_no_pallet, kvi_no_item, kvi_no_data_capture,
				kvi_no_po, kvi_no_stop, kvi_no_zone, kvi_no_loc,
				kvi_no_case, kvi_no_split, kvi_no_merge,
				kvi_no_aisle, kvi_no_drop, kvi_order_time,
				no_lunches,  no_breaks, damage)
			VALUES ('I' || TO_CHAR (seq1.nextval), TRUNC(SYSDATE),
				'IWASH', 'C',
				NVL(pdtStart, SYSDATE),
				(NVL(pdtStart, SYSDATE) + (iDuration / 1440)),
				iDuration, psUser, sSupervisor,
				0, 0, 0, 0, 0, 0, 0, 0, 0, 
				0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
			DBMS_OUTPUT.PUT_LINE('Add IWASH #rows[' ||
				TO_CHAR(SQL%ROWCOUNT) || ']');
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot create IWASH for ' ||
					'batch ' || psBatch || ' and user ' ||
					psUser);
		END;
		END IF;

		BEGIN
			INSERT INTO batch (
				batch_no, batch_date, jbcd_job_code, status,
				actl_start_time, actl_stop_time,
				actl_time_spent, user_id, user_supervsr_id,
				kvi_doc_time, kvi_cube, kvi_wt, kvi_no_piece,
				kvi_no_pallet, kvi_no_item, kvi_no_data_capture,
				kvi_no_po, kvi_no_stop, kvi_no_zone, kvi_no_loc,
				kvi_no_case, kvi_no_split, kvi_no_merge,
				kvi_no_aisle, kvi_no_drop, kvi_order_time,
				no_lunches,  no_breaks, damage)
			VALUES ('I' || TO_CHAR(seq1.nextval), TRUNC(SYSDATE),
				'ISTOP', 'C',
				(NVL(pdtStart, SYSDATE) + (iDuration / 1440)),
				(NVL(pdtStart, SYSDATE) + (iDuration / 1440)),
				0, psUser, sSupervisor, 0, 0, 0, 0, 0, 0, 0, 0, 
				0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
			DBMS_OUTPUT.PUT_LINE('Add ISTOP #rows[' ||
				TO_CHAR(SQL%ROWCOUNT) || ']');
		EXCEPTION
			WHEN OTHERS THEN
				poiStatus := ERR_LM_INS_ISTOP_FAIL;
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot create ISTOP for ' ||
					'batch ' || psBatch || ' and user ' ||
					psUser);
		END;
	EXCEPTION
		WHEN e_bad_user THEN
			poiStatus := ERR_LM_BAD_USER;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				': Cannot create ISTOP for ' ||
				'batch ' || psBatch || ' and bad user ' ||
				psUser);
		WHEN skip_rest THEN
			NULL;
		WHEN OTHERS THEN
			poiStatus := ERR_LM_INS_ISTOP_FAIL;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				': Cannot create ISTOP for ' ||
				'batch ' || psBatch || ' and user ' ||
				psUser);
	END create_istop;

	FUNCTION get_loader_batch (
		psData1		IN  VARCHAR2,
		psData2		IN  VARCHAR2 DEFAULT NULL)
	RETURN VARCHAR2 IS
		sBatch	batch.batch_no%TYPE := NULL;
	BEGIN
		IF psData2 IS NULL THEN
			-- Exit from case label
			BEGIN
				SELECT DISTINCT 'L' || TO_CHAR(float_no)
				INTO sBatch
				FROM float_detail
				WHERE order_seq = psData1
				AND   ROWNUM = 1;
			EXCEPTION
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE(
						TO_CHAR(SQLCODE) ||
						': Cannot get float # from ' ||
						'orderseq ' || psData1);
					sBatch := NULL;
			END;
		ELSE
			-- Exit from zone label
			BEGIN
				SELECT DISTINCT 'L' || TO_CHAR(float_no)
				INTO sBatch
				FROM floats
				WHERE truck_no = psData1
				AND   float_seq = psData2
				AND   ROWNUM = 1;
			EXCEPTION
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE(
						TO_CHAR(SQLCODE) ||
						': Cannot get float # from ' ||
						'truck/pallet' || psData1 ||
						'/' || psData2);
					sBatch := NULL;
			END;
		END IF;

		RETURN sBatch;
	END;

	PROCEDURE create_ilexit (
		psJobCode	IN  batch.jbcd_job_code%TYPE,
		psUser		IN  batch.user_id%TYPE,
		psBatch		IN  batch.batch_no%TYPE,
		pdtStartTime	IN  batch.actl_start_time%TYPE,
		poiStatus	OUT NUMBER,
		psExtra		IN  VARCHAR2 DEFAULT NULL)
	IS
		sSuccess	VARCHAR2 (1) := 'Y';
		sSupervisor	usr.suprvsr_user_id%TYPE;
		sLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
		iDuration	NUMBER := 0;
		e_bad_user	EXCEPTION;
		skip_rest	EXCEPTION;
		sBatch		batch.batch_no%TYPE := psBatch;
		sExtra		batch.cmt%TYPE := psExtra;
		sExtra1		batch.cmt%TYPE := NULL;
	BEGIN
		poiStatus := 0;

                dbms_output.put_line(' entered create ilexit');

		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	sSupervisor, sLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || psUser;
			IF sSupervisor IS NULL OR sLbrGrp IS NULL THEN
				sSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor ' ||
					'for ' || psUser);
				sSuccess := 'N';
		END;
		IF sSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;

		BEGIN
			SELECT	NVL (st.stop_dur, 0) 
			  INTO	iDuration
			  FROM	sched_type st, sched s, usr u, batch b,
				job_code jc
			 WHERE	st.sctp_sched_type = s.sched_type            
			   AND	s.sched_lgrp_lbr_grp = u.lgrp_lbr_grp        
			   AND	s.sched_jbcl_job_class = jc.jbcl_job_class   
			   AND	s.sched_actv_flag = 'Y'                      
			   AND	u.user_id = 'OPS$' || psUser
			   AND	jc.jbcd_job_code = b.jbcd_job_code           
			   AND	b.batch_no = sBatch;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot calculate duration for ' ||
					'batch ' || sBatch || ' and user ' ||
					psUser);
				iDuration := 0;
		END;

                dbms_output.put_line(' before inserting to batch');

		IF psJobCode = 'ILCEXT' THEN
			sExtra := 'Batch[' || sBatch || ']';
			BEGIN
				SELECT f.truck_no || ' ' || f.float_seq
				INTO sExtra1
				FROM floats f, float_detail d
				WHERE f.float_no = d.float_no
				AND   f.pallet_pull IN ('N', 'B', 'Y')
				AND   d.order_seq = psExtra
				AND   ROWNUM = 1;
			EXCEPTION
				WHEN OTHERS THEN
					sExtra1 := NULL;
			END;
			IF sExtra1 IS NOT NULL THEN
				IF sExtra IS NOT NULL THEN
					sExtra := sExtra || ' ';
				END IF;
				sExtra := sExtra || 'Float Label[' ||
					sExtra1 || ']';
			END IF;
		END IF;

		BEGIN
			INSERT INTO batch (
				batch_no, batch_date, jbcd_job_code, status,
				actl_start_time, actl_stop_time, ref_no,
				user_id, user_supervsr_id,
				kvi_doc_time, kvi_cube, kvi_wt, kvi_no_piece,
				kvi_no_pallet, kvi_no_item, kvi_no_data_capture,
				kvi_no_po, kvi_no_stop, kvi_no_zone, kvi_no_loc,
				kvi_no_case, kvi_no_split, kvi_no_merge,
				kvi_no_aisle, kvi_no_drop, kvi_order_time,
				no_lunches,  no_breaks, damage, cmt)
			VALUES ('I' || TO_CHAR(seq1.nextval), TRUNC(SYSDATE),
				psJobCode, 'A',
				NVL(pdtStartTime, SYSDATE), NULL,
				DECODE(psJobCode, 'ILCEXT', psExtra, sBatch),
				psUser, sSupervisor, 0, 0, 0, 0, 0, 0, 0, 0, 
				0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
				sExtra);
		EXCEPTION
			WHEN OTHERS THEN
				poiStatus := ERR_LM_JOBCODE_NOT_FOUND;
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot create ' || psJobCode ||
					' for ' || 'batch ' || sBatch ||
					' and user ' || psUser);
		END;
	EXCEPTION
		WHEN e_bad_user THEN
			poiStatus := ERR_LM_BAD_USER;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				': Cannot create ' || psJobCode || ' for ' ||
				'batch ' || sBatch || ' and bad user ' ||
				psUser);
		WHEN skip_rest THEN
			NULL;
		WHEN OTHERS THEN
			poiStatus := ERR_LM_JOBCODE_NOT_FOUND;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				': Cannot create ' || psJobCode || ' for ' ||
				'batch ' || sBatch || ' and user ' ||
				psUser);
	END create_ilexit;

	PROCEDURE exit_float_label (
		psUser	  IN  batch.user_id%TYPE,
		poiError  OUT NUMBER)
	IS
		lSuccess	VARCHAR2 (1) := 'Y';
		lLbrActive	VARCHAR2 (1) := NULL;
		lCrtBatch	VARCHAR2 (1) := NULL;
		sBatch		batch.batch_no%TYPE := NULL;
		lSupervisor	usr.suprvsr_user_id%TYPE := NULL;
		lLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
		e_bad_user	EXCEPTION;
		skip_rest	EXCEPTION;
		lStatus		batch.status%TYPE := NULL;
		lGetStatus	NUMBER := 0;
		iTimeSpent	NUMBER := 0;
		dtStartTime	DATE := NULL;
		iStatus		NUMBER := 0;
		sJobcode	batch.jbcd_job_code%TYPE := NULL;
		sCmt		batch.cmt%TYPE := NULL;
		sRef		batch.ref_no%TYPE := NULL;
		sTruck		batch.ref_no%TYPE := NULL;
		sFloat		floats.float_seq%TYPE := NULL;
		sFloatNo	batch.batch_no%TYPE := NULL;
	BEGIN
		poiError := 0;

		DBMS_OUTPUT.PUT_LINE('Exiting float label screen for user [' ||
			psUser || ']'); 

		-- Get LM flag
		BEGIN
			SELECT	NVL(s.config_flag_val, 'N')
			  INTO	lLbrActive
			  FROM sys_config s
			 WHERE s.config_flag_name = 'LBR_MGMT_FLAG';
		EXCEPTION
			WHEN  OTHERS THEN
				lLbrActive := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('LM flag[' || lLbrActive || ']');

		-- Get LM create batch flag
		BEGIN
			SELECT	NVL(s.create_batch_flag, 'N')
			  INTO	lCrtBatch
			  FROM lbr_func s
			 WHERE s.lfun_lbr_func = 'LD';
		EXCEPTION
			WHEN  OTHERS THEN
				lCrtBatch := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('CrtBatch flag[' || lCrtBatch || ']');

		-- Don't need to do anything if LM related flags are not set
		IF lLbrActive = 'N' OR lCrtBatch = 'N' THEN
			RAISE skip_rest;
		END IF;

		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	lSupervisor, lLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || psUser;

			DBMS_OUTPUT.PUT_LINE('Supervisor[' || lSupervisor ||
				'] lbrGrp[ ' || lLbrGrp || ']');
			IF lSupervisor IS NULL OR lLbrGrp IS NULL THEN
				lSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor ' ||
					'for ' || psUser);
				lSuccess := 'N';
		END;
		IF lSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;

		-- Retrieve active batch for user
		BEGIN
			SELECT	b.batch_no, b.actl_start_time,
				b.jbcd_job_code, b.ref_no, b.cmt
			  INTO	sBatch, dtStartTime, sJobcode, sRef, sCmt
			  FROM	batch b
			 WHERE	b.user_id = psUser
			   AND	b.status = 'A'
			   AND	b.actl_start_time = (SELECT MAX(actl_start_time)
					FROM batch b2
		 			WHERE	b2.user_id = psUser
					  AND	b2.status = 'A');
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Error getting active batch for ' ||
					'user[' || psUser || ']');
				sBatch := NULL;
				dtStartTime := NULL;
				lStatus := 'F';
		END;
		DBMS_OUTPUT.PUT_LINE('Active batch [' || sBatch || '] user[' ||
			psUser || ' status[' || lStatus || ']');
		DBMS_OUTPUT.PUT_LINE('Batch [' || sBatch || '] user[' ||
			psUser || ' ref[' || sRef || '] jobcode[' ||
			sJobcode || '] cmt[' || sCmt || '] startTm[' ||
			TO_CHAR(dtStartTime, 'MM/DD/YYYY HH24:MI:SS') || ']');

		sFloatNo := NULL;
		IF sBatch LIKE 'L%' AND sBatch NOT LIKE 'LC%' THEN
			sFloatNo := SUBSTR(sBatch, 2);
			IF INSTR(sFloatNo, 'R') <> 0 THEN
				sFloatNo:= SUBSTR(sFloatNo, 1,
						INSTR(sFloatNo, 'R') - 1);
			ELSIF INSTR(sFloatNo, 'U') <> 0 THEN
				sFloatNo:= SUBSTR(sFloatNo, 1,
						INSTR(sFloatNo, 'U') - 1);
			END IF;
		ELSIF sBatch IN ('ILBNFD', 'ILFEXT') AND sRef LIKE 'L%' THEN
			sRef := SUBSTR(sRef, 2);
		END IF;
		DBMS_OUTPUT.PUT_LINE('Batch [' || sBatch || '] user[' ||
			psUser || ' Conv Ref[' || sRef || ']');

		BEGIN
			SELECT DISTINCT f.truck_no, f.float_seq
			INTO sTruck, sFloat
			FROM floats f, float_detail d
			WHERE f.float_no = d.float_no
			AND   f.pallet_pull IN ('N', 'B', 'Y')
			AND   (((sBatch LIKE 'L%') AND
				(f.truck_no = sRef) AND
				(f.float_no = TO_NUMBER(sFloatNo))) OR
			       ((sBatch LIKE 'LC%') AND
				(f.float_no = TO_NUMBER(sCmt)) AND
				(d.order_seq = sRef)) OR
			       ((sJobcode = 'ILFEXT') AND
				(f.float_no = TO_NUMBER(sRef))) OR
			       ((sJobcode = 'ILBNFD') AND
				(f.float_no = TO_NUMBER(sRef))) OR
			       ((sJobcode = 'ILUNTK') AND
				(f.truck_no = TO_NUMBER(sRef))) OR
			       ((sJobcode = 'ILCEXT') AND
				(d.order_seq = TO_NUMBER(sRef))))
			AND    ROWNUM = 1;
		EXCEPTION
			WHEN OTHERS THEN
				sTruck := sRef;
				sFloat := NULL;
		END;

		IF sBatch LIKE 'L%' AND
		   sBatch NOT LIKE 'LC%' AND
		   (sBatch NOT LIKE 'L%U_' AND sBatch NOT LIKE 'L%U__') THEN
			-- If this is a loader batch or exit from zone,
			-- We should complete the float too
			BEGIN
				UPDATE las_pallet
				   SET loader_status = '*',
					selection_status = NULL,
					upd_date = SYSDATE,
					upd_user = psUser
				 WHERE truck = LTRIM(RTRIM(sTruck))
				 AND   palletno = LTRIM(RTRIM(sFloat));
			EXCEPTION
				WHEN OTHERS THEN
					NULL;
			END;
		END IF;

		-- No batch is active for user. Do nothing.
		/* Charm600003040 - remove Starts - code is newly added in pl_lmc.PL_RF_LOGOUT
		IF lStatus <> 'A' THEN
			create_istop(psUser, sBatch, poiError);
			RAISE skip_rest;
		END IF;

		-- Complete the current active batch for the user
		BEGIN
			pl_lm1.create_schedule (sBatch, SYSDATE, iTimeSpent);
		EXCEPTION
			WHEN OTHERS THEN
				poiError := SQLCODE;
		END;
		
       
		-- Add an ISTOP for the user
		create_istop(psUser, sBatch, poiError);
		*/

	EXCEPTION
		WHEN e_bad_user THEN
			poiError := ERR_LM_BAD_USER;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				'User ' || psUser ||
				' is not set up in Labor Management');
		WHEN skip_rest THEN
			NULL;
		WHEN OTHERS THEN
			poiError := ERR_LM_BAD_USER;
	END exit_float_label;

	PROCEDURE exit_float_label2 (
		psUser	  IN  batch.user_id%TYPE,
		poiError  OUT NUMBER)
	IS
		lSuccess	VARCHAR2 (1) := 'Y';
		lLbrActive	VARCHAR2 (1) := NULL;
		lCrtBatch	VARCHAR2 (1) := NULL;
		sBatch		batch.batch_no%TYPE := NULL;
		lSupervisor	usr.suprvsr_user_id%TYPE := NULL;
		lLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
		e_bad_user	EXCEPTION;
		skip_rest	EXCEPTION;
		lStatus		batch.status%TYPE := NULL;
		lGetStatus	NUMBER := 0;
		iTimeSpent	NUMBER := 0;
		dtStartTime	DATE := NULL;
		iStatus		NUMBER := 0;
		sJobcode	batch.jbcd_job_code%TYPE := NULL;
		sCmt		batch.cmt%TYPE := NULL;
		sRef		batch.ref_no%TYPE := NULL;
		sTruck		batch.ref_no%TYPE := NULL;
		sFloat		floats.float_seq%TYPE := NULL;
		sFloatNo	batch.batch_no%TYPE := NULL;
		lrw_batch	pl_lmc.c_get_cur_batch%ROWTYPE := NULL;
	BEGIN
		poiError := 0;

		DBMS_OUTPUT.PUT_LINE('Exiting float label screen for user [' ||
			psUser || ']'); 

		-- Get LM flag
		BEGIN
			SELECT	NVL(s.config_flag_val, 'N')
			  INTO	lLbrActive
			  FROM sys_config s
			 WHERE s.config_flag_name = 'LBR_MGMT_FLAG';
		EXCEPTION
			WHEN  OTHERS THEN
				lLbrActive := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('LM flag[' || lLbrActive || ']');

		-- Get LM create batch flag
		BEGIN
			SELECT	NVL(s.create_batch_flag, 'N')
			  INTO	lCrtBatch
			  FROM lbr_func s
			 WHERE s.lfun_lbr_func = 'LD';
		EXCEPTION
			WHEN  OTHERS THEN
				lCrtBatch := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('CrtBatch flag[' || lCrtBatch || ']');

		-- Don't need to do anything if LM related flags are not set
		IF lLbrActive = 'N' OR lCrtBatch = 'N' THEN
			RAISE skip_rest;
		END IF;

		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	lSupervisor, lLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || psUser;

			DBMS_OUTPUT.PUT_LINE('Supervisor[' || lSupervisor ||
				'] lbrGrp[ ' || lLbrGrp || ']');
			IF lSupervisor IS NULL OR lLbrGrp IS NULL THEN
				lSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor ' ||
					'for ' || psUser);
				lSuccess := 'N';
		END;
		IF lSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;

		-- Retrieve active batch for user
		BEGIN
			SELECT	b.batch_no, b.actl_start_time,
				b.jbcd_job_code, b.ref_no, b.cmt
			  INTO	sBatch, dtStartTime, sJobcode, sRef, sCmt
			  FROM	batch b
			 WHERE	b.user_id = psUser
			   AND	b.status = 'A'
			   AND	b.actl_start_time = (SELECT MAX(actl_start_time)
					FROM batch b2
		 			WHERE	b2.user_id = psUser
					  AND	b2.status = 'A');
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Error getting active batch for ' ||
					'user[' || psUser || ']');
				sBatch := NULL;
				dtStartTime := NULL;
				lStatus := 'F';
		END;
		DBMS_OUTPUT.PUT_LINE('Active batch [' || sBatch || '] user[' ||
			psUser || ' status[' || lStatus || ']');
		DBMS_OUTPUT.PUT_LINE('Batch [' || sBatch || '] user[' ||
			psUser || ' ref[' || sRef || '] jobcode[' ||
			sJobcode || '] cmt[' || sCmt || '] startTm[' ||
			TO_CHAR(dtStartTime, 'MM/DD/YYYY HH24:MI:SS') || ']');

		sFloatNo := NULL;
		IF sBatch LIKE 'L%' AND sBatch NOT LIKE 'LC%' THEN
			sFloatNo := SUBSTR(sBatch, 2);
			IF INSTR(sFloatNo, 'R') <> 0 THEN
				sFloatNo:= SUBSTR(sFloatNo, 1,
						INSTR(sFloatNo, 'R') - 1);
			ELSIF INSTR(sFloatNo, 'U') <> 0 THEN
				sFloatNo:= SUBSTR(sFloatNo, 1,
						INSTR(sFloatNo, 'U') - 1);
			END IF;
		ELSIF sBatch IN ('ILBNFD', 'ILFEXT') AND sRef LIKE 'L%' THEN
			sRef := SUBSTR(sRef, 2);
		END IF;
		DBMS_OUTPUT.PUT_LINE('Batch [' || sBatch || '] user[' ||
			psUser || ' Conv Ref[' || sRef || ']');

		BEGIN
			SELECT DISTINCT f.truck_no, f.float_seq
			INTO sTruck, sFloat
			FROM floats f, float_detail d
			WHERE f.float_no = d.float_no
			AND   f.pallet_pull IN ('N', 'B', 'Y')
			AND   (((sBatch LIKE 'L%') AND
				(f.truck_no = sRef) AND
				(f.float_no = TO_NUMBER(sFloatNo))) OR
			       ((sBatch LIKE 'LC%') AND
				(f.float_no = TO_NUMBER(sCmt)) AND
				(d.order_seq = sRef)) OR
			       ((sJobcode = 'ILFEXT') AND
				(f.float_no = TO_NUMBER(sRef))) OR
			       ((sJobcode = 'ILBNFD') AND
				(f.float_no = TO_NUMBER(sRef))) OR
			       ((sJobcode = 'ILUNTK') AND
				(f.truck_no = TO_NUMBER(sRef))) OR
			       ((sJobcode = 'ILCEXT') AND
				(d.order_seq = TO_NUMBER(sRef))))
			AND    ROWNUM = 1;
		EXCEPTION
			WHEN OTHERS THEN
				sTruck := sRef;
				sFloat := NULL;
		END;

		IF sBatch LIKE 'L%' AND
		   sBatch NOT LIKE 'LC%' AND
		   (sBatch NOT LIKE 'L%U_' AND sBatch NOT LIKE 'L%U__') THEN
			-- If this is a loader batch or exit from zone,
			-- We should complete the float too
			BEGIN
				UPDATE las_pallet
				   SET loader_status = '*',
					selection_status = NULL,
					upd_date = SYSDATE,
					upd_user = psUser
				 WHERE truck = LTRIM(RTRIM(sTruck))
				 AND   palletno = LTRIM(RTRIM(sFloat));
			EXCEPTION
				WHEN OTHERS THEN
					NULL;
			END;
		END IF;

		-- No batch is active for user. Do nothing.
/*
		IF lStatus <> 'A' THEN
			create_istop(psUser, sBatch, poiError);
			RAISE skip_rest;
		END IF;

		-- Complete the current active batch for the user
		BEGIN
			pl_lm1.create_schedule (sBatch, SYSDATE, iTimeSpent);
		EXCEPTION
			WHEN OTHERS THEN
				poiError := SQLCODE;
		END;
		
       
		-- Add an ISTOP for the user
		create_istop(psUser, sBatch, poiError);
*/

	EXCEPTION
		WHEN e_bad_user THEN
			poiError := ERR_LM_BAD_USER;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				'User ' || psUser ||
				' is not set up in Labor Management');
		WHEN skip_rest THEN
			NULL;
		WHEN OTHERS THEN
			poiError := ERR_LM_BAD_USER;
	END exit_float_label2;

	PROCEDURE exit_zone_label (
		psUser	  IN  batch.user_id%TYPE,
		psData1	  IN  VARCHAR2,
		psData2	  IN  VARCHAR2,
		poiError  OUT NUMBER)
	IS
		lSuccess	VARCHAR2 (1) := 'Y';
		lLbrActive	VARCHAR2 (1) := NULL;
		lCrtBatch	VARCHAR2 (1) := NULL;
		sBatch		batch.batch_no%TYPE := NULL;
		lSupervisor	usr.suprvsr_user_id%TYPE := NULL;
		lLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
		e_bad_user	EXCEPTION;
		skip_rest	EXCEPTION;
		lStatus		batch.status%TYPE := NULL;
		lGetStatus	NUMBER := 0;
		iTimeSpent	NUMBER := 0;
		dtStartTime	DATE := NULL;
		-- CRQ#42225 -  declaring the stop time variable
        dtStopTime    DATE := NULL;
		iStatus		NUMBER := 0;
	BEGIN
		poiError := 0;

		DBMS_OUTPUT.PUT_LINE('Exiting zone label screen for user [' ||
			psUser || ']'); 

		-- Get LM flag
		BEGIN
			SELECT	NVL(s.config_flag_val, 'N')
			  INTO	lLbrActive
			  FROM sys_config s
			 WHERE s.config_flag_name = 'LBR_MGMT_FLAG';
		EXCEPTION
			WHEN  OTHERS THEN
				lLbrActive := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('LM flag[' || lLbrActive || ']');

		-- Get LM create batch flag
		BEGIN
			SELECT	NVL(s.create_batch_flag, 'N')
			  INTO	lCrtBatch
			  FROM lbr_func s
			 WHERE s.lfun_lbr_func = 'LD';
		EXCEPTION
			WHEN  OTHERS THEN
				lCrtBatch := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('CrtBatch flag[' || lCrtBatch || ']');

		-- Don't need to do anything if LM related flags are not set
		IF lLbrActive = 'N' OR lCrtBatch = 'N' THEN
			RAISE skip_rest;
		END IF;

		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	lSupervisor, lLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || psUser;

			DBMS_OUTPUT.PUT_LINE('Supervisor[' || lSupervisor ||
				'] lbrGrp[ ' || lLbrGrp || ']');
			IF lSupervisor IS NULL OR lLbrGrp IS NULL THEN
				lSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor ' ||
					'for ' || psUser);
				lSuccess := 'N';
		END;
		IF lSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;

		-- Retrieve active batch for user
		BEGIN
			SELECT	b.batch_no, b.actl_start_time
			  INTO	sBatch, dtStartTime
			  FROM	batch b
			 WHERE	b.user_id = psUser
			   AND	b.status = 'A'
			   AND	b.actl_start_time = (SELECT MAX(actl_start_time)
					FROM batch b2
		 			WHERE	b2.user_id = psUser
					  AND	b2.status = 'A');
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Error getting active batch for ' ||
					'user[' || psUser || ']');
				sBatch := NULL;
				dtStartTime := NULL;
				lStatus := 'F';
		END;
		DBMS_OUTPUT.PUT_LINE('Active batch [' || sBatch ||
			'] user[' ||
			psUser || ' status[' || lStatus || ']');

		-- No active batch is found. Try to get it from psData1 and
		-- psData2
		IF sBatch IS NULL THEN
			sBatch := get_loader_batch(psData1, psData2);
		END IF;

		-- No batch is active for user. Do nothing.
		IF lStatus <> 'A' THEN
		-- CRQ#42225 Added the below query to fetch the stop time of last completed batch
            BEGIN
                SELECT b.batch_no, b.actl_stop_time, b.status
                INTO sBatch, dtStopTime, lStatus
                FROM batch b
                WHERE b.user_id = psUser
                AND b.status = 'C'
                AND b.actl_stop_time =
                              (SELECT MAX (actl_stop_time)
                                 FROM batch b2
                                WHERE b2.user_id = psUser AND b2.status = 'C');
            EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (   TO_CHAR (SQLCODE)
                                  || ': Error getting completed batch for '
                                  || 'user['
                                  || psUser
                                  || ']'
                                 );
                sBatch := NULL;
                dtStopTime := NULL;
                lStatus := 'F';
            END;

            DBMS_OUTPUT.put_line (   'Complete batch ['
                            || sBatch
                            || '] user['
                            || psUser
                            || ' status['
                            || lStatus
                            || '] stop time is:' || dtStopTime
                           );

			           --CRQ#42225 calling the 'create_ilexit' with the stop time of last completed batch if not with the sysdate
                create_ilexit ('ILFEXT',
                        psUser,
                        sBatch,
                        nvl(dtStopTime,sysdate),
                        poiError,
                        psdata2
                       );

			RAISE skip_rest;
		END IF;

                dbms_output.put_line(' L batch is = '|| sBatch);
                dbms_output.put_line(' instr( sbatch) is = '||  INSTR(sBatch, 'R') );

		IF sBatch LIKE 'L%' THEN
			IF INSTR(sBatch, 'R') = 0 THEN
				-- This batch is an active original
				-- loader batch
			    BEGIN
				UPDATE batch
				SET status = 'F',
				    user_id = NULL,
				    actl_start_time = NULL
				WHERE batch_no = sBatch
				AND   status = 'A';
			    EXCEPTION
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
						': Cannot update loader ' ||
						'batch ' || sBatch ||
						' back to F');
			    END;
			ELSE
				-- This batch is an active re-load
				-- or un-loaded loader batch
			    BEGIN
				    DELETE batch
				    WHERE batch_no = sBatch
				    AND   status = 'A';
			    EXCEPTION
				    WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
						': Cannot delete loader ' ||
						'batch ' || sBatch);
			    END;
			END IF;
		ELSE
			-- Not a loader batch. Complete it
			pl_lm1.create_schedule (sBatch, SYSDATE, iTimeSpent);
		END IF;
		
		/*CRQ#42225 - added this below query again to fetch the stop time of the completed batch in case if any batch would have got
		completed as a result of 'create_schedule' called above */
		BEGIN
                SELECT b.batch_no, b.actl_stop_time, b.status
                INTO sBatch, dtStopTime, lStatus
                FROM batch b
                WHERE b.user_id = psUser
                AND b.status = 'C'
                AND b.actl_stop_time =
                              (SELECT MAX (actl_stop_time)
                                 FROM batch b2
                                WHERE b2.user_id = psUser AND b2.status = 'C');
            EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (   TO_CHAR (SQLCODE)
                                  || ': Error getting completed batch for '
                                  || 'user['
                                  || psUser
                                  || ']'
                                 );
                sBatch := NULL;
                dtStopTime := NULL;
                lStatus := 'F';
            END;

            DBMS_OUTPUT.put_line (   'Complete batch ['
                            || sBatch
                            || '] user['
                            || psUser
                            || ' status['
                            || lStatus
                            || '] stop time is:' || dtStopTime
                           );

		-- Create indirect exit
		           --CRQ#42225 calling the 'create_ilexit' with the stop time of last completed batch if not with the sysdate
                create_ilexit ('ILFEXT',
                        psUser,
                        sBatch,
                        nvl(dtStopTime,sysdate),
                        poiError,
                        psdata2
                       );

	EXCEPTION
		WHEN e_bad_user THEN
			poiError := ERR_LM_BAD_USER;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				'User ' || psUser ||
				' is not set up in Labor Management');
		WHEN skip_rest THEN
			NULL;
		WHEN OTHERS THEN
			poiError := ERR_LM_BAD_USER;
	END exit_zone_label;

	PROCEDURE exit_case_label (
		psUser	  IN  batch.user_id%TYPE,
		psData1	  IN  VARCHAR2,
		poiError  OUT NUMBER)
	IS
		lSuccess	VARCHAR2 (1) := 'Y';
		lLbrActive	VARCHAR2 (1) := NULL;
		lCrtBatch	VARCHAR2 (1) := NULL;
		sBatch		batch.batch_no%TYPE := NULL;
		lSupervisor	usr.suprvsr_user_id%TYPE := NULL;
		lLbrGrp		usr.lgrp_lbr_grp%TYPE := NULL;
		e_bad_user	EXCEPTION;
		skip_rest	EXCEPTION;
		lStatus		batch.status%TYPE := NULL;
		lGetStatus	NUMBER := 0;
		iTimeSpent	NUMBER := 0;
		dtStartTime	DATE := NULL;
		-- CRQ#42225 - declaring the stop time variable
        dtStopTime     DATE := NULL;                                           

		iStatus		NUMBER := 0;
	BEGIN
		poiError := 0;

		DBMS_OUTPUT.PUT_LINE('Exiting case label screen for user [' ||
			psUser || ']'); 

		-- Get LM flag
		BEGIN
			SELECT	NVL(s.config_flag_val, 'N')
			  INTO	lLbrActive
			  FROM sys_config s
			 WHERE s.config_flag_name = 'LBR_MGMT_FLAG';
		EXCEPTION
			WHEN  OTHERS THEN
				lLbrActive := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('LM flag[' || lLbrActive || ']');

		-- Get LM create batch flag
		BEGIN
			SELECT	NVL(s.create_batch_flag, 'N')
			  INTO	lCrtBatch
			  FROM lbr_func s
			 WHERE s.lfun_lbr_func = 'LD';
		EXCEPTION
			WHEN  OTHERS THEN
				lCrtBatch := 'N';
		END;
		DBMS_OUTPUT.PUT_LINE('CrtBatch flag[' || lCrtBatch || ']');

		-- Don't need to do anything if LM related flags are not set
		IF lLbrActive = 'N' OR lCrtBatch = 'N' THEN
			RAISE skip_rest;
		END IF;

		BEGIN
			SELECT	suprvsr_user_id, lgrp_lbr_grp
			  INTO	lSupervisor, lLbrGrp
			  FROM	usr
			 WHERE	user_id = 'OPS$' || psUser;

			DBMS_OUTPUT.PUT_LINE('Supervisor[' || lSupervisor ||
				'] lbrGrp[ ' || lLbrGrp || ']');
			IF lSupervisor IS NULL OR lLbrGrp IS NULL THEN
				lSuccess := 'N';
			END IF;
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Cannot find supervisor ' ||
					'for ' || psUser);
				lSuccess := 'N';
		END;
		IF lSuccess = 'N' THEN
			RAISE e_bad_user;
		END IF;

		-- Retrieve active batch for user
		BEGIN
			SELECT	b.batch_no, b.actl_start_time
			  INTO	sBatch, dtStartTime
			  FROM	batch b
			 WHERE	b.user_id = psUser
			   AND	b.status = 'A'
			   AND	b.actl_start_time = (SELECT MAX(actl_start_time)
					FROM batch b2
		 			WHERE	b2.user_id = psUser
					  AND	b2.status = 'A');
		EXCEPTION
			WHEN OTHERS THEN
				DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
					': Error getting active batch for ' ||
					'user[' || psUser || ']');
				sBatch := NULL;
				dtStartTime := NULL;
				lStatus := 'F';
		END;
		DBMS_OUTPUT.PUT_LINE('Active batch [' || sBatch ||
			'] user[' || psUser || ' status[' || lStatus || ']'||
                        'Start Time ['|| to_char(dtStartTime,'mm/dd/rr hh24:mi:ss') ||']');

		-- No active batch is found. Try to get it from psData1 and
		-- psData2
		IF sBatch IS NULL THEN
			sBatch := get_loader_batch(psData1, NULL);
		END IF;

		-- No batch is active for user. Do nothing.
		IF lStatus <> 'A' THEN
		          --CRQ#42225 Added the below query to fetch the stop time of the last completed batch 
                BEGIN
                    SELECT b.batch_no, b.actl_stop_time, b.status
                    INTO sBatch, dtStopTime, lStatus
                    FROM batch b
                    WHERE b.user_id = psUser
                    AND b.status = 'C'
                    AND b.actl_stop_time =
                              (SELECT MAX (actl_stop_time)
                                 FROM batch b2
                                WHERE b2.user_id = psUser AND b2.status = 'C');
                EXCEPTION
                WHEN OTHERS
                THEN
                DBMS_OUTPUT.put_line (   TO_CHAR (SQLCODE)
                                  || ': Error getting complete batch for '
                                  || 'user['
                                  || psUser
                                  || ']'
                                 );
                sBatch := NULL;
                dtStopTime := NULL;
                lStatus := 'F';
                END;

                DBMS_OUTPUT.put_line (   'Complete batch ['
                            || sBatch
                            || '] user['
                            || psUser
                            || ' status['
                            || lStatus
                            || ']'
                            || 'Stop Time ['
                            || TO_CHAR (dtStopTime, 'mm/dd/rr hh24:mi:ss')
                            || ']'
                           );

			-- CRQ#42225  calling create_ilexit with the stop time of the completed batch if not with the sysdate
                create_ilexit ('ILCEXT',
                        psUser,
                        sBatch,
                        NVL(dtStopTime,SYSDATE),
                        poiError,
                        psData1
                       );

			RAISE skip_rest;
		END IF;

		IF sBatch LIKE 'LC%' THEN
			-- This batch is an active case loader batch
			BEGIN
				DELETE batch
				WHERE batch_no = sBatch
				AND   status = 'A';
			EXCEPTION
				WHEN OTHERS THEN
					DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
						': Cannot delete loader ' ||
						'batch ' || sBatch);
			END;
		ELSE
			-- Not a case loader batch. Complete it
			pl_lm1.create_schedule (sBatch, SYSDATE, iTimeSpent);
		END IF;

		-- Create indirect exit
		/*CRQ#42225 - added this below query again to fetch the stop time of the completed batch in case if any batch would have got
		completed as a result of 'create_schedule' called above */
		BEGIN
                    SELECT b.batch_no, b.actl_stop_time, b.status
                    INTO sBatch, dtStopTime, lStatus
                    FROM batch b
                    WHERE b.user_id = psUser
                    AND b.status = 'C'
                    AND b.actl_stop_time =
                              (SELECT MAX (actl_stop_time)
                                 FROM batch b2
                                WHERE b2.user_id = psUser AND b2.status = 'C');
                EXCEPTION
                WHEN OTHERS
                THEN
                DBMS_OUTPUT.put_line (   TO_CHAR (SQLCODE)
                                  || ': Error getting complete batch for '
                                  || 'user['
                                  || psUser
                                  || ']'
                                 );
                sBatch := NULL;
                dtStopTime := NULL;
                lStatus := 'F';
                END;

                DBMS_OUTPUT.put_line (   'Complete batch ['
                            || sBatch
                            || '] user['
                            || psUser
                            || ' status['
                            || lStatus
                            || ']'
                            || 'Stop Time ['
                            || TO_CHAR (dtStopTime, 'mm/dd/rr hh24:mi:ss')
                            || ']'
                           );

		-- CRQ#42225  calling create_ilexit with the stop time of the completed batch if not with the sysdate
                create_ilexit ('ILCEXT',
                        psUser,
                        sBatch,
                        NVL(dtStopTime,SYSDATE),
                        poiError,
                        psData1
                       );

	EXCEPTION
		WHEN e_bad_user THEN
			poiError := ERR_LM_BAD_USER;
			DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
				'User ' || psUser ||
				' is not set up in Labor Management');
		WHEN skip_rest THEN
			NULL;
		WHEN OTHERS THEN
			poiError := ERR_LM_BAD_USER;
	END exit_case_label;
--  02/25/10  - 12554 - tsow0456  - 
--    Added for 212 Enh - SCE017 -  Begin    
--     Creates LM batch when a stop is moved
    PROCEDURE LoadStop (psTruck      las_pallet.truck%type,
            psOrderSeq   las_case.order_seq%type,
            pStatus      OUT INTEGER) IS

        sSupervisor        usr.SUPRVSR_USER_ID%type;
        lFloatNo        floats.float_no%type;
        lBatchNo        batch.batch_no%type;
        sJobCode         batch.jbcd_job_code%TYPE := NULL;
        lStopNo         float_detail.stop_no%type;
        iError number := 0;
        seqnumber number := 0;
        exist_case number := 0;
        dtStop DATE := NULL;        
        iStatus    NUMBER := 0;
        iNumItems NUMBER := 0.0;
        iNumCases NUMBER := 0.0; 
        iNumSplits NUMBER := 0.0;
        iNumMerges NUMBER := 0.0;
        iNumDataCapt NUMBER := 0.0;
        iSpltWt NUMBER := 0.0;
        iSpltCube NUMBER := 0.0;
        iCaseWt NUMBER := 0.0;
        iCaseCube NUMBER := 0.0;
        iNumPieces NUMBER := 0.0; 
        iTotCube NUMBER := 0.0;
        iTotWt NUMBER := 0.0;
        iTotCount NUMBER := 0.0;
        iTemp NUMBER := 0.0;
        
    BEGIN
        pStatus := 0;
        -- Get supervisor id
        BEGIN
            SELECT NVL (REPLACE (suprvsr_user_id, 'OPS$', ''), 'NOMGR')
            INTO sSupervisor
            FROM usr
            WHERE REPLACE (user_id, 'OPS$', '') = REPLACE (USER, 'OPS$', '');
        EXCEPTION
        WHEN OTHERS THEN
           sSupervisor := 'NOMGR';
        END;        
        -- Get float number
        lFloatNo := f_GetFloatNo_2 (psTruck, psOrderSeq);

        IF ((lFloatNo = 0) OR (lFloatNo IS NULL)) THEN
            pStatus := ERR_NO_CASE_DROP_INFO;
            dbms_output.put_line('Could not get FloatNo;sqlcode[' || to_char(sqlcode) ||
                '];ErrMsg=[' || sqlerrm || ']');
            RETURN;
        END IF;        
        -- Start batch
        CreateISTART(REPLACE(USER, 'OPS$', ''),
        'L' || TO_CHAR(lFloatNo), iError);
        dbms_output.put_line(' Inside load stop = '||
        ' Float number = '||lFloatNo||' OrderSeq = '||
        psOrderSeq ||' Truck = '|| psTruck);
        
        -- Complete previous batch
        iStatus := CompletePreviousBatch(dtStop);
        IF iStatus <> 0 THEN
            pStatus := ERR_LM_SCHED_NOT_FOUND;
            DBMS_OUTPUT.PUT_LINE('LoadStop: CompletePreviousBatch error[' ||  TO_CHAR(iStatus) || ']');    
            RETURN;
        END IF;
        -- Fetch stop number for this order sequence
        BEGIN
            SELECT d.stop_no INTO lStopNo
            FROM float_detail d
            WHERE d.order_seq = psOrderSeq
                AND d.float_no = lFloatNo;
        EXCEPTION
        WHEN OTHERS THEN
            dbms_output.put_line('Could not get stop;sqlcode[' || to_char(sqlcode) ||
                '];ErrMsg=[' || sqlerrm || ']');
        END;
        -- Get the values to be inserted into the batch table
        BEGIN
            SELECT 
                m.load_job_code, 
                SUM(DECODE(d.merge_alloc_flag, 
                            'M', 0,
                            'S', 0,
                            DECODE(uom, 1, d.qty_alloc, 0) ) ) as numSplits, 
                SUM(DECODE(d.merge_alloc_flag,
                            'M', 0,
                            'S', 0,
                            DECODE(uom, 2, d.qty_alloc/nvl(p.spc,1), 
                                null, d.qty_alloc/nvl(p.spc,1), 0) ) ) as numCases, 
                SUM(DECODE(d.merge_alloc_flag, 
                                'M', DECODE(uom, 2, d.qty_alloc/nvl(p.spc,1), 1, d.qty_alloc, 0),
                                'S', 0,
                        0 ) ) as numMerges, 
                SUM(DECODE(p.catch_wt_trk, 'Y', DECODE(uom,1,d.qty_alloc,d.qty_alloc/nvl(spc,1)),0) ) as numDataCapt, 
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(uom,1,d.qty_alloc*(p.g_weight/nvl(p.spc,1)),0) ) ) as spltWt, 
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(uom,1,d.qty_alloc*p.split_cube,0) ) ) as spltCube,
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(uom,2,d.qty_alloc*(p.g_weight/nvl(p.spc,1)), null, d.qty_alloc*(p.g_weight/nvl(p.spc,1)), 0) ) ) as caseWt,
                SUM(DECODE(d.merge_alloc_flag,'M',0,'S',0,DECODE(uom,2,(d.qty_alloc/nvl(p.spc,1))*p.case_cube, null, (d.qty_alloc/nvl(p.spc,1))*p.case_cube, 0) ) ) as caseCube,
                COUNT(DISTINCT d.prod_id||d.cust_pref_vendor) as numItems
            INTO 
                sJobCode, iNumSplits, iNumCases, 
                iNumMerges, iNumDataCapt, 
                iSpltWt, iSpltCube, iCaseWt, iCaseCube, 
                iNumItems
            FROM 
                sel_method m, floats f, 
                float_detail d, route r, pm p
            WHERE 
                m.method_id = r.method_id
                AND m.group_no = f.group_no
                AND f.float_no = d.float_no
                AND d.stop_no = lStopNo
                AND d.float_no = lFloatNo
                AND f.pallet_pull IN ('B', 'N', 'Y')
                AND f.route_no = r.route_no
                AND d.prod_id = p.prod_id
                AND d.cust_pref_vendor = p.cust_pref_vendor
            GROUP BY 
                m.load_job_code;
        EXCEPTION
        WHEN OTHERS THEN
            sJobCode := NULL;
            iTotCube := 0.0;
            iTotWt := 0.0;
        END;
        -- calculate total cube, weight, pieces
        iNumPieces := iNumCases + iNumSplits + iNumMerges;
        iTotWt := iCaseWt + iSpltWt;
        iTotCube := iCaseCube + iSpltCube;
        
        BEGIN
            INSERT INTO batch
            (batch_no, batch_date, status, 
            user_id, user_supervsr_id, jbcd_job_code, 
            ref_no, actl_start_time, goal_time, target_time,
            kvi_cube, kvi_wt, kvi_no_piece, kvi_no_case, kvi_no_split,
            kvi_no_merge, kvi_no_item, kvi_no_stop, kvi_no_pallet,
	    cmt
            )
            VALUES 
            ('LC' || TO_CHAR(seq1.nextval), TRUNC(SYSDATE), 'A',
            REPLACE(USER, 'OPS$', ''), sSupervisor, sJobCode, 
	    lStopNo, NVL(dtStop, SYSDATE), 0, 0,
            iTotCube, iTotWt, iNumPieces, iNumCases, iNumSplits, 
            iNumMerges, iNumItems, 1, 0,
	    lFloatNo
            );
            
            DBMS_OUTPUT.PUT_LINE('LoadStop:Insert into batch completed SQLCode['|| TO_CHAR(sqlcode) || 
            '];Message[' ||  sqlerrm || 
            '];Rows Affected[' || TO_CHAR(SQL%ROWCOUNT) || ']');
            
            IF (SQL%ROWCOUNT = 0) THEN
                dbms_output.put_line('No rows inserted into batch;sqlcode[' || to_char(sqlcode) ||
                '];ErrMsg=[' || sqlerrm || ']');
                RAISE NO_LM_BATCH_FOUND;
            ELSE
            -- Less the kvi values for this float after the stop is moved into
            -- another float or zone            
            UPDATE batch 
            SET
                kvi_cube =  kvi_cube - iTotCube, 
                kvi_wt = kvi_wt -  iTotWt,
                kvi_no_piece = kvi_no_piece - iNumPieces, 
                kvi_no_case = kvi_no_case - iNumCases, 
                kvi_no_split = kvi_no_split - iNumSplits,
                kvi_no_merge = kvi_no_merge - iNumMerges, 
                kvi_no_item = kvi_no_item - iNumItems, 
                kvi_no_stop = kvi_no_stop - 1 -- since a single stop is moved                            
            WHERE 
                batch_no = 'L' || TO_CHAR(lFloatNo)                
                AND status NOT IN ('C');
                
            DBMS_OUTPUT.PUT_LINE('LoadStop:Update for float being moved completed SQLCode['|| TO_CHAR(sqlcode) || 
            '];Message[' ||  sqlerrm || 
            '];Rows Affected[' || TO_CHAR(SQL%ROWCOUNT) || ']');                

            END IF;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pStatus := ERR_NO_LM_BATCH;    
            dbms_output.put_line('No Data Found;sqlcode[' || to_char(sqlcode) ||
                '];ErrMsg=[' || sqlerrm || ']');
        WHEN OTHERS THEN
            pStatus := ERR_LM_BATCH_UPD_FAIL;
            dbms_output.put_line('Insert into batch Failed;sqlcode[' || to_char(sqlcode) ||
                '];ErrMsg=[' || sqlerrm || ']');
        END;
END LoadStop;
    
--    Completes LM batch when a stop is moved
PROCEDURE exit_stop (
        psUser      IN  batch.user_id%TYPE,
        psData1      IN  VARCHAR2,
        poiError  OUT NUMBER)
IS
        lSuccess    VARCHAR2 (1) := 'Y';
        lLbrActive    VARCHAR2 (1) := NULL;
        lCrtBatch    VARCHAR2 (1) := NULL;
        sBatch        batch.batch_no%TYPE := NULL;
        lSupervisor    usr.suprvsr_user_id%TYPE := NULL;
        lLbrGrp        usr.lgrp_lbr_grp%TYPE := NULL;
        e_bad_user    EXCEPTION;
        skip_rest    EXCEPTION;
        lStatus        batch.status%TYPE := NULL;
        lGetStatus    NUMBER := 0;
        iTimeSpent    NUMBER := 0;
        dtStartTime    DATE := NULL;
		--CRQ#42225 - declaring stop time variable
        dtStopTime    DATE  := NULL;
        iStatus        NUMBER := 0;
BEGIN
    poiError := 0;
    
    pl_log.ins_msg('WARN', 'exit_stop','Execution Begins;Input:' || 
    'UserId[' || psUser ||
    '];OrderSeq[' || psData1 ||
    '];D:' ||
    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
    NULL, NULL);
    -- Get LM flag
    BEGIN
        SELECT    NVL(s.config_flag_val, 'N')
        INTO    lLbrActive
        FROM sys_config s
        WHERE s.config_flag_name = 'LBR_MGMT_FLAG';
    EXCEPTION
    WHEN  OTHERS THEN
        lLbrActive := 'N';
    END;
    DBMS_OUTPUT.PUT_LINE('LM flag[' || lLbrActive || ']');
    pl_log.ins_msg('WARN', 'exit_stop','LM Flag:[' || lLbrActive ||
    '];D:' ||
    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
    NULL, NULL);
    -- Get LM create batch flag
    BEGIN
        SELECT    NVL(s.create_batch_flag, 'N')
        INTO    lCrtBatch
        FROM lbr_func s
        WHERE s.lfun_lbr_func = 'LD';
    EXCEPTION
    WHEN  OTHERS THEN
        lCrtBatch := 'N';
    END;
    DBMS_OUTPUT.PUT_LINE('CrtBatch flag[' || lCrtBatch || ']');
    pl_log.ins_msg('WARN', 'exit_stop','LM Create Batch Flag:[' || lCrtBatch ||
    '];D:' ||
    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
    NULL, NULL);
    -- Don't need to do anything if LM related flags are not set
    IF lLbrActive = 'N' OR lCrtBatch = 'N' THEN
        RAISE skip_rest;
    END IF;

    BEGIN
        SELECT    suprvsr_user_id, lgrp_lbr_grp
        INTO    lSupervisor, lLbrGrp
        FROM    usr
        WHERE    user_id = 'OPS$' || psUser;

        DBMS_OUTPUT.PUT_LINE('Supervisor[' || lSupervisor ||
            '] lbrGrp[ ' || lLbrGrp || ']');
        IF lSupervisor IS NULL OR lLbrGrp IS NULL THEN
            lSuccess := 'N';
        END IF;
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
            ': Cannot find supervisor ' ||
            'for ' || psUser);
        lSuccess := 'N';
    END;    
    pl_log.ins_msg('WARN', 'exit_stop','Get Supervisor, LbrGroup;' ||
    'Supervisor[' || lSupervisor || 
    '];LbrGroup[' || lLbrGrp || 
    '];LSuccess[' || lSuccess || 
    '];D:' ||
    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
    NULL, NULL);
    
    IF lSuccess = 'N' THEN
        RAISE e_bad_user;
    END IF;

    -- Retrieve active batch for user
    BEGIN
        SELECT    b.batch_no, b.actl_start_time
        INTO    sBatch, dtStartTime
        FROM    batch b
        WHERE    b.user_id = psUser
        AND    b.status = 'A'
        AND    b.actl_start_time = (SELECT MAX(actl_start_time)
            FROM batch b2
            WHERE    b2.user_id = psUser
            AND    b2.status = 'A');
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
            ': Error getting active batch for ' ||
            'user[' || psUser || ']');
        sBatch := NULL;
        dtStartTime := NULL;
        lStatus := 'F';        
        pl_log.ins_msg('WARN', 'exit_stop','Select Active batch Failed for ' || 
        'User[' || psUser ||         
        '];SQLCode[' || TO_CHAR(sqlcode) ||
        '];Status[' || lStatus ||
        '];D:' ||
        TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
        NULL, NULL);
    END;
    DBMS_OUTPUT.PUT_LINE('Active batch [' || sBatch ||
        '] user[' || psUser || ' status[' || lStatus || ']'||
        'Start Time ['|| TO_CHAR(dtStartTime,'mm/dd/rr hh24:mi:ss') ||']');

    -- No active batch is found. Try to get it from psData1 and
    -- psData2
    IF sBatch IS NULL THEN
        sBatch := get_loader_batch(psData1, NULL);
    END IF;
    
    pl_log.ins_msg('WARN', 'exit_stop','Select Active batch for ' || 
    'User[' || psUser || 
    '];Status[' || lStatus ||
    '];Batch[' || sBatch ||
    '];Start Time[' || TO_CHAR(dtStartTime,'mm/dd/rr hh24:mi:ss') ||
    ']; D: ' ||
    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
    NULL, NULL);

    -- No batch is active for user. Do nothing.
    IF lStatus <> 'A' THEN
	-- CRQ#42225 - added the below query to fetch the stop time of the last completed batch
            BEGIN
                SELECT b.batch_no, b.actl_stop_time, b.status
                INTO sBatch, dtStopTime, lStatus
                FROM batch b
                WHERE b.user_id = psUser
                AND b.status = 'C'
                AND b.actl_stop_time =
                              (SELECT MAX (actl_stop_time)
                                 FROM batch b2
                                WHERE b2.user_id = psUser AND b2.status = 'C');
            EXCEPTION
            WHEN OTHERS THEN
                        DBMS_OUTPUT.put_line (   TO_CHAR (SQLCODE)
                                  || ': Error getting complete batch for '
                                  || 'user['
                                  || psUser
                                  || ']'
                                 );
            sBatch := NULL;
            dtStopTime := NULL;
            lStatus := 'F';
            pl_log.ins_msg ('WARN',
                            'exit_stop',
                               'Select Complete batch Failed for '
                            || 'User['
                            || psUser
                            || '];SQLCode['
                            || TO_CHAR (SQLCODE)
                            || '];Status['
                            || lStatus
                            || '];D:'
                            || TO_CHAR (SYSDATE, 'MM/DD/RR HH24:MI:SS'),
                            NULL,
                            NULL
                           );
            END;

        DBMS_OUTPUT.put_line (   'Complete batch ['
                            || sBatch
                            || '] user['
                            || psUser
                            || ' status['
                            || lStatus
                            || ']'
                            || 'Stop Time ['
                            || TO_CHAR (dtStopTime, 'mm/dd/rr hh24:mi:ss')
                            || ']'
                           );
-- CRQ#42225 avij3336 calling 'create_ilexit' with the stop time of last completed batch if not with the sysdate
        create_ilexit ('ILCEXT',
                        psUser,
                        sBatch,
                        NVL(dtStopTime,SYSDATE),
                        poiError,
                        psData1
                       );

        RAISE skip_rest;
    END IF;

    IF sBatch LIKE 'LC%' THEN    
        pl_log.ins_msg('WARN', 'exit_stop','Select Active batch for ' || 
        'User[' || psUser || 
        '];Status[' || lStatus ||
        '];Batch[' || sBatch ||
        '];Start Time[' || TO_CHAR(dtStartTime,'mm/dd/rr hh24:mi:ss') ||
        '];D:' ||
        TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
        NULL, NULL);
        -- This batch is an active case loader batch
        BEGIN
            DELETE batch
            WHERE batch_no = sBatch
            AND   status = 'A';
        EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
            ': Cannot delete loader ' ||
            'batch ' || sBatch);
            pl_log.ins_msg('WARN', 'exit_stop','Delete batch failed for' || 
            'User[' || psUser || 
            '];Batch[' || sBatch || 
            '];SQLCode[' || TO_CHAR(sqlcode) ||                    
            '];D:' ||
            TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
            NULL, NULL);
        END;
    ELSE
        -- Not a case loader batch. Complete it
        pl_log.ins_msg('WARN', 'exit_stop','Not Case Load;Complete Batch' || 
        'User[' || psUser || 
        '];Batch[' || sBatch ||             
        '];D:' ||
        TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
        NULL, NULL);
        pl_lm1.create_schedule (sBatch, SYSDATE, iTimeSpent);
    END IF;
    -- Create indirect exit
    -- Get start time from previous batch
   /*create_ilexit('ILCEXT', psUser, sBatch, dtStartTime, poiError,
        psData1);*/
		/*CRQ#42225 - added this below query again to fetch the stop time of the completed batch in case if any batch would have got
completed as a result of 'create_schedule' called above */
        -- CRQ#42225 - added the below query to fetch the stop time of the last completed batch
            BEGIN
                SELECT b.batch_no, b.actl_stop_time, b.status
                INTO sBatch, dtStopTime, lStatus
                FROM batch b
                WHERE b.user_id = psUser
                AND b.status = 'C'
                AND b.actl_stop_time =
                              (SELECT MAX (actl_stop_time)
                                 FROM batch b2
                                WHERE b2.user_id = psUser AND b2.status = 'C');
            EXCEPTION
            WHEN OTHERS THEN
                        DBMS_OUTPUT.put_line (   TO_CHAR (SQLCODE)
                                  || ': Error getting complete batch for '
                                  || 'user['
                                  || psUser
                                  || ']'
                                 );
            sBatch := NULL;
            dtStopTime := NULL;
            lStatus := 'F';
            pl_log.ins_msg ('WARN',
                            'exit_stop',
                               'Select Complete batch Failed for '
                            || 'User['
                            || psUser
                            || '];SQLCode['
                            || TO_CHAR (SQLCODE)
                            || '];Status['
                            || lStatus
                            || '];D:'
                            || TO_CHAR (SYSDATE, 'MM/DD/RR HH24:MI:SS'),
                            NULL,
                            NULL
                           );
            END;

        DBMS_OUTPUT.put_line (   'Complete batch ['
                            || sBatch
                            || '] user['
                            || psUser
                            || ' status['
                            || lStatus
                            || ']'
                            || 'Stop Time ['
                            || TO_CHAR (dtStopTime, 'mm/dd/rr hh24:mi:ss')
                            || ']'
                           );

		-- CRQ#42225 avij3336 calling 'create_ilexit' with the stop time of last completed batch if not with the sysdate
		create_ilexit ('ILCEXT',
                        psUser,
                        sBatch,
                        NVL(dtStopTime,SYSDATE),
                        poiError,
                        psData1
                       );

EXCEPTION
WHEN e_bad_user THEN
    poiError := ERR_LM_BAD_USER;
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQLCODE) ||
        'User ' || psUser ||
        ' is not set up in Labor Management');
WHEN skip_rest THEN
    NULL;
WHEN OTHERS THEN
    poiError := ERR_LM_BAD_USER;
    pl_log.ins_msg('WARN', 'exit_stop','Exception occurred' || 
    'SQLCode[' || TO_CHAR(SQLCODE) || 
    '];D:' ||
    TO_CHAR(SYSDATE, 'MM/DD/RR HH24:MI:SS'),
    NULL, NULL);
END exit_stop ;
--    02/25/10  - 12554 - tsow0456  - 
--    Added for 212 Enh - SCE017 -  End  

END pl_sos_sls_lm;
/
SHOW ERRORS;
--CREATE OR REPLACE PUBLIC SYNONYM pl_sos_sls_lm FOR pl_sos_sls_lm
--/
--GRANT EXECUTE ON pl_sos_sls_lm TO swms_user
--/
