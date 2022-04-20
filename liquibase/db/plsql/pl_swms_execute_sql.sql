CREATE OR REPLACE
PACKAGE swms.pl_swms_execute_sql IS
/*****************************************************************/
/* sccs_id=@(#) src/schema/plsql/pl_swms_execute_sql.sql, swms, swms.12 */
/*****************************************************************/
---------------------------------------------------------------------------
-- Package Name:
--    pl_swms_execute_sql
--
-- Description:
--    Package for execute sql statement from client (like form).
--    Invoked from Weblogic forms.
--
-- Main Procedures:
--   execute_immediate:Execute the passed in sql statement.
--   delete_ndm_repl: Delete/clear all NDM tasks.
--   commit_ndm_repl: Clear selected NDM tasks. 
-- Sub Procedures:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/25/10 prppxx   Initial Version
--    12/08/10 prppxx   Activity: SWMS12.0.0_0064_CRQ19462.
--                      Add deletion labor batch in delete_ndm_repl
--                      for "delete all" on the form pn1sa.
--    02/22/11 prppxx   Activity: Delete_lbr_batch_4_some_ndm_repl.
--			   This fix will be in 12.2.1(?).
--                      Add delete labor batch in delete_ndm_repl for 
--                      "delete selection" on form pn1sa.
--    04/20/11 prppxx   Activity: CRQ22419-Dual maintenance pn1sb in 11g.
--                      Move the update logic into stored procedure to 
--                      improve the performance in 11g world.
--                      Add commit of RLP task (Putback task to reserve slot).
--                      "delete selection" on form pn1sa.
--
--    06/21/13 prpbcb   TFS
--                      Project:
--                R12.5.2--WIB#158--CRQ46749_Deleting_miniload_demand_repl_updates_inv
--
--                      When deleting demand miniloader replenishments the
--                      inventory is updated.  The inventory needs
--                      to be left alone.
--                      Changed both occurences of procedure delete_mnl_repl()
--                      it is overloaded) to look at column UPDATE_INV in
--                      the PRIORITY_CODE table and if it is 'N' then not
--                      update the inventory when deleting the
--                      miniloader replenishments.  When UPDATE_INV is
--                      'N' then it means the replenishment does not
--                      update inventory when it is performed which is the
--                      case for demand replenishments.  The REPLENST.PRIORITY
--                      is always populated for miniloader replenishments
--                      and corresponds to the PRIORITY_CODE.PRIORITY_CODE
--                      column.
--                      Added function:
--                         -  get_mnl_priority_upd_inv_flag
--
--                      NOTE: We need to have one common routine to do the
--                            actual deleting of the replenishment task and
--                            do some consolidating in the miniloader 
--                            replenishment form regarding deleting the tasks.
--
--                      At this time table PRIORITY_CODE has this stucture
--                      and values:
--  10/14/15  mdev3739 Charm 6000008070 - Inventory UpdateAdjustment
--                      Added the status condition to exclude other 'NEW' status.
--                      (User not refreshing the from and doing delete, So it is 
--                      deleted)  
/*******************
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 PRIORITY_CODE                             NOT NULL VARCHAR2(3)
 UNPACK_CODE                               NOT NULL VARCHAR2(1)
 PRIORITY_VALUE                            NOT NULL NUMBER(2)
 PRIO_DESIGNATOR                                    VARCHAR2(1)
 UPDATE_INV                                         VARCHAR2(1)
 DESCRIPTION                                        VARCHAR2(50)
 DELETE_AT_START_OF_DAY                             VARCHAR2(1)
 RETENTION_DAYS                                     NUMBER

PRI U PRIORITY_VALUE P U DESCRIPTION                                        D RETENTION_DAYS
--- - -------------- - - -------------------------------------------------- - --------------
URG N             12 @ N Demand Replenishments for Miniload Cases
URG Y             15 @ N Demand Replenishment for Miniload Splits
HGH N             18 # Y High Priority Store Order for Miniload Cases
HGH Y             20 # Y High Priority Store Order for Miniload Splits
MED N             45   Y Move item to miniload by slotting
LOW N             48   Y Non Demand Replenishments for Miniload Cases
LOW Y             50   Y Non Demand Replenishments for Miniload Splits
*******************/
--
--


