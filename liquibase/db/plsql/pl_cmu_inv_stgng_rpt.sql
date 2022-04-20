/***************************************************************************************/
-- Package Specification
/***************************************************************************************/

CREATE OR REPLACE PACKAGE pl_cmu_inv_stgng_rpt AS
	/*
		Package Name: pl_cmu_inv_staging_rpt
		Description: This package populates a staging table with inventory data which is then reported to the CMU team.
		Modification History:
			Date		Developer			Comments
			4/1/2020	Danny Betancourt	Committed to TFS
	*/
	
	/*
		Procedure: qoh_into_staging_table (public)
		Description: This procedure performs the actual population of the staging table.
	*/
	PROCEDURE qoh_into_stgng_tbl (param_prod_id_array t_prod_ids);

	/*
		Procedure: not_rcvd_into_staging_table (public)
		Description: This procedure performs the actual population of the staging table.
	*/
	PROCEDURE not_rcvd_into_stgng_tbl (param_sn_no_array t_sn_nos);
END pl_cmu_inv_stgng_rpt;
/

CREATE OR REPLACE PACKAGE BODY pl_cmu_inv_stgng_rpt AS
	/*
		Package Name: pl_cmu_inv_staging_rpt
		Description: This package populates a staging table with inventory data which is then reported to the CMU team.
		Modification History:
			Date		Developer			Comments
			4/1/2020	Danny Betancourt	Committed to TFS
	*/
	
	/*
		Procedure: qoh_into_staging_table (public)
		Description: This procedure performs the actual population of the staging table.
	*/
	PROCEDURE qoh_into_stgng_tbl (param_prod_id_array t_prod_ids) IS
		PRAGMA INLINE;
		l_batch rpt_inv_stgng_out.batch_id%TYPE := rpt_inv_stgng_out_batch_seq.NEXTVAL;
	BEGIN
		INSERT INTO rpt_inv_stgng_out (batch_id, po_no, po_line_id, prod_id, uom, qoh, trans_date, pallet_id, trans_type, sn_no, record_status, record_status_message, add_date, upd_date, add_user)
			SELECT
				l_batch,
				e.po_no,
				e.po_line_id,
				i.prod_id,
				2,
				i.qoh / p.spc,
				i.rec_date,
				e.pallet_id,
				'PUT',
				e.sn_no,
				'N',
				NULL,
				CURRENT_DATE,
				NULL,
				REPLACE(USER, 'OPS$', NULL)
			FROM inv i, erd_lpn e, pm p
			WHERE
				i.qoh > 0
				AND i.prod_id MEMBER OF param_prod_id_array
				AND i.logi_loc = e.pallet_id
				AND i.prod_id = e.prod_id
				AND i.prod_id = p.prod_id
				AND i.plogi_loc != i.logi_loc;
		INSERT INTO rpt_inv_stgng_out (batch_id, po_no, po_line_id, prod_id, uom, qoh, trans_date, pallet_id, trans_type, sn_no, record_status, record_status_message, add_date, upd_date, add_user)
			SELECT
				l_batch,
				t.po_no,
				t.po_line_id,
				i.prod_id,
				2,
				i.qoh / p.spc,
				i.rec_date,
				t.pallet_id,
				'PUT',
				t.sn_no,
				'N',
				NULL,
				CURRENT_DATE,
				NULL,
				REPLACE(USER, 'OPS$', NULL)
			FROM inv i, pm p, trans t
			WHERE
				i.qoh > 0
				AND i.prod_id MEMBER OF param_prod_id_array
				AND i.prod_id = p.prod_id
				AND t.trans_type = 'PUT'
				AND i.prod_id = t.prod_id
				AND i.rec_id = t.sn_no
				AND i.logi_loc = t.dest_loc
				AND i.plogi_loc = i.logi_loc;
	EXCEPTION
		WHEN OTHERS THEN
			pl_log.ins_msg
			(
				i_msg_type		=> pl_log.ct_fatal_msg,
				i_procedure_name	=> 'qoh_into_staging_table',
				i_msg_text		=> 'The default catch was activated.',
				i_msg_no			=> SQLCODE,
				i_sql_err_msg		=> SQLERRM,
				i_application_func	=> 'ct_application_function',
				i_program_name		=> 'pl_cmu_inv_staging_rpt',
				i_msg_alert		=> 'N'
			);
			RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 'qoh_into_staging_table: ' || SQLERRM);
	END qoh_into_stgng_tbl;

	/*
		Procedure: not_rcvd_into_staging_table (public)
		Description: This procedure performs the actual population of the staging table.
	*/
	PROCEDURE not_rcvd_into_stgng_tbl (param_sn_no_array t_sn_nos) IS
		PRAGMA INLINE;
		l_batch rpt_inv_stgng_out.batch_id%TYPE := rpt_inv_stgng_out_batch_seq.NEXTVAL;
	BEGIN
		INSERT INTO rpt_inv_stgng_out (batch_id, po_no, po_line_id, prod_id, uom, qoh, trans_date, pallet_id, trans_type, sn_no, record_status, record_status_message, add_date, upd_date, add_user)
			SELECT
				l_batch,
				d.po_no,
				d.po_line_id,
				d.prod_id,
				2,
				d.qty / p.spc,
				m.rec_date,
				d.pallet_id,
				'NEW',
				m.erm_id,
				'N',
				NULL,
				CURRENT_DATE,
				NULL,
				REPLACE(USER, 'OPS$', NULL)
			FROM erm m, erd_lpn d, pm p
			WHERE
				m.erm_id MEMBER OF param_sn_no_array
				AND m.status = 'NEW'
				AND m.erm_id = d.sn_no
				AND d.prod_id = p.prod_id;
	EXCEPTION
		WHEN OTHERS THEN
			pl_log.ins_msg
			(
				i_msg_type		=> pl_log.ct_fatal_msg,
				i_procedure_name	=> 'not_rcvd_into_staging_table',
				i_msg_text		=> 'The default catch was activated.',
				i_msg_no			=> SQLCODE,
				i_sql_err_msg		=> SQLERRM,
				i_application_func	=> 'ct_application_function',
				i_program_name		=> 'pl_cmu_inv_staging_rpt',
				i_msg_alert		=> 'N'
			);
			RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 'not_rcvd_into_staging_table: ' || SQLERRM);
	END not_rcvd_into_stgng_tbl;
END pl_cmu_inv_stgng_rpt;
/
