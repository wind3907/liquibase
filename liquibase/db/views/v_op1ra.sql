REM @(#) src/schema/views/v_op1ra.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_op1ra.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_op1ra.sql, swms, swms.9, 10.1.1
CREATE OR REPLACE VIEW swms.v_op1ra
AS
	SELECT	m.print_group print_group,
		m.seq print_seq,
		m.queue print_queue,
		m.batch_no batch_no,
		h.ship_date ship_date,
		h.label_seq label_seq,
		h.label_type label_type,
		h.fld_text fld_text
	  FROM	label_header h, label_master m
	 WHERE	h.batch_no = m.batch_no
	   AND	NVL (m.print_flag, 'Y') != 'N'
/