---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Global Type Declarations
---------------------------------------------------------------------------
	TYPE recReplen IS RECORD 
	(
	 task_id	replenlst.task_id%TYPE,
	 src_loc	replenlst.src_loc%TYPE,
	 dest_loc 	replenlst.dest_loc%TYPE,
	 inv_dest_loc 	replenlst.inv_dest_loc%TYPE,
	 pallet_id 	replenlst.pallet_id%TYPE,
	 qty 		replenlst.qty%TYPE,
	 batch_no 	replenlst.batch_no%TYPE
	);

	TYPE tabReplen IS TABLE OF recReplen INDEX BY BINARY_INTEGER;
	TYPE tabTask IS TABLE OF replenlst.task_id%TYPE INDEX BY BINARY_INTEGER;

	TYPE recReplenMnl IS RECORD 
	(
	 task_id	replenlst.task_id%TYPE,
	 src_loc	replenlst.src_loc%TYPE,
	 dest_loc 	replenlst.dest_loc%TYPE,
	 inv_dest_loc 	replenlst.inv_dest_loc%TYPE,
	 pallet_id 	replenlst.pallet_id%TYPE,
	 qty 		replenlst.qty%TYPE,
	 batch_no 	replenlst.batch_no%TYPE,
         uom            replenlst.uom%TYPE,
         prod_id        replenlst.prod_id%TYPE,
         cpv            replenlst.cust_pref_vendor%TYPE,
         orig_pallet_id replenlst.orig_pallet_id%TYPE
	);

	TYPE tabReplenMnl IS TABLE OF recReplenMnl INDEX BY BINARY_INTEGER;
---------------------------------------------------------------------------
-- Global Variables
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Public Constants
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(20) := 'pl_swms_execute_sql';   -- Package name.  
                                                          -- Used in
                                                          -- error messages.

---------------------------------------------------------------------------
-- Procedure Declarations
---------------------------------------------------------------------------
-- This is first used to commit all of the NDM task on pn1sa screen.
-- It can be used in other constructed execute stmt.
PROCEDURE execute_immediate
            (i_last_qry     IN VARCHAR2,
             io_RowCnt  IN OUT NUMBER);

-- This is used to delete/clear all of the NDM task on pn1sa screen.
PROCEDURE delete_ndm_repl 
            (i_last_qry     IN VARCHAR2,
             io_RowCnt  IN OUT NUMBER);

-- This is used to delete/clear some of the selected NDM task on pn1sa screen.
PROCEDURE delete_ndm_repl 
            (i_tabTask     IN tabTask,
             i_RowCnt      IN NUMBER,
	     o_delCnt	  OUT NUMBER);
-- This is used to commit some of the selected NDM task on pn1sa screen.
PROCEDURE commit_ndm_repl (
	     i_tabTask      IN tabTask,
             i_RowCnt       IN NUMBER,
   	     o_recCnt	    IN OUT NUMBER); 
-- This is used to delete all of the MNL replenishment task on pn1sb screen.
PROCEDURE delete_mnl_repl
	    (i_last_qry     IN VARCHAR2,
             io_RowCnt      IN OUT NUMBER);
-- This is used to delete some Miniload repl on pn1sb screen.
PROCEDURE delete_mnl_repl (i_tabTask      IN tabTask,
                              i_RowCnt       IN NUMBER,
	 		      o_delCnt	     OUT NUMBER);
-- This procedure commit the RLP records if the same MNL pallet has been committed.
-- PROCEDURE commit_rlp_repl (o_recCnt      OUT number);
   PROCEDURE commit_rlp_repl;

---------------------------------------------------------------------------
-- Function Declarations
---------------------------------------------------------------------------

END pl_swms_execute_sql;
/
CREATE OR REPLACE
PACKAGE BODY swms.pl_swms_execute_sql
IS

