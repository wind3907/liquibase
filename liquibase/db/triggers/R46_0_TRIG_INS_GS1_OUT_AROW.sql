----------------------------------------------------------------------------------------------------
-- Trigger:
--    R46_0_TRIG_INS_GS1_OUT_AROW
--
-- Description:
--    This trigger inserts data to the Staging table GS1_OUT from ORDGS1 table when route is closed.
--
-- Modification History:
--    Date       Designer   Comments
--    ---------  --------   ---------------------------------------------------
--    08/16/2021 SRAJ8407   Created trigger to populate data from ORDGS1 to
--                          the GS1_OUT when the route is closed.
------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER swms.trig_ins_gs1_out_arow AFTER
	UPDATE OF status ON swms.route
	FOR EACH ROW
	WHEN ( NEW.status = 'CLS' )
DECLARE
	l_trg_name   VARCHAR2(30) := 'TRIG_INS_GS1_OUT_AROW';
	l_count      NUMBER;
	CURSOR c_gs1_out (
		l_route_no route.route_no%TYPE
	) IS
	SELECT
		order_id,
		order_line_id,
		seq_no,
		route_no,
		prod_id,
		cust_pref_vendor,
		shipped_date,
		gs1_gtin,
		uom,
		gs1_lot_id,
		gs1_production_date,
		cust_po,
		add_date,
		add_user,
		upd_date,
		upd_user,
		float_no,
		scan_method,
		order_seq,
		case_id
	FROM
		ordgs1
	WHERE
		route_no = l_route_no
	AND upd_date is not null
	ORDER BY
		order_id,
		order_line_id,
		seq_no,
		route_no;

BEGIN
	pl_log.ins_msg('INFO', l_trg_name, 'Starting of Trigger Execution for GS1_OUT Table', SQLCODE, SQLERRM);
	SELECT
		COUNT(*)
	INTO l_count
	FROM
		ordgs1
	WHERE
		route_no = :OLD.route_no;

	IF ( l_count > 0 ) THEN 
	FOR l_gs1_out IN c_gs1_out(:OLD.route_no) LOOP
		BEGIN
			INSERT INTO gs1_out (
				order_id,
				order_line_id,
				seq_no,
				record_status,
				route_no,
				prod_id,
				cust_pref_vendor,
				shipped_date,
				gs1_gtin,
				uom,
				gs1_lot_id,
				gs1_production_date,
				cust_po,
				add_user,
				float_no,
				scan_method,
				order_seq,
				case_id) 
			VALUES (
				l_gs1_out.order_id,
				l_gs1_out.order_line_id,
				l_gs1_out.seq_no,
				'N',
				l_gs1_out.route_no,
				l_gs1_out.prod_id,
				l_gs1_out.cust_pref_vendor,
				l_gs1_out.shipped_date,
				l_gs1_out.gs1_gtin,
				l_gs1_out.uom,
				l_gs1_out.gs1_lot_id,
				l_gs1_out.gs1_production_date,
				l_gs1_out.cust_po,
				USER,
				l_gs1_out.float_no,
				l_gs1_out.scan_method,
				l_gs1_out.order_seq,
				l_gs1_out.case_id
			);

		EXCEPTION
			WHEN OTHERS THEN pl_log.ins_msg('WARN', l_trg_name, 'Error in Inserting records to the GS1_OUT table', SQLCODE, SQLERRM);
		END;
	END LOOP;
	ELSE pl_log.ins_msg('WARN', l_trg_name, 'No records found in the ordgs1 table for Route ' || :OLD.route_no, SQLCODE, SQLERRM);
	END IF;
	pl_log.ins_msg('INFO', l_trg_name, 'End of Trigger Execution for GS1_OUT Table', SQLCODE, SQLERRM);
END;
/
