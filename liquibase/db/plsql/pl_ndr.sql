/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_ndr IS
---------------------------------------------------------------------------
-- Package Name:
--    pl_ndr
--
-- Description:
--    Deleting non deman replenishments
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    18/09/12 vkat2696   CRQ26861  Created.  The
--                      use is for  automating the deletion process of non demand replenishments
--------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Procedure:
--    delete_ndr
--
-- Description:
--   This procedure  updates the inv quantity and deletes the ndr 
--    from replenlst table.
--    Deletion of fork batches is also done
--------------------------------------------------------------------------- 
   
PROCEDURE delete_ndr;
-----------------------------Commit replen variables -----
TYPE task_table_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
all_tasks	task_table_type;
g_tabTask	pl_swms_execute_sql.tabTask;
g_batch_no		NUMBER := 0;
g_qry_batch_no	NUMBER;
g_qry_status 	VARCHAR2 (3);
g_selected		boolean := FALSE;
g_start_pos 	NUMBER := 0;
g_end_pos 		NUMBER := 0;
g_num_recs 	 	NUMBER := 0;
g_cleared		boolean := FALSE;

END pl_ndr;
/

show errors 

/**************************************************************************/
-- Package Body
/**************************************************************************/
CREATE OR REPLACE PACKAGE BODY  swms.pl_ndr IS
PROCEDURE delete_ndr IS
l_status    replenlst.status%TYPE := NULL;
sysconfig   VARCHAR2(20);
message     VARCHAR2(70);
method_type VARCHAR2(1);
tRec        NUMBER := NULL;
UserInput   VARCHAR2 (80);
area_type   VARCHAR2(1);
g_batch_no  NUMBER;
g_user_id   VARCHAR2 (10) := REPLACE (USER, 'OPS$');

l_no_records_processed 	PLS_INTEGER;
l_no_batches_created 	PLS_INTEGER;
l_no_batches_existing 	PLS_INTEGER;
l_no_not_created_due_to_error PLS_INTEGER;

lbr_active 	VARCHAR2(1) := 'N';
fork_active VARCHAR2(1) := 'N';

	CURSOR lc_item_details IS 
	SELECT * 
	FROM replenlst 
	WHERE type = 'NDM'
	AND status = 'NEW' 
	AND replen_type != 'S' FOR UPDATE;

BEGIN

	SELECT config_flag_val INTO sysconfig
	FROM sys_config 
	where config_flag_name = 'START_FLOAT_CH'
	FOR update of config_flag_val nowait;

	FOR lv_ndr_item IN lc_item_details
	LOOP

		UPDATE inv
		SET qty_alloc = decode(sign(qty_alloc - lv_ndr_item.qty),1,qty_alloc - lv_ndr_item.qty,0)
		WHERE plogi_loc = lv_ndr_item.src_loc
		AND logi_loc = lv_ndr_item.pallet_id;

		UPDATE inv
		SET qty_planned = decode(sign(qty_planned - lv_ndr_item.qty),1,qty_planned - lv_ndr_item.qty,0)
		WHERE plogi_loc = nvl(lv_ndr_item.inv_dest_loc,lv_ndr_item.dest_loc);

		DELETE FROM replenlst
		WHERE batch_no = lv_ndr_item.batch_no
		AND src_loc = lv_ndr_item.src_loc
		AND dest_loc = lv_ndr_item.dest_loc
		AND pallet_id = lv_ndr_item.pallet_id;

		-------- Delete fork batch
		SELECT config_flag_val INTO lbr_active
		FROM sys_config
		WHERE config_flag_name = 'LBR_MGMT_FLAG';

		SELECT create_batch_flag INTO fork_active
		FROM lbr_func
		WHERE lfun_lbr_func = 'FL';

		IF fork_active = 'Y' AND lbr_active = 'Y' THEN

			DELETE FROM batch
			WHERE batch_no = 'FN' || to_char(lv_ndr_item.task_id)
			AND status = 'F';
		
		END IF;
	
	END LOOP;
	COMMIT;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
	message := 'NO DATA FOUND';
	pl_log.ins_msg ('INFO','PL_NDR',message, SQLCODE, SQLERRM,'NO DATA FOUND','PL_NDR','N');

	WHEN OTHERS THEN
	message := 'UNEXPECTED ERROR: PROCESSING STOPPED';
	pl_log.ins_msg ('FATAL','PL_NDR',message, SQLCODE, SQLERRM,'UNEXPECTED ERROR','PL_NDR','Y');

END delete_ndr;

END pl_ndr;
/

CREATE OR REPLACE PUBLIC SYNONYM PL_NDR FOR SWMS.PL_NDR;
/
GRANT ALL ON SWMS.PL_NDR TO SWMS_USER;
/	 