--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function VARCHAR2(10) := 'INVENTORY';


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    get_mnl_priority_upd_inv_flag
--
-- Description:
--    This functions returns the flag that determines if the inventory
--    should be updated when deleting a miniloader replenishment.
--
--    The flag that designates this is PRIORITY_CODE.UPDATE_INV
--    The minloader replenishment task has a priority which
--    corresponds to PRIORITY_CODE.PRIORITY_VALUE.
--
--    Call this function only for replenishments with type = 'MNL'
--
-- Parameters:
--    i_task_id   - Miniloader replenishment task id.
--
-- Return Values:
--    priority_code.update_inv
--    or NULL if not found
--
-- Called by:
--    -
--
-- Exceptions Raised:
--    pl_exc.e_data_error      - Could not find the update inv flag.
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/21/13 prpbcb   Created.
---------------------------------------------------------------------------
FUNCTION get_mnl_priority_upd_inv_flag(i_task_id IN replenlst.task_id%TYPE)
RETURN VARCHAR2
IS
   l_object_name   VARCHAR2(61);
   l_message       VARCHAR2(256);    -- Message buffer
   l_return_value  priority_code.update_inv%TYPE;
BEGIN
   SELECT pc.update_inv
     INTO l_return_value
     FROM priority_code pc, replenlst r
    WHERE pc.priority_value = r.priority
      AND r.task_id         = i_task_id;

   RETURN(l_return_value);
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      --
      -- Did not find the priority.  Log a message and
      -- raise an exception.  This is a fatal error.
      --
      l_object_name := 'get_mnl_priority_upd_inv_flag';
      l_message := 
            'TABLE=priority_code,replenlst  ACTION=SELECT'
         || '  i_task_id[' || i_task_id || ']'
         || '  MESSAGE="Did not found the replenlst priority."';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
               SQLCODE, SQLERRM, ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_message);
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      -- This is fatal error.
      --
      l_object_name := 'get_mnl_priority_upd_inv_flag';
      l_message := l_object_name || ' i_task_id['
                  || TO_CHAR(i_task_id) || ']';
      pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function,
                     gl_pkg_name);
      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' ||  SQLERRM);
END get_mnl_priority_upd_inv_flag;




