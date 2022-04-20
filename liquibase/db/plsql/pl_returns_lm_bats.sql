CREATE OR REPLACE PACKAGE pl_returns_lm_bats AS
/*******************************************************************************

**Package:

**        pl_returns_lm_bats. Migrated from returns_lm_bats.pc

**

**Description:

**        Creates Returns Putaway Labor Management Batches.

**		logic for print_pallet_batch will be handled in pre_putaway Java wrapper.

**

**Called by:

**        This is a common package called from many other programs

*******************************************************************************/

    FUNCTION find_pallet_batch (
        o_pallet_batch_no       OUT batch.batch_no%TYPE,
        o_pallet_batch_no_len   OUT NUMBER,
        i_prc_seq_no            IN 	NUMBER,
        i_credit_memo           IN 	VARCHAR2,
        o_batch_cube            OUT NUMBER
    ) RETURN NUMBER;

    FUNCTION create_pallet_batch (
        o_pallet_batch_no       OUT batch.batch_no%TYPE,
        o_pallet_batch_no_len   OUT NUMBER,
        i_prc_seq_no            IN NUMBER,
        i_job_code              IN VARCHAR2,
        i_credit_memo           IN VARCHAR2
    ) RETURN NUMBER;

    FUNCTION attach_line_item_to_batch (
        i_pallet_batch_no   IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_id         IN putawaylst.pallet_id%TYPE,
        i_credit_memo       IN VARCHAR2
    ) RETURN NUMBER;

    FUNCTION load_pallet_batch (
        i_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER;

    FUNCTION close_pallet_batch (
        i_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER;

    FUNCTION delete_pallet_batch (
        i_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER;

    FUNCTION unload_pallet_batch (
        i_cur_pallet_batch_no       IN batch.batch_no%TYPE,
        i_cur_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER;

    FUNCTION move_puts_to_batch (
        i_cur_pallet_batch_no       IN batch.batch_no%TYPE,
        i_cur_pallet_batch_no_len   IN NUMBER,
        i_new_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_new_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER;

    FUNCTION create_default_rtn_lm_batch (
        i_user_id    IN batch.user_id%TYPE,
        i_batch_no   IN batch.batch_no%TYPE
    ) RETURN NUMBER;

END pl_returns_lm_bats;
/

CREATE OR REPLACE PACKAGE BODY pl_returns_lm_bats AS

    ORACLE_NOT_FOUND       CONSTANT NUMBER := 1403;
    ORACLE_NORMAL          CONSTANT NUMBER := 0;
    NO_LM_BATCH_FOUND      CONSTANT NUMBER := 146;
    CTE_RTN_BTCH_FLG_OFF   CONSTANT NUMBER := 144;
	UPD_FAIL 			   CONSTANT NUMBER :=1;
	
  /**********************************+**************************************
  **  FUNCTION:  find_pallet_batch
  **
  **  DESCRIPTION - Function that finds an open returns putaway batch for
  **                the attachment of putawaylst records on credit memos.
  **
  **  PARAMETERS:
  **    o_pallet_batch_no - pointer to buffer to write the existing batch
  **                        matching seq no and job code.
  **    o_pallet_batch_no_len - pointer to buffer containing batch field length.
  **    i_prc_seq_no - Sequence identifier from the PRC table.  (ref field)
  **    job_code - Job code from the PRC table.  (jobcode field)
  **    credit_memo - The return being processed (for aplog)
  ***********************************-*************************************/

    FUNCTION find_pallet_batch (
        o_pallet_batch_no       OUT batch.batch_no%TYPE,
        o_pallet_batch_no_len   OUT NUMBER,
        i_prc_seq_no            IN NUMBER,
        i_credit_memo           IN VARCHAR2,
        o_batch_cube            OUT NUMBER
    ) RETURN NUMBER IS

        l_func_name          VARCHAR2(50) := 'find_pallet_batch';
        l_status             NUMBER := ORACLE_NORMAL;
        l_pallet_batch_no    VARCHAR2(13) := ' ';
        l_total_batch_cube   NUMBER := 0.0;
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside find_pallet_batch, credit_memo = ' ||i_credit_memo, sqlcode, sqlerrm);                   
        BEGIN
            SELECT
                b.batch_no
            INTO l_pallet_batch_no
            FROM
                batch b
            WHERE
                b.ref_no = TO_CHAR(i_prc_seq_no)
                AND b.status = 'X'
                AND b.batch_no >= 'T'
                AND b.batch_no < 'U';

          /*
          **  No reason to check status of this query.
          */

            BEGIN
                SELECT
                    SUM(p.qty * pm.case_cube / pm.spc)
                INTO l_total_batch_cube
                FROM
                    pm,
                    putawaylst p
                WHERE
                    pm.prod_id = p.prod_id
                    AND pm.cust_pref_vendor = p.cust_pref_vendor
                    AND p.pallet_batch_no = l_pallet_batch_no
                GROUP BY
                    p.pallet_batch_no;

                o_pallet_batch_no_len := length(l_pallet_batch_no);
                o_pallet_batch_no := l_pallet_batch_no;
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to find total_batch_cube for pallet_batch_no = ' || l_pallet_batch_no, 
                    sqlcode, sqlerrm);
            END;

        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to find batch for sequence on credit memo.prc_seq_no = '
                                                    || i_prc_seq_no
                                                    || ' credit_memo = '
                                                    || i_credit_memo, sqlcode, sqlerrm);

                l_status := sqlcode;
        END;

        o_batch_cube := l_total_batch_cube;
        RETURN l_status;
    END find_pallet_batch;
	
  /**********************************+**************************************
  **  FUNCTION:  create_pallet_batch
  **
  **  DESCRIPTION - Function creates a returns batch.
  **
  **  PARAMETERS:
  **    o_pallet_batch_no - pointer to buffer to write the new batch.
  **    o_pallet_batch_no_len - pointer to buffer containing batch field length.
  **    i_prc_seq_no - Sequence identifier from the PRC table.  (ref field)
  **    i_job_code - Job code from the PRC table.  (jobcode field)
  **    credit_memo - The return being processed (for aplog)
  ***********************************-*************************************/

    FUNCTION create_pallet_batch (
        o_pallet_batch_no       OUT batch.batch_no%TYPE,
        o_pallet_batch_no_len   OUT NUMBER,
        i_prc_seq_no            IN NUMBER,
        i_job_code              IN VARCHAR2,
        i_credit_memo           IN VARCHAR2
    ) RETURN NUMBER IS

        l_status            NUMBER := ORACLE_NORMAL;
        l_pallet_batch_no   VARCHAR2(13);
        l_func_name         VARCHAR2(50) := 'create_pallet_batch';
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside create_pallet_batch', sqlcode, sqlerrm);
        l_pallet_batch_no := ' ';
        BEGIN
            SELECT
                'T'
                || ltrim(TO_CHAR(pallet_batch_no_seq.NEXTVAL) )
            INTO l_pallet_batch_no
            FROM
                dual;

            BEGIN
                INSERT INTO batch (
                    batch_no,
                    batch_date,
                    status,
                    ref_no,
                    jbcd_job_code
                ) VALUES (
                    l_pallet_batch_no,
                    trunc(SYSDATE),
                    'X',
                    ltrim(TO_CHAR(i_prc_seq_no) ),
                    i_job_code
                );

              /*
              **  Return batch number to calling routine.
              */

                o_pallet_batch_no_len := length(l_pallet_batch_no);
                o_pallet_batch_no := l_pallet_batch_no;
                pl_text_log.ins_msg_async('INFO', l_func_name, 'New pallet batch created.pallet_batch_no = ' || l_pallet_batch_no, sqlcode, sqlerrm);
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to create returns batch for credit memo.pallet_batch_no = '
                                                        || l_pallet_batch_no
                                                        || ' credit_memo = '
                                                        || i_credit_memo, sqlcode, sqlerrm);

                    l_status := sqlcode;
            END;
            
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to create pallet_batch_no for credit memo.
								credit_memo = ' || i_credit_memo, sqlcode, sqlerrm);               
                l_status := sqlcode;
                RETURN l_status;
        END;
		RETURN l_status;
    END create_pallet_batch;
	
  /**********************************+**************************************
  **  FUNCTION:  attach_line_item_to_batch
  **
  **  DESCRIPTION - Function sets the pallet_batch_no field of the specified
  **                pallet to the specified batch.
  **
  **  PARAMETERS:
  **    i_pallet_batch_no - the batch number to attach to.
  **    i_pallet_id - Pallet being processed.
  **    credit_memo - Return being processed.  (for pl_log)
  ***********************************-*************************************/

    FUNCTION attach_line_item_to_batch (
        i_pallet_batch_no   IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_id         IN putawaylst.pallet_id%TYPE,
        i_credit_memo       IN VARCHAR2
    ) RETURN NUMBER IS
        l_func_name   VARCHAR2(50) := 'attach_line_item_to_batch';
        l_status      NUMBER := ORACLE_NORMAL;
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, 'Inside attach_line_item_to_batch', sqlcode, sqlerrm);
        UPDATE putawaylst
        SET
            pallet_batch_no = i_pallet_batch_no
        WHERE
            pallet_id = i_pallet_id;
		RETURN l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to update batch in putaway task on credit memo.
												credit_memo = '
                                                || i_credit_memo
                                                || ' pallet_batch_no = '
                                                || i_pallet_batch_no, sqlcode, sqlerrm);

            l_status := UPD_FAIL;
            RETURN l_status;
    END attach_line_item_to_batch;
	
  /**********************************+**************************************
  **  FUNCTION:  load_pallet_batch
  **
  **  DESCRIPTION - Function sets the KVI values in the batch record.
  **
  **  PARAMETERS:
  **    i_pallet_batch_no - the batch number of batch to load.
  **    i_pallet_batch_no_len - length of pallet batch no field.
  ***********************************-*************************************/

    FUNCTION load_pallet_batch (
        i_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER IS

        l_func_name      VARCHAR2(50) := 'load_pallet_batch';
        l_status         NUMBER := ORACLE_NORMAL;
        l_num_locs       NUMBER := 0;
        l_num_items      NUMBER := 0;
        l_num_pieces     NUMBER := 0;
        l_num_cases      NUMBER := 0;
        l_num_splits     NUMBER := 0;
        l_num_aisles     NUMBER := 0;
        l_num_pallets    NUMBER := 0;
        l_num_pos        NUMBER := 0;
        l_total_cube     NUMBER := 0.0;
        l_total_weight   NUMBER := 0.0;
    BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, ' processing batch.pallet_batch_no = ' || i_pallet_batch_no, sqlcode, sqlerrm);
						
        SELECT
            SUM(y.qty * (p.case_cube / p.spc) ),
            SUM(y.qty * p.avg_wt),
            COUNT(*),
            COUNT(DISTINCT y.prod_id),
            COUNT(DISTINCT y.dest_loc),
            SUM(DECODE(y.uom,0, (y.qty / p.spc),0) ),
            SUM(DECODE(y.uom,1,y.qty,0) ),
            COUNT(DISTINCT substr(y.dest_loc,1,2) ),
            COUNT(DISTINCT y.rec_id)
        INTO
            l_total_cube,
            l_total_weight,
            l_num_pallets,
            l_num_items,
            l_num_locs,
            l_num_cases,
            l_num_splits,
            l_num_aisles,
            l_num_pos
        FROM
            pm p,
            putawaylst y
        WHERE
            p.prod_id = y.prod_id
            AND p.cust_pref_vendor = y.cust_pref_vendor
            AND substr(y.rec_id,1,1) IN (
                'S',
                'P',
                'D'
            )
            AND y.pallet_batch_no = i_pallet_batch_no;

        l_num_pieces := l_num_splits + l_num_cases;
        BEGIN
            UPDATE batch
            SET
                kvi_cube = l_total_cube,
                kvi_wt = l_total_weight,
                kvi_no_piece = l_num_pieces,
                kvi_no_pallet = l_num_pallets,
                kvi_no_item = l_num_items,
                kvi_no_po = l_num_pos,
                kvi_no_loc = l_num_locs,
                kvi_no_case = l_num_cases,
                kvi_no_split = l_num_splits,
                kvi_no_aisle = l_num_aisles
            WHERE
                batch_no = i_pallet_batch_no;

				pl_text_log.ins_msg_async('INFO', l_func_name,'batch_no '
                                                || i_pallet_batch_no
                                                || ' is loaded.pallet_batch_no = '										
                                                || i_pallet_batch_no, sqlcode, sqlerrm);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to update batch with KVI values on batch.
								pallet_batch_no = ' || i_pallet_batch_no, sqlcode, sqlerrm);               
                l_status := sqlcode;
        END;

        RETURN l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, ' Calculation of KVI values on completed batch failed.
								pallet_batch_no = ' || i_pallet_batch_no, sqlcode, sqlerrm);           
            l_status := UPD_FAIL;
            RETURN l_status;
    END;
	
  /**********************************+**************************************
  **  FUNCTION:  close_pallet_batch
  **
  **  DESCRIPTION - Function changes the status of the batch to 'F' or
  **                closes the batch to further additions.
  **                Calls lm_download to calculate goal times.
  **
  **  PARAMETERS:
  **    p_pallet_batch_no - the batch number to close.
  **    p_pallet_batch_no_len - length of pallet batch no field.
  ***********************************-*************************************/

    FUNCTION close_pallet_batch (
        i_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER IS
        l_func_name   VARCHAR2(50) := 'close_pallet_batch';
        l_status      NUMBER := ORACLE_NORMAL;
        l_out_status  VARCHAR2(20);
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Inside close_pallet_batch. pallet_batch_no = ' || i_pallet_batch_no, sqlcode, sqlerrm);
        l_status := load_pallet_batch(i_pallet_batch_no,i_pallet_batch_no_len);
        IF l_status = ORACLE_NORMAL THEN
            pl_batch_download.p_lm_download(i_pallet_batch_no,l_out_status);
            pl_text_log.ins_msg_async('INFO', l_func_name, ' Batch closed.download_batch = ' || i_pallet_batch_no, sqlcode, sqlerrm);
        END IF;
        IF l_out_status = 'SUCCESS' THEN
            l_status := ORACLE_NORMAL;
        ELSE
            l_out_status := 1;
        END IF;
        RETURN l_status;
    END close_pallet_batch;
  
  /**********************************+**************************************
  **  FUNCTION:  delete_pallet_batch
  **
  **  DESCRIPTION - Function deletes the specified returns batch.
  **
  **  PARAMETERS:
  **    i_pallet_batch_no - the batch number of batch to delete.
  **    i_pallet_batch_no_len - length of pallet batch no field.
  ***********************************-*************************************/

    FUNCTION delete_pallet_batch (
        i_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER IS
        l_status      NUMBER := ORACLE_NORMAL;
        l_func_name   VARCHAR2(50) := 'delete_pallet_batch';
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Inside close_pallet_batch. pallet_batch_no = ' || i_pallet_batch_no, sqlcode, sqlerrm);
        DELETE batch
        WHERE
            batch_no = i_pallet_batch_no;

        pl_text_log.ins_msg_async('INFO', l_func_name, 'returns batch deleted. pallet_batch_no = ' || i_pallet_batch_no, sqlcode, sqlerrm);
        RETURN l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to delete returns batch. pallet_batch_no = ' || i_pallet_batch_no, sqlcode, sqlerrm);
            l_status := sqlcode;
            RETURN l_status;
    END delete_pallet_batch;
	
  /**********************************+**************************************
  **  FUNCTION:  unload_pallet_batch
  **
  **  DESCRIPTION - Function subtracts the KVI values for existing putaway task
  **                from the batch record.
  **
  **  PARAMETERS:
  **    p_cur_pallet_batch_no - the current batch number from which to remove
  **                            KVI's for existing putaway tasks.
  **    p_cur_pallet_batch_no_len - length of current pallet batch no field.
  ***********************************-*************************************/

    FUNCTION unload_pallet_batch (
        i_cur_pallet_batch_no       IN batch.batch_no%TYPE,
        i_cur_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER IS

        l_func_name      VARCHAR2(50) := 'unload_pallet_batch';
        l_status         NUMBER := ORACLE_NORMAL;
        l_num_locs       NUMBER := 0;
        l_num_items      NUMBER := 0;
        l_num_pieces     NUMBER := 0;
        l_num_cases      NUMBER := 0;
        l_num_splits     NUMBER := 0;
        l_num_aisles     NUMBER := 0;
        l_num_pallets    NUMBER := 0;
        l_num_pos        NUMBER := 0;
        l_total_cube     NUMBER := 0.0;
        l_total_weight   NUMBER := 0.0;
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Inside unload_pallet_batch. cur_pallet_batch_no = ' || i_cur_pallet_batch_no, sqlcode, sqlerrm);
        SELECT
            SUM(y.qty * (p.case_cube / p.spc) ),
            SUM(y.qty * p.avg_wt),
            COUNT(*),
            COUNT(DISTINCT y.prod_id),
            COUNT(DISTINCT y.dest_loc),
            SUM(DECODE(y.uom,0, (y.qty / p.spc),0) ),
            SUM(DECODE(y.uom,1,y.qty,0) ),
            COUNT(DISTINCT substr(y.dest_loc,1,2) ),
            COUNT(DISTINCT y.rec_id)
        INTO
            l_total_cube,
            l_total_weight,
            l_num_pallets,
            l_num_items,
            l_num_locs,
            l_num_cases,
            l_num_splits,
            l_num_aisles,
            l_num_pos
        FROM
            pm p,
            putawaylst y
        WHERE
            p.prod_id = y.prod_id
            AND p.cust_pref_vendor = y.cust_pref_vendor
            AND substr(y.rec_id,1,1) IN (
                'S',
                'P',
                'D'
            )
            AND y.pallet_batch_no = i_cur_pallet_batch_no;

        l_num_pieces := l_num_splits + l_num_cases;
        BEGIN
            UPDATE batch
            SET
                kvi_cube = kvi_cube - l_total_cube,
                kvi_wt = kvi_wt - l_total_weight,
                kvi_no_piece = kvi_no_piece - l_num_pieces,
                kvi_no_pallet = kvi_no_pallet - l_num_pallets,
                kvi_no_item = kvi_no_item - l_num_items,
                kvi_no_po = kvi_no_po - l_num_pos,
                kvi_no_loc = kvi_no_loc - l_num_locs,
                kvi_no_case = kvi_no_case - l_num_cases,
                kvi_no_split = kvi_no_split - l_num_splits,
                kvi_no_aisle = kvi_no_aisle - l_num_aisles
            WHERE
                batch_no = i_cur_pallet_batch_no;
			

				pl_text_log.ins_msg_async('INFO', l_func_name, ' Removal of KVI"s for existing putaway tasks is complete. pallet_batch_no = '
												|| i_cur_pallet_batch_no, sqlcode, sqlerrm);
          
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, ' Unable to remove KVIs for existing putaway tasks from batch. pallet_batch_no = '
                || i_cur_pallet_batch_no, sqlcode, sqlerrm);
                l_status := UPD_FAIL;
        END;

        RETURN l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Calculation of KVI values on completed batch failed. pallet_batch_no = ' || i_cur_pallet_batch_no, 
            sqlcode, sqlerrm);
            l_status := sqlcode;
            RETURN l_status;
    END unload_pallet_batch;
	
  /**********************************+**************************************
  **  FUNCTION:  move_puts_to_batch
  **
  **  DESCRIPTION - Function sets the pallet_batch_no field of the all the
  **                pallets on one specified batch to another the specified
  **                batch.
  **
  **  PARAMETERS:
  **    p_cur_pallet_batch_no - the current batch number being unattached
  **                            from.
  **    p_cur_pallet_batch_no_len - length of current pallet batch no field.
  **    p_new_pallet_batch_no - the new batch number being attached to.
  **    p_new_pallet_batch_no_len - length of new pallet batch no field.
  ***********************************-*************************************/

    FUNCTION move_puts_to_batch (
        i_cur_pallet_batch_no       IN batch.batch_no%TYPE,
        i_cur_pallet_batch_no_len   IN NUMBER,
        i_new_pallet_batch_no       IN putawaylst.pallet_batch_no%TYPE,
        i_new_pallet_batch_no_len   IN NUMBER
    ) RETURN NUMBER IS
        l_status      NUMBER := ORACLE_NORMAL;
        l_func_name   VARCHAR2(50) := 'move_puts_to_batch';
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Inside move_puts_to_batch. cur_pallet_batch_no = ' || i_cur_pallet_batch_no, sqlcode, sqlerrm);
		
        UPDATE putawaylst
        SET
            pallet_batch_no = i_new_pallet_batch_no
        WHERE
            pallet_batch_no = i_cur_pallet_batch_no;

			pl_text_log.ins_msg_async('INFO', l_func_name, 'Putaway tasks moved to new batch... cur_pallet_batch_no = '
                                            || i_cur_pallet_batch_no
                                            || ' new_pallet_batch_no = '
                                            || i_new_pallet_batch_no, sqlcode, sqlerrm);
        RETURN l_status;
    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to reattach putaway tasks to new batch. cur_pallet_batch_no = '
                                                || i_cur_pallet_batch_no
                                                || ' new_pallet_batch_no = '
                                                || i_new_pallet_batch_no, sqlcode, sqlerrm);

            l_status := UPD_FAIL;
            RETURN l_status;
    END move_puts_to_batch;
	
  /**********************************+**************************************
  **  FUNCTION:  create_default_rtn_lm_batch
  **
  **  DESCRIPTION - Function creates the indirect time catcher batch after
  **                a FUNC1 has been entered from RF.
  **
  **  PARAMETERS:
  **    i_user_id - the current user.
  **    i_batch_no - current batch no.
  ***********************************-*************************************/

    FUNCTION create_default_rtn_lm_batch (
        i_user_id    IN batch.user_id%TYPE,
        i_batch_no   IN batch.batch_no%TYPE
    ) RETURN NUMBER IS

        l_func_name   VARCHAR2(50) := 'create_default_rtn_lm_batch';
		l_ret_val     NUMBER := ORACLE_NORMAL;      
        l_job_code    VARCHAR2(6);
        l_batch_no    VARCHAR2(13);
    BEGIN
		pl_text_log.ins_msg_async('INFO', l_func_name, ' Inside create_default_rtn_lm_batch. batch_no = ' || i_batch_no, sqlcode, sqlerrm);
		
		l_job_code := pl_common.f_get_syspar('LM_RTN_DFLT_IND_JOBCODE','x');
        
		IF l_job_code != 'x' THEN 
		
			pl_text_log.ins_msg_async('INFO', l_func_name, 'RTN DFLT JBCODE = ' || l_job_code, sqlcode, sqlerrm);
			SELECT
				'I' || seq1.NEXTVAL
			INTO l_batch_no
			FROM
				dual;

			pl_text_log.ins_msg_async('INFO', l_func_name, 'RTN DFLT batch = ' || l_batch_no, sqlcode, sqlerrm);
			
			BEGIN
				INSERT INTO batch (
					batch_no,
					batch_date,
					status,
					jbcd_job_code,
					actl_start_time,
					user_id,
					user_supervsr_id,
					kvi_doc_time,
					kvi_cube,
					kvi_wt,
					kvi_no_piece,
					kvi_no_pallet,
					kvi_no_item,
					kvi_no_data_capture,
					kvi_no_po,
					kvi_no_stop,
					kvi_no_zone,
					kvi_no_loc,
					kvi_no_case,
					kvi_no_split,
					kvi_no_merge,
					kvi_no_aisle,
					kvi_no_drop,
					kvi_order_time,
					kvi_distance,
					kvi_no_cart,
					kvi_no_pallet_piece,
					kvi_no_cart_piece,
					goal_time,
					target_time,
					ref_no
				)
					SELECT
						l_batch_no,
						trunc(SYSDATE),
						'A',
						l_job_code,
						b.actl_stop_time,
						b.user_id,
						b.user_supervsr_id,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						0,
						i_batch_no
					FROM
						batch b
					WHERE
						ROWNUM = 1
						AND b.actl_stop_time = (
							SELECT
								MAX(actl_stop_time)
							FROM
								batch b2
							WHERE
								b2.batch_no = b.batch_no
								AND b2.batch_date = b.batch_date
								AND b2.status = 'C'
								AND replace(b2.user_id,'OPS$',NULL) = replace(i_user_id,'OPS$',NULL)
						);

			EXCEPTION
				WHEN OTHERS THEN
					pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to create RTN default indirect jobcode.batch_no = '
														|| l_batch_no
														|| ' job_code = '
														|| l_job_code
														|| ' User_id = '
														|| i_user_id, sqlcode, sqlerrm);

					l_ret_val := NO_LM_BATCH_FOUND;
			END;
		ELSE
			pl_text_log.ins_msg_async('WARN', l_func_name, 'Unable to get syspar for returns default indirect jobcode.', sqlcode, sqlerrm);
            l_ret_val := CTE_RTN_BTCH_FLG_OFF;
		END IF;
		
        RETURN l_ret_val;
    
    END create_default_rtn_lm_batch;

END pl_returns_lm_bats;
/

GRANT EXECUTE ON pl_returns_lm_bats TO swms_user;
