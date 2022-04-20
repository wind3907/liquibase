/******************************************************************************
  @(#) TRG_ins_label_master_BROW.sql
  @(#) src/schema/triggers/trg_ins_label_master_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.3
******************************************************************************/

CREATE OR REPLACE TRIGGER SWMS.TRG_ins_label_master_BROW
BEFORE INSERT ON swms.label_master
FOR EACH ROW
BEGIN
	DECLARE
		p_flag		VARCHAR2 (1);
		l_batch_no	NUMBER := :NEW.batch_no;
	BEGIN
		BEGIN
			SELECT	s1.config_flag_val
			  INTO	p_flag
			  FROM	sys_config s1, sys_config s2, sys_config s3
			 WHERE	s1.CONFIG_FLAG_NAME = 'PRINT_REPLEN_LABELS'
			   AND	s2.config_flag_name = 'SEPARATE_BULK'
			   AND	s2.config_flag_val  = 'Y'
			   AND	s3.config_flag_name = 'SEND_DMD_RPL_TO_RF'
			   AND	s3.config_flag_val  = 'Y';
			EXCEPTION
				WHEN OTHERS THEN
					p_flag := 'Y';
		END;

		IF (p_flag = 'N') THEN
		BEGIN
			SELECT 'N'
			  INTO	p_flag
			  FROM	floats
			 WHERE	batch_no = l_batch_no
			   AND	pallet_pull = 'R'
			   AND	ROWNUM = 1;
			EXCEPTION
				WHEN OTHERS THEN
					p_flag := 'Y';
		END;
		END IF;
		:NEW.print_flag := p_flag;
	END;
END;
/