---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

	PROCEDURE execute_immediate (i_last_qry     IN 		VARCHAR2,
		               	     io_RowCnt      IN OUT 	NUMBER) IS
	BEGIN
		EXECUTE IMMEDIATE (i_last_qry);
                io_RowCnt := SQL%ROWCOUNT;

	END execute_immediate;

        PROCEDURE delete_ndm_repl (i_last_qry     IN VARCHAR2,
			           io_RowCnt      IN OUT NUMBER) IS
           
	   l_tabReplen	    tabReplen;
	   iIndex 	    number;
	   l_message       VARCHAR2(512);    -- Message buffer
           l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                            '.delete_ndm_repl';
	BEGIN

		EXECUTE IMMEDIATE (i_last_qry) BULK COLLECT INTO l_tabReplen;
		FOR iIndex IN 1..l_tabReplen.COUNT
		LOOP
		    BEGIN
			DELETE	replenlst
			 WHERE	task_id = l_tabReplen (iIndex).task_id;

                        UPDATE inv
			   SET qty_alloc = DECODE (SIGN (qty_alloc - l_tabReplen (iIndex).qty),1,qty_alloc - l_tabReplen (iIndex).qty,0)
			 WHERE plogi_loc = l_tabReplen (iIndex).src_loc
			   AND logi_loc = l_tabReplen (iIndex).pallet_id;

			IF (SQL%NOTFOUND) THEN
			  -- No row(s) updated. Log message and keep on going.
                          l_message := 'TABLE=inv  ACTION=UPDATE' ||
                          ' KEY=' ||  l_tabReplen (iIndex).pallet_id || '(pallet id)' ||
                          ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl';
                          pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                         l_message, SQLCODE, SQLERRM);
			END IF;

			UPDATE inv
			   SET qty_planned = DECODE(SIGN(qty_planned - l_tabReplen (iIndex).qty),1,qty_planned - l_tabReplen (iIndex).qty,0)
			 WHERE plogi_loc = NVL(l_tabReplen (iIndex).inv_dest_loc, l_tabReplen (iIndex).dest_loc);

			IF (SQL%NOTFOUND) THEN
                          l_message := 'TABLE=inv  ACTION=UPDATE' ||
                          ' KEY=' ||  l_tabReplen (iIndex).dest_loc || '(inv_dest_loc)' ||
                          ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl';
                          pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                         l_message, SQLCODE, SQLERRM);
			END IF;

 			 -- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - Begin
    			DELETE FROM trans
			    WHERE batch_no = l_tabReplen (iIndex).batch_no
			    AND src_loc = l_tabReplen (iIndex).src_loc
			    AND dest_loc =l_tabReplen (iIndex).dest_loc
			    AND pallet_id = l_tabReplen (iIndex).pallet_id
			    AND trans_type = 'RPF'; 
			    -- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - End
                    
			DELETE FROM batch
			 WHERE batch_no = 'FN' || TO_CHAR (l_tabReplen (iIndex).task_id)
			   AND status = 'F'; 

                        io_RowCnt := iIndex;

		     EXCEPTION WHEN OTHERS THEN
			  ROLLBACK; 
			  io_RowCnt := 0;
                          l_message := 'TABLE=erplenlst  ACTION=DELETE,UPDATE' ||
                          ' KEY=' ||  l_tabReplen (iIndex).pallet_id || '(pallet_id)' ||
                          ' MESSAGE="SQL%NOTFOUND true.  Failed to delete NDM repl';
                          pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                         l_message, SQLCODE, SQLERRM);
			
		    END;
		END LOOP;

	END    delete_ndm_repl;

        PROCEDURE delete_ndm_repl (i_tabTask      IN tabTask,
                                   i_RowCnt       IN NUMBER,
				   o_delCnt	  OUT NUMBER) IS
   
           l_message       VARCHAR2(512);    -- Message buffer
           l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                            '.delete_ndm_repl2';
	   row_index NUMBER := i_tabTask.FIRST;

	   CURSOR curReplen (iTask Number) IS
			SELECT task_id, src_loc, dest_loc, inv_dest_loc, pallet_id, qty, batch_no
			  FROM replenlst
			 WHERE task_id = iTask
			 AND status in ('NEW','PRE'); --#6000008070- Added the column to exclude other than NEW and PRE rec.
        BEGIN
		   o_delCnt := 0;
		   LOOP
			EXIT WHEN row_index IS NULL;
			FOR rReplen IN curReplen (i_tabTask(row_index))
			LOOP
		        BEGIN
			    DELETE replenlst
			     WHERE task_id = rReplen.task_id
				 AND status in ('NEW','PRE'); --#6000008070- Added the column to exclude ottherthan NEW rec.

                            UPDATE inv
			       SET qty_alloc = DECODE (SIGN (qty_alloc - rReplen.qty), 1, qty_alloc - rReplen.qty, 0)
			     WHERE plogi_loc = rReplen.src_loc
			       AND logi_loc = rReplen.pallet_id;

			    IF (SQL%NOTFOUND) THEN
			      -- No row(s) updated. Log message and keep on going.
                              l_message := 'TABLE=inv  ACTION=UPDATE' ||
                              ' KEY=' ||  rReplen.pallet_id || '(pallet id)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl task';
                              pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
			    END IF;

			    UPDATE inv
			       SET qty_planned = DECODE(SIGN(qty_planned - rReplen.qty), 1, qty_planned - rReplen.qty, 0)
			     WHERE plogi_loc = NVL(rReplen.inv_dest_loc, rReplen.dest_loc);

			    IF (SQL%NOTFOUND) THEN
                              l_message := 'TABLE=inv  ACTION=UPDATE' ||
                              ' KEY=' ||  rReplen.dest_loc || '(inv_dest_loc)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to update for delete NDM repl task';
                              pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
			    END IF;

 			    -- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - Begin
    			    DELETE FROM trans
			        WHERE batch_no = rReplen.batch_no
			        AND src_loc = rReplen.src_loc
			        AND dest_loc = rReplen.dest_loc
			        AND pallet_id = rReplen.pallet_id
			        AND trans_type = 'RPF'; 
			    -- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - End

			    DELETE FROM batch
			     WHERE batch_no = 'FN' || TO_CHAR (rReplen.task_id)  
			       AND status = 'F'; 
                    
			    o_delCnt := o_delCnt + 1;

		        EXCEPTION WHEN OTHERS THEN
			      ROLLBACK; 
			      o_delCnt := 0;
                              l_message := 'TABLE=replenlst  ACTION=DELETE,UPDATE' ||
                              ' KEY=' ||  rReplen.pallet_id || '(pallet_id)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to delete NDM repl';
                              pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
			
		        END;
		   	END LOOP;	
                        row_index := i_tabTask.NEXT(row_index);
	   END LOOP;

	END delete_ndm_repl;


        PROCEDURE delete_mnl_repl (i_last_qry     IN VARCHAR2,
			           io_RowCnt      IN OUT NUMBER) IS
           l_spc	   number;
	   l_tabReplen_mnl	    tabReplenMnl;
	   iIndex 	 	    number;
	   l_message       VARCHAR2(512);    -- Message buffer
           l_object_name   VARCHAR2(30) := 'delete_mnl_repl';
           l_update_inv_flag   priority_code.update_inv%TYPE;  -- Flag 
                                    -- that designates if the inventory needs to be updated when
                                    -- deleting the replenishment.  For demand replenishments
                                    -- this needs to be N.
        BEGIN
           pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Starting procedure (i_last_qry,io_RowCnt)',
                          NULL, NULL, ct_application_function, gl_pkg_name);

		EXECUTE IMMEDIATE (i_last_qry) BULK COLLECT INTO l_tabReplen_mnl;
		FOR iIndex IN 1..l_tabReplen_mnl.COUNT
		LOOP

		    BEGIN
			SELECT spc 
			  INTO l_spc
			  FROM pm 
			 WHERE prod_id = l_tabReplen_mnl (iIndex).prod_id
			   AND cust_pref_vendor = l_tabReplen_mnl (iIndex).cpv;

                        --
                        -- 06/21/2013
                        -- See if the inventory needs to be updated.  This is
                        -- based on the value in PRIORITY_CODE.UPDATE_INV for
                        -- the replenishment priority.  If 'N' then do not 
                        -- update inventory.   For demand replenishments
                        -- the value will be 'N'.
                        --
                      l_update_inv_flag :=  get_mnl_priority_upd_inv_flag(l_tabReplen_mnl(iIndex).task_id);

                      l_message := 'Deleting miniloader replenishment'
                         || '  task_id['      || TO_CHAR(l_tabReplen_mnl(iIndex).task_id)    || ']'
                         || '  prod_id['      || l_tabReplen_mnl(iIndex).prod_id             || ']'
                         || '  src_loc['      || l_tabReplen_mnl(iIndex).src_loc             || ']'
                         || '  inv_dest_loc[' || l_tabReplen_mnl(iIndex).inv_dest_loc        || ']'
                         || '  pallet_id['    || l_tabReplen_mnl(iIndex).pallet_id           || ']'
                         || '  qty['      || TO_CHAR(l_tabReplen_mnl(iIndex).qty)            || ']'
                         || '  uom['      || TO_CHAR(l_tabReplen_mnl(iIndex).uom)            || ']'
                         || '  orig_pallet_id['    || l_tabReplen_mnl(iIndex).orig_pallet_id || ']'
                         || '  l_update_inv_flag['    || l_update_inv_flag || ']';

                      pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                         NULL, NULL, ct_application_function, gl_pkg_name);


                        IF (l_update_inv_flag = 'Y') THEN
			   UPDATE inv
       			      SET qty_alloc =
                                    DECODE(l_tabReplen_mnl(iIndex).uom,
                                           1, DECODE(SIGN(qty_alloc - l_tabReplen_mnl(iIndex).qty),1,qty_alloc - l_tabReplen_mnl(iIndex).qty,0),
                                           2, DECODE(SIGN(qty_alloc - l_tabReplen_mnl(iIndex).qty * l_spc),1,qty_alloc - l_tabReplen_mnl(iIndex).qty * l_spc,0))
			    WHERE plogi_loc = l_tabReplen_mnl(iIndex).src_loc
			      AND logi_loc = l_tabReplen_mnl(iIndex).orig_pallet_id;   

			   IF (SQL%NOTFOUND) THEN
			      -- No row(s) updated. Log message and keep on going.
                              l_message := 'TABLE=inv  ACTION=UPDATE' ||
                              ' KEY=' ||  l_tabReplen_mnl(iIndex).orig_pallet_id || '(MNL orig pallet id)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to update INV when delete MNL repl task';
                              pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
			   END IF;

    			   DELETE inv
    			    WHERE logi_loc = l_tabReplen_mnl(iIndex).pallet_id
       			      AND plogi_loc = l_tabReplen_mnl(iIndex).dest_loc;

			   IF (SQL%NOTFOUND) THEN
                              l_message := 'TABLE=inv  ACTION=UPDATE' ||
                              ' KEY=' ||  l_tabReplen_mnl(iIndex).dest_loc || '(MNL inv_dest_loc)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to delete INV when delete MNL repl task';
                              pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
		   	   END IF;
                        END IF; -- IF (l_update_inv_flag = 'Y')

			DELETE	replenlst
			 WHERE	task_id = l_tabReplen_mnl (iIndex).task_id;


		        -- This will delete the record for Qty returned if there is any.
    		        DELETE replenlst
     		         WHERE src_loc = l_tabReplen_mnl(iIndex).src_loc
       		         AND dest_loc = src_loc
       		         AND pallet_id = l_tabReplen_mnl(iIndex).orig_pallet_id
       		         AND type = 'RLP';

 			-- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - Begin
    			DELETE FROM trans
			    WHERE batch_no = l_tabReplen_mnl(iIndex).batch_no
			    AND src_loc = l_tabReplen_mnl(iIndex).src_loc
			    AND dest_loc = l_tabReplen_mnl(iIndex).dest_loc
			    AND pallet_id = l_tabReplen_mnl(iIndex).pallet_id
			    AND trans_type = 'RPF'; 
			-- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - End

			 io_RowCnt := iIndex;

		        EXCEPTION WHEN OTHERS THEN
			      ROLLBACK; 
                              l_message := 'TABLE=replenlst  ACTION=DELETE,UPDATE' ||
                              ' KEY=' ||  l_tabReplen_mnl(iIndex).orig_pallet_id || '(MNL orig pallet_id)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to delete all MNL repl';
                              pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
			
		        END;
	        END LOOP;

           pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Ending procedure (i_last_qry,io_RowCnt)',
                          NULL, NULL, ct_application_function, gl_pkg_name);

	END delete_mnl_repl;


PROCEDURE delete_mnl_repl(i_tabTask  IN tabTask,
                         i_RowCnt    IN NUMBER,
                         o_delCnt    OUT NUMBER) IS
   
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(61) := 'delete_mnl_repl';
   l_update_inv_flag   priority_code.update_inv%TYPE;  -- Flag 
                                    -- that designates if the inventory needs to be updated when
                                    -- deleting the replenishment.  For demand replenishments
                                    -- this needs to be N.
   row_index NUMBER := i_tabTask.FIRST;

   CURSOR curReplen(iTask  NUMBER) IS
      SELECT r.task_id, r.prod_id, r.src_loc, r.dest_loc, r.inv_dest_loc,
             r.pallet_id, r.batch_no, r.qty, r.orig_pallet_id, r.priority, r.uom, pm.spc
        FROM replenlst r, pm
       WHERE r.task_id = iTask
         AND r.prod_id = pm.prod_id;
BEGIN
   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Starting procedure (i_tabTask,i_RowCnt,o_delCnt)',
                  NULL, NULL, ct_application_function, gl_pkg_name);

   o_delCnt := 0;

   LOOP
      EXIT WHEN row_index IS NULL;
      FOR rReplen IN curReplen (i_tabTask(row_index))
      LOOP
         l_update_inv_flag :=  get_mnl_priority_upd_inv_flag(rReplen.task_id);

         l_message := 'Deleting miniloader replenishment'
            || '  task_id['           || TO_CHAR(rReplen.task_id)    || ']'
            || '  prod_id['           || rReplen.prod_id             || ']'
            || '  src_loc['           || rReplen.src_loc             || ']'
            || '  inv_dest_loc['      || rReplen.inv_dest_loc        || ']'
            || '  pallet_id['         || rReplen.pallet_id           || ']'
            || '  qty['               || TO_CHAR(rReplen.qty)        || ']'
            || '  uom['               || TO_CHAR(rReplen.uom)        || ']'
            || '  orig_pallet_id['    || rReplen.orig_pallet_id      || ']'
            || '  priority['          || TO_CHAR(rReplen.priority)   || ']'
            || '  l_update_inv_flag[' || l_update_inv_flag           || ']';

         pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM, ct_application_function, gl_pkg_name);

         IF rReplen.priority <> 45 THEN
            BEGIN
               --
               -- 06/21/2013
               -- See if the inventory needs to be updated.  This is
               -- based on the value in PRIORITY_CODE.UPDATE_INV for
               -- the replenishment priority.  If 'N' then do not 
               -- update inventory.   For demand replenishments
               -- the value will be 'N'.
               --
               IF (l_update_inv_flag = 'Y') THEN

                  UPDATE inv
                     SET qty_alloc = DECODE(rReplen.uom,
                                            1, DECODE(SIGN(qty_alloc - rReplen.qty),1,qty_alloc - rReplen.qty,0),
                                            2, DECODE(SIGN(qty_alloc - rReplen.qty * rReplen.spc),1,qty_alloc - rReplen.qty * rReplen.spc,0))
                   WHERE plogi_loc = rReplen.src_loc
                     AND logi_loc = rReplen.orig_pallet_id;   

                  IF (SQL%NOTFOUND) THEN
                     -- No row(s) updated. Log message and keep on going.
                     l_message := 'TABLE=inv  ACTION=UPDATE' ||
                              ' KEY=' ||  rReplen.orig_pallet_id || '(orig pallet id)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to update INV when delete some MNL repl task';
                     pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                   l_message, SQLCODE, SQLERRM);
                  END IF;

                  DELETE inv
                   WHERE logi_loc = rReplen.pallet_id
                     AND plogi_loc = rReplen.dest_loc;

                  IF (SQL%NOTFOUND) THEN
                     l_message := 'TABLE=inv  ACTION=UPDATE' ||
                              ' KEY=' ||  rReplen.dest_loc || '(inv_dest_loc)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to delete INV when delete some MNL repl task';
                              pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
                  END IF;
               END IF;  -- end IF (l_update_inv_flag = 'Y')

               DELETE replenlst
                WHERE task_id = rReplen.task_id;

               -- This will delete the record for Qty returned if there is any.
               DELETE replenlst
                WHERE src_loc   = rReplen.src_loc
                  AND dest_loc  = src_loc
                  AND pallet_id = rReplen.orig_pallet_id
                  AND type      = 'RLP';

               -- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - Begin
               DELETE FROM trans
                WHERE batch_no    = rReplen.batch_no
                  AND src_loc     = rReplen.src_loc
                  AND dest_loc    = rReplen.dest_loc
                  AND pallet_id   = rReplen.pallet_id
                  AND trans_type  = 'RPF'; 
               -- 01/19/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE015 - End

               o_delCnt := o_delCnt + 1;
            EXCEPTION
               WHEN OTHERS THEN
                  ROLLBACK; 
                  o_delCnt := 0;
                  l_message := 'TABLE=replenlst  ACTION=DELETE,UPDATE' ||
                              ' KEY=' ||  rReplen.pallet_id || '(pallet_id)' ||
                              ' MESSAGE="SQL%NOTFOUND true.  Failed to delete some MNL repl';

                  pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                 l_message, SQLCODE, SQLERRM);
            END;
         ELSE
            pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Priority 45 miniloader replenishment task which cannot be deleted.',
                        NULL, NULL, ct_application_function, gl_pkg_name);
         END IF; -- End checking priority 45.
      END LOOP;
      row_index := i_tabTask.NEXT(row_index);
   END LOOP;

   pl_log.ins_msg(pl_lmc.ct_info_msg, l_object_name, 'Ending procedure (i_tabTask,i_RowCnt,o_delCnt)',
                  NULL, NULL, ct_application_function, gl_pkg_name);

END delete_mnl_repl;


        PROCEDURE commit_ndm_repl (i_tabTask      IN tabTask,
                                   i_RowCnt       IN NUMBER,
				   o_recCnt       IN OUT NUMBER) IS
        -- Variables to store statistics returned by the procedure pl_mlf.
           l_no_records_processed         NUMBER;
           l_no_batches_created           NUMBER;
           l_no_batches_existing          NUMBER;
           l_no_not_created_due_to_error  NUMBER;
   
           l_message       VARCHAR2(512);    -- Message buffer
           l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                            '.commit_ndm_repl';
	   row_index NUMBER := i_tabTask.FIRST;

	   CURSOR curReplen (iTask Number) IS
			SELECT task_id, src_loc, dest_loc, inv_dest_loc, pallet_id, qty, batch_no, gen_date, gen_uid
			  FROM replenlst
			 WHERE task_id = iTask;

        BEGIN
		   o_recCnt := 0;
		   LOOP 
			EXIT WHEN row_index IS NULL; 
			FOR rReplen IN curReplen (i_tabTask(row_index))
			LOOP
		    	   UPDATE replenlst
		       	      SET status = 'NEW'
		     	    WHERE task_id = rReplen.task_id
		       	      AND pallet_id = rReplen.pallet_id;

			   o_recCnt := o_recCnt + 1;

		  	   BEGIN
   				pl_lmf.create_nondemand_rpl_batch(rReplen.task_id,
                               				         l_no_records_processed,
                                     				 l_no_batches_created,
                                     				 l_no_batches_existing,
                                     				 l_no_not_created_due_to_error);

			        IF (l_no_not_created_due_to_error = 1) THEN
                                   l_message := 'Labor batch not created for dest loc ' || 
              			                 rReplen.dest_loc || ', pallet ' || rReplen.pallet_id || '.' ||
						' Check swms log for reason why.';
                                   pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                             l_message, SQLCODE, SQLERRM);
   				END IF;
   			   EXCEPTION
			      WHEN OTHERS THEN
			         ROLLBACK; 
			         o_recCnt := 0;
                                 l_message := 'pl_lmf.create_nondemand_rpl_batch ACTION=DELETE,UPDATE' ||
                                 ' KEY=' ||  rReplen.pallet_id || '(pallet_id)' || rReplen.task_id ||
                                 ' MESSAGE= Failed to create NDM repl batch';
                                 pl_log.ins_msg(pl_lmc.ct_fatal_msg, l_object_name,
                                                l_message, SQLCODE, SQLERRM);
			   END;

		   	END LOOP;

			row_index := i_tabTask.NEXT(row_index);

		   END LOOP;

	END commit_ndm_repl;

        --PROCEDURE commit_rlp_repl (o_recCnt      OUT number)
        PROCEDURE commit_rlp_repl
        IS
		CURSOR c_commited_mnl_repl IS
			SELECT orig_pallet_id, src_loc, add_user
			  FROM replenlst
			 WHERE type = 'MNL' AND status = 'NEW';

	        r_commited_mnl_repl      c_commited_mnl_repl%ROWTYPE;
                l_message       VARCHAR2(512);    -- Message buffer
                l_object_name   VARCHAR2(61) := gl_pkg_name ||
                                            '.commit_rlp_repl';
	BEGIN
	      IF NOT c_commited_mnl_repl%ISOPEN
      	      THEN
         	OPEN c_commited_mnl_repl;
      	      END IF;

	--      o_recCnt := 0;
 	      LOOP
		  FETCH c_commited_mnl_repl
	           INTO r_commited_mnl_repl;
  
		  EXIT WHEN c_commited_mnl_repl%NOTFOUND
               		 OR c_commited_mnl_repl%NOTFOUND IS NULL;

		  UPDATE replenlst 
		     SET status = 'NEW'
		   WHERE status = 'PRE'
		     AND type = 'RLP'
		     AND src_loc = r_commited_mnl_repl.src_loc
		     AND dest_loc = r_commited_mnl_repl.src_loc
		     AND pallet_id = r_commited_mnl_repl.orig_pallet_id;

	--	  IF (SQL%ROWCOUNT > 0) THEN
	--              o_recCnt := o_recCnt + 1;
        --          END IF;
	       END LOOP;

               CLOSE c_commited_mnl_repl;

	EXCEPTION
	WHEN OTHERS
	THEN
            IF c_commited_mnl_repl%ISOPEN
            THEN
               CLOSE c_commited_mnl_repl;
            END IF;
 	    --o_recCnt := 0; 
            l_message := 'Failed to commit RLP records.' ;
            pl_log.ins_msg ('FATAL', l_object_name, l_message, SQLCODE, SQLERRM);

	END commit_rlp_repl;

END pl_swms_execute_sql;
/
