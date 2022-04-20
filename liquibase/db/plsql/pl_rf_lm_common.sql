CREATE OR REPLACE PACKAGE          pl_rf_lm_common IS

/*******************************************************************************
**Package:
**        pl_rf_lm_common. Migrated from lm_common.pc
**
**Description:
**        Generic functions for labor management.
**
**Called by:
**        This is a Common package called from many programs.
-- 9/9/21 mcha1213 modify lmc_rf_logout for LR
*******************************************************************************/

    FUNCTION Lmc_Get_Last_Complete_Batch (
        i_user_id	        IN     batch.user_id%TYPE,
        o_batch_no	        OUT    batch.batch_no%TYPE  )
    RETURN rf.status;

    FUNCTION Lmc_Batch_Is_Active_Check (
        i_batch_no 	        IN     batch.batch_no%TYPE  )
    RETURN rf.status;

    FUNCTION Lmc_Find_Active_Batch (
        i_user_id 	        IN     batch.user_id%TYPE ,
        o_batch_no	        OUT    batch.batch_no%TYPE ,
        o_is_parent_flag    OUT    VARCHAR2 )
    RETURN rf.status;

    FUNCTION Lmc_Merge_Batch (
        i_batch_no          IN     batch.batch_no%TYPE ,
        i_parent_batch_no   IN     batch.parent_batch_no%TYPE )
    RETURN rf.status;

    FUNCTION Lmc_Signon_To_Batch (
        i_batch_no          IN     batch.batch_no%TYPE ,
        i_user_id           IN     batch.user_id%TYPE,
        i_supervisor_id     IN     batch.user_supervsr_id%TYPE,
        i_equip_id          IN     batch.equip_id%TYPE,
        i_previous_batch_no IN     batch.batch_no%TYPE )
    RETURN rf.status;

	FUNCTION Lmc_Insert_Into_Float_Hist (
		i_batch_no			IN	   batch.batch_no%TYPE  )
	RETURN rf.status;

    FUNCTION Lmc_Signoff_From_batch (
        i_batch_no          IN     batch.batch_no%TYPE  )
    RETURN rf.status;

	FUNCTION Lmc_Get_Haul_Location (
		i_pallet_id			IN     trans.pallet_id%TYPE,
		o_dest_loc			OUT	   trans.dest_loc%TYPE )
	RETURN rf.status;

	PROCEDURE Lmc_Sel_3_Part_Move_Syspar (
		o_3_part_move_bln   OUT    NUMBER );

	FUNCTION Lmc_Is_Three_Part_Move_Active (
		i_psz_loc			IN	   loc.logi_loc%TYPE )
	RETURN rf.status;

	FUNCTION Lmc_Is_Forklift (
		i_batch_no			IN	   batch.batch_no%TYPE )
	RETURN NUMBER;

    FUNCTION Lmc_Get_Last_Batch (
        i_user_id           IN     batch.user_id%TYPE,
        i_batch_no          IN     batch.batch_no%TYPE ,
        o_batch_no          OUT    batch.batch_no%TYPE ,
        o_status            OUT    VARCHAR2,
        o_job_code          OUT    batch.jbcd_job_code%TYPE,
        o_equip_id          OUT    batch.equip_id%TYPE,
        o_is_parent         OUT    VARCHAR2  )
    RETURN NUMBER;

    PROCEDURE Lmc_Rf_Logout (
        i_user_id           IN     batch.user_id%TYPE,
        i_logout_option     IN     VARCHAR2,
        i_logout_from       IN     NUMBER,
        o_status            OUT    NUMBER );

    FUNCTION lmc_labor_mgmt_active RETURN rf.status;

    FUNCTION lmc_get_duration (
        i_user_id           IN     batch.user_id%TYPE,
        i_jobcode           IN     batch.jbcd_job_code%TYPE,
        i_labor_group       IN     usr.lgrp_lbr_grp%TYPE,
        o_dur               OUT    sched_type.start_dur%TYPE )
    RETURN rf.status;

    FUNCTION lmc_batch_istart (
        i_user_id           IN     batch.user_id%TYPE ,
        o_prev_batch_no     OUT    batch.batch_no%TYPE ,
        o_supervisor_id     OUT    batch.user_supervsr_id%TYPE )
    RETURN rf.status;

END pl_rf_lm_common;
/


CREATE OR REPLACE PACKAGE BODY                            pl_rf_lm_common IS

------------------------------------------------------------------------------
/*                      GLOBAL DECLARATIONS                                */
------------------------------------------------------------------------------

ORACLE_PRIMARY_KEY_CONSTRAINT EXCEPTION;
PRAGMA EXCEPTION_INIT(ORACLE_PRIMARY_KEY_CONSTRAINT, -1400);

------------------------------------------------------------------------------
/*       CONSTANT VARIABLES FOR LABOR MANAGEMENT FUNCTIONS                  */
------------------------------------------------------------------------------

	LM_LAST_IS_ISTOP        NUMBER := 9999;
	BATCH_TYPE_FK           NUMBER := -201;
	BATCH_TYPE_NOTFK        NUMBER := -202;
	BATCH_TYPE_NOBATCH      NUMBER := -203;

	LOGOUT_OPTION_L         VARCHAR2(1) := 'L';
	LOGOUT_OPTION_S         VARCHAR2(1) := 'S';
	LOGOUT_OPTION_C         VARCHAR2(1) := 'C';

-------------------------------------------------------------------------------
/**                     PUBLIC MODULES                                      **/
-------------------------------------------------------------------------------

/*******************************************************************************
**Function:
**        Lmc_Get_Last_Complete_Batch
**
** Description:
**        This function finds the user's last completed batch.
**
**
** Input:
**     i_user_id     -  User being assigned to batch.
**
** Output:
**     o_batch_no    -  Current active batch returned to calling function.
**
*******************************************************************************/

  FUNCTION Lmc_Get_Last_Complete_Batch (
        i_user_id	        IN     batch.user_id%TYPE,
        o_batch_no	        OUT    batch.batch_no%TYPE )
  RETURN rf.status IS

        l_function_name         VARCHAR2(40) := 'LMC_GET_LAST_COMPLETE_BATCH';
        l_ret_val               rf.status := rf.STATUS_NORMAL;
        l_batch_no              batch.batch_no%TYPE;

        CURSOR cbatch IS
            SELECT batch_no
            FROM batch
            WHERE status = 'C'
                AND user_id = replace(i_user_id,'OPS$',null)
            ORDER BY actl_stop_time DESC,
                     actl_start_time DESC,
                     DECODE(jbcd_job_code, 'ISTART', 1,
                                           'IWASH', 1, 0);

  BEGIN
        pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Get_Last_Complete_Batch with user_id : ' || i_user_id ||
        ' o_batch_no. '|| SQLERRM, SQLCODE, SQLERRM);

        /*
        ** This cursor selects the last completed batch for a user.
        ** An ISTART can have the same actl_start_time as the following
        ** batch so we need to be sure it does not get selected first.
        ** If there is an IWASH and ISTOP with the same actl_start_time
        ** then select the ISTOP first.
        */

        BEGIN
            OPEN cbatch;

            FETCH cbatch INTO o_batch_no;

			IF cbatch%rowcount = 0 THEN

				pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE - No completed batch found for user.' ||
                SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;
			END IF;

            CLOSE cbatch;
pl_text_log.ins_msg_async('INFO', l_function_name, 'Lmc_Get_Last_Complete_Batch rf_status = ' ||l_ret_val||'o_batch_no  ='||o_batch_no
                , SQLCODE, SQLERRM);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE - Failed looking for last complete batch.' ||
                SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;

        END;

        RETURN l_ret_val;

  END Lmc_Get_Last_Complete_Batch;

-------------------------------------------------------------------------------
/**Function:
**        Lmc_Batch_Is_Active_Check
**
** Description:
**        This function checks the status of a batch.
**
** Input:
**     i_batch_no char     - The batch to check.
**
*******************************************************************************/

  FUNCTION Lmc_Batch_Is_Active_Check (
        i_batch_no 	        IN     batch.batch_no%TYPE )
  RETURN rf.status IS

        l_function_name     VARCHAR2(40):= 'LMC_BATCH_IS_ACTIVE_CHECK';
        l_ret_val           rf.status := rf.STATUS_NORMAL;
        l_parent_batch_no   batch.parent_batch_no%TYPE;
        l_status            VARCHAR2(1);
        l_p_status          VARCHAR2(1);

  BEGIN
        pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Batch_Is_Active_Check with batch_no : ' || i_batch_no, SQLCODE, SQLERRM);

        BEGIN

            SELECT status,
			   parent_batch_no
            INTO l_status,
		     l_parent_batch_no
            FROM batch
            WHERE batch_no = i_batch_no;
            pl_text_log.ins_msg_async('INFO', l_function_name, 'l_status 1....' || l_status, SQLCODE, SQLERRM);
            pl_text_log.ins_msg_async('INFO', l_function_name, 'parent_batch_no 1....' || l_parent_batch_no, SQLCODE, SQLERRM);

            IF l_status = 'A' THEN
                l_ret_val := rf.STATUS_LM_ACTIVE_BATCH;

            ELSIF l_status = 'C' THEN
                l_ret_val := rf.STATUS_LM_BATCH_COMPLETED;

            ELSIF l_status = 'M' THEN
               BEGIN
                    SELECT status
                    INTO l_p_status
                    FROM batch
                    WHERE batch_no = l_parent_batch_no;
                    IF l_p_status = 'A' THEN
                        l_ret_val := rf.STATUS_LM_ACTIVE_BATCH;

                    ELSIF l_p_status = 'C' THEN
                        l_ret_val := rf.STATUS_LM_BATCH_COMPLETED;

                    END IF;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('FATAL', l_function_name, 'LMC ORACLE Failed looking up status on parent batch.'
                        || SQLERRM, SQLCODE, SQLERRM);

                        l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;

                END;

            END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('FATAL', l_function_name, 'LMC ORACLE Failed looking up status on batch.' ||
                SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;

        END;

        pl_text_log.ins_msg_async('INFO', l_function_name, 'Ending Lmc_Batch_Is_Active_Check l_ret_val = ' || l_ret_val, SQLCODE, SQLERRM);

        RETURN l_ret_val;

  END Lmc_Batch_Is_Active_Check;

/*******************************************************************************
**Function:
**        Lmc_Find_Active_Batch
**
** Description:
**        This function finds the user's current active batch.
**        It also sets a flag denoting whether or not the active batch is
**        a parent batch or not.
**
**        All users on labor management must have an active batch during their
**        shift!
**
** Input:
**     i_user_id     -  User being assigned to batch.
**
** Output:
**     o_batch_no          - Current active batch returned to calling function.
**     o_is_parent_flag    - Flag returned to calling function denoting
**                            whether the current active batch is a parent
**                            batch.
**
*******************************************************************************/

  FUNCTION Lmc_Find_Active_Batch (
        i_user_id 	        IN     batch.user_id%TYPE,
        o_batch_no	        OUT    batch.batch_no%TYPE,
        o_is_parent_flag    OUT    VARCHAR2 )
  RETURN rf.status IS

        l_function_name         VARCHAR2(40) := 'LMC_FIND_ACTIVE_BATCH';
        l_ret_val               rf.status := rf.STATUS_NORMAL;
        l_batch_no              VARCHAR2(14);
        l_is_parent_flag        VARCHAR2(1);
        l_num_recs              NUMBER := 0;
        l_is_istop              VARCHAR2(1);
        NOT_FOUND               EXCEPTION;

        CURSOR c_active_batch_cur (c_user_id IN VARCHAR2) IS
              SELECT batch_no,
                  DECODE(parent_batch_no, NULL, 'N', 'Y') as is_parent_flag
              FROM batch
              WHERE status = 'A'
                AND user_id = replace(c_user_id, 'OPS$', NULL);

        CURSOR c_istop_cur IS
              SELECT 'Y'
              FROM batch
              WHERE jbcd_job_code = 'ISTOP'
                AND batch_no = o_batch_no;

  BEGIN
        pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Find_Active_Batch with user_id : ' || i_user_id , SQLCODE, SQLERRM);

        o_is_parent_flag := 'N';

        BEGIN

            l_num_recs := 0;

            FOR r_active_batch_cur IN c_active_batch_cur(i_user_id)
            LOOP

                l_batch_no := r_active_batch_cur.batch_no;
                l_is_parent_flag := r_active_batch_cur.is_parent_flag;

                l_num_recs := l_num_recs + 1;
            END LOOP;

            /*
            ** The user has an active batch.
            */

            IF l_num_recs = 0 THEN

                RAISE NOT_FOUND;

            ELSIF l_num_recs > 1 THEN
                /*
                ** The user has more than one active batch which is an error.
                */
                l_ret_val := rf.STATUS_LM_MULTI_ACTIVE_BATCH;

                pl_text_log.ins_msg_async('ERROR', l_function_name, 'ERROR  User has more than one active batch.'
                || SQLERRM, SQLCODE, SQLERRM);

            ELSE
                /*
                ** The user has one active batch.
                */

                o_batch_no := l_batch_no;
                o_is_parent_flag := l_is_parent_flag;

                pl_text_log.ins_msg_async('DEBUG', l_function_name, 'The active batch for user ' || i_user_id || ' is ' || o_batch_no
                || SQLERRM, SQLCODE, SQLERRM);

            END IF;

        EXCEPTION
            WHEN NOT_FOUND THEN
                /*
                ** The user does not have an active batch.
                ** Check the last completed batch for an ISTOP.  If it is, then pass
                ** a flag to the calling routine to allow the user to signon to a
                ** batch.
                */

                l_ret_val := Lmc_Get_Last_Complete_Batch(i_user_id, o_batch_no);

                pl_text_log.ins_msg_async('INFO', l_function_name, 'Lmc_Get_Last_Complete_Batch rf_status = ' || l_ret_val
                            , SQLCODE, SQLERRM);
                IF l_ret_val = 0 THEN
                    l_is_istop := 'N';

                    OPEN c_istop_cur;

                        FETCH c_istop_cur INTO l_is_istop;
            pl_text_log.ins_msg_async('INFO', l_function_name, 'l_is_istop....' || l_is_istop, SQLCODE, SQLERRM);
						IF c_istop_cur%rowcount = 0 THEN

							pl_text_log.ins_msg_async('WARN', l_function_name, 'LMC ORACLE No record found for batch ' || o_batch_no ||
                            ' with job code ISTOP.' || SQLERRM, SQLCODE, SQLERRM);

                            l_ret_val := rf.STATUS_LM_NO_ACTIVE_BATCH;

						ELSE
							l_ret_val := LM_LAST_IS_ISTOP;
						END IF;

                    CLOSE c_istop_cur;


                ELSE

                    l_ret_val := rf.STATUS_LM_NO_ACTIVE_BATCH;
                    pl_text_log.ins_msg_async('INFO', l_function_name, 'inside else rf_status = ' || l_ret_val
                            , SQLCODE, SQLERRM);
                END IF;

            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_function_name, 'LMC ORACLE Failed looking for current active batch.'
                || SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_LM_NO_ACTIVE_BATCH;

        END;

        pl_text_log.ins_msg_async('INFO', l_function_name, 'Ending Lmc_Find_Active_Batch with user_id : ' || i_user_id || ' and l_ret_val' || l_ret_val, SQLCODE, SQLERRM);

        RETURN l_ret_val;

  END Lmc_Find_Active_Batch;

/*******************************************************************************
**Function:
**        Lmc_Merge_Batch
**
** Description:
**        This function merges the specified batch with the parent batch.
**        A parent batch can be designated if a parent does not exists.
**
**
** Input:
**     i_batch_no            - Batch to be merged.
**     i_parent_batch_no     - Parent Batch.
**
*******************************************************************************/

  FUNCTION Lmc_Merge_Batch (
        i_batch_no          IN     batch.batch_no%TYPE,
        i_parent_batch_no   IN     batch.parent_batch_no%TYPE )
  RETURN rf.status IS

        l_function_name         VARCHAR2(40) := 'LMC_MERGE_BATCH';
        l_ret_val               rf.status := rf.STATUS_NORMAL;
        l_target_time           NUMBER;
        l_goal_time             NUMBER;
        l_parent_batch_date     VARCHAR2(9);

  BEGIN
        pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Merge_Batch with batch_no : ' || i_batch_no ||
         ' and parent_batch_no : ' || i_parent_batch_no || SQLERRM, SQLCODE, SQLERRM);

        BEGIN
            SELECT NVL(target_time, 0),
                   NVL(goal_time, 0)
            INTO l_target_time,
                 l_goal_time
            FROM batch
            WHERE batch_no = i_batch_no;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to get target and goal time LM batch'
                || SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;

        END;

        IF l_ret_val = 0 THEN
            BEGIN
                SELECT TO_CHAR(parent_batch_date, 'MMDDYYYY')
                INTO l_parent_batch_date
                FROM batch
                WHERE batch_no = i_parent_batch_no;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to get parent batch date for LM batch'
                    || SQLERRM, SQLCODE, SQLERRM);

                    l_ret_val := rf.STATUS_NO_LM_PARENT_FOUND;

            END;

        END IF;

        IF l_ret_val = 0 THEN
            /**Removed truncating the actl_stop_time to the minute.**/
            BEGIN
                UPDATE batch
                SET status = 'M',
                    actl_stop_time = SYSDATE,
                    parent_batch_no = i_parent_batch_no,
                    parent_batch_date = TO_DATE(l_parent_batch_date, 'MMDDYYYY'),
                    goal_time = 0,
                    target_time = 0,
                    total_count = 0,
                    total_pallet = 0,
                    total_piece = 0
                WHERE batch_no = i_batch_no;

                IF SQL%rowcount = 0 THEN

                    pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to set LM batch to merged'
                    || SQLERRM, SQLCODE, SQLERRM);

                    l_ret_val := rf.STATUS_LM_BATCH_UPD_FAIL;

                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('FATAL', l_function_name, 'LMC ORACLE Unable to set LM batch to merged'
                    || SQLERRM, SQLCODE, SQLERRM);

                    l_ret_val := rf.STATUS_DATA_ERROR;

            END;

        END IF;

        IF l_ret_val = 0 THEN
            BEGIN
                UPDATE batch
                SET target_time = target_time + l_target_time,
                    goal_time = goal_time + l_goal_time,
                    total_count = total_count + 1,
                    total_pallet = total_pallet + 1
                WHERE batch_no = i_parent_batch_no;

                IF SQL%rowcount = 0 THEN

                    pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to add target and goal times to LM parent batch'
                    || SQLERRM, SQLCODE, SQLERRM);

                    l_ret_val := rf.STATUS_LM_PARENT_UPD_FAIL;
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to add target and goal times to LM parent batch'
                    || SQLERRM, SQLCODE, SQLERRM);

                    l_ret_val := rf.STATUS_DATA_ERROR;

            END;

        END IF;

        RETURN l_ret_val;

  END Lmc_Merge_Batch;

/*******************************************************************************
**Function:
**        Lmc_Signon_To_Batch
**
** Description:
**        This function attaches a user to the specified forklift batch.
**
**
** Input:
**     i_batch_no          - Batch to attach to.
**     i_user_id           - User performing operation.
**     i_supervisor_no     - Users supervisor id
**     i_equip_id          - Equipment being used.
**     i_previous_batch_no - The batch the user just signed off of (see note).
**                            The actl_start_time of the batch being signed
**                            onto will be set to the actl_stop_time of
**                            the previous batch unless the previous batch
**                            is an ISTOP in which case the actl_start_time
**                            is set to the sysdate.
**                            NOTE:  If i_previous_batch_no is
**                            a parent batch then it will still be an active
**                            batch thus the actl_stop_time will be null so
**                            the actl_start_time of i_batch_no will be
**                            set to sysdate.  i_batch_no is in the process
**                            of being merged with i_previous_batch_no.
**
*******************************************************************************/

  FUNCTION Lmc_Signon_To_Batch (
        i_batch_no          IN     batch.batch_no%TYPE,
        i_user_id           IN     batch.user_id%TYPE,
        i_supervisor_id     IN     batch.user_supervsr_id%TYPE,
        i_equip_id          IN     batch.equip_id%TYPE,
        i_previous_batch_no IN     batch.batch_no%TYPE )
  RETURN rf.status IS

        l_function_name         VARCHAR2(40) := 'LMC_SIGNON_TO_BATCH';
        l_ret_val               rf.status := rf.STATUS_NORMAL;
        l_status                batch.status%TYPE;

  BEGIN
        pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Signon_To_Batch with batch_no : ' || i_batch_no || ', user_id : '
        || i_user_id || ', supervisor_id : ' || i_supervisor_id || ', equip_id : ' || i_equip_id || ', previous_batch_no : '
        || i_previous_batch_no || SQLERRM, SQLCODE, SQLERRM);

        /*
    	**  Get the status of the batch to signon to.
    	*/
        BEGIN
            SELECT status INTO l_status
            FROM batch
            WHERE batch_no = i_batch_no;

            IF l_status = 'C' THEN
                /* The batch is completed.  Cannot signon to a completed batch. */
                pl_text_log.ins_msg_async('DEBUG', l_function_name, 'LMC ORACLE Batch already completed' || SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_LM_BATCH_COMPLETED;

            ELSIF l_status = 'F' THEN
                /*
        		**  The batch is a future batch.  Signon to it.
        		**  Must go to seconds because of the criticality of the order of
        		**  batch assignment for forklift distance/movement processing.
        		**
        		**  The comments for i_previous_batch_no explains why the
        		**  DECODE is used in the sub query.
        		*/
                BEGIN
                    UPDATE batch
                    SET status = 'A',
                        user_id = replace(i_user_id,'OPS$',NULL),
                        user_supervsr_id = i_supervisor_id,
                        equip_id = i_equip_id,
                        actl_start_time =
                            (SELECT DECODE(b2.jbcd_job_code, 'ISTOP', SYSDATE,
                                    NVL(b2.actl_stop_time, SYSDATE))
                             FROM batch b2
                             WHERE b2.batch_no = i_previous_batch_no)
                    WHERE batch_no = i_batch_no;

                    IF SQL%rowcount = 0 THEN

                        pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to activate LM batch' || SQLERRM, SQLCODE, SQLERRM);

                        l_ret_val := rf.STATUS_LM_BATCH_UPD_FAIL;
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to activate LM batch' || SQLERRM, SQLCODE, SQLERRM);
                        l_ret_val := rf.STATUS_DATA_ERROR;

            	END;

            ELSIF l_status = 'W' THEN
                /*
        		** Signing onto a suspended batch after a break away.
        		** Set the status to A and set the actual start time to the actual
        		** stop time of the previous batch.
        		**
        		** If there are child batches then leave the status as M and w
        		** set the actual start time and actual stop time.
        		*/
                BEGIN
                    UPDATE batch
                    SET status = 'A',
                        resumed_after_break_away_flag = 'Y',
                        actl_start_time  =
                            (SELECT DECODE(b2.jbcd_job_code, 'ISTOP', SYSDATE,
                                    NVL(b2.actl_stop_time, SYSDATE))
                             FROM batch b2
                             WHERE b2.batch_no = i_previous_batch_no)
                    WHERE status = 'W'
                        AND batch_no = i_batch_no;

                    IF SQL%rowcount = 0 THEN

                        pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to activate suspended LM batch'
                        || SQLERRM, SQLCODE, SQLERRM);

                        l_ret_val := rf.STATUS_LM_BATCH_UPD_FAIL;
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to activate suspended LM batch'
                        || SQLERRM, SQLCODE, SQLERRM);

                        l_ret_val := rf.STATUS_DATA_ERROR;

                END;

                /*
        		** 05/14/2010 Brian Bent
        		** Update the child(merge) batches, if any.
        		** Try to keep the same spread in the actual start time as the
        		** initial pickup. I stuck the ABS as a fail safe.  The one thing
        		** we want is to have the actual start time of the child batch after
        		** the actual start time of the parent batch.
        		*/
                BEGIN
                    UPDATE batch b
                    SET resumed_after_break_away_flag = 'Y',
                        b.actl_start_time  =
                            (SELECT b2.actl_start_time +
                                    ABS((b.initial_pickup_scan_date -
                                    b2.initial_pickup_scan_date))
                             FROM batch b2
                             WHERE b2.batch_no = i_batch_no)
                    WHERE b.status = 'M'
                        AND b.parent_batch_no = i_batch_no;

                    IF SQL%rowcount = 0 THEN
                        pl_text_log.ins_msg_async('WARN', l_function_name, 'LMC ORACLE  LM batch is not updated' || SQLERRM, SQLCODE, SQLERRM);
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to update LM batch' || SQLERRM, SQLCODE, SQLERRM);
                        l_ret_val := rf.STATUS_DATA_ERROR;

                END;

                /*
        		** The actual stop time for the child batches will be the same
        		** as the actual start time.
        		*/
                BEGIN
                    UPDATE batch b
                    SET b.actl_stop_time = b.actl_start_time
                    WHERE b.status = 'M'
                          AND b.parent_batch_no = i_batch_no;

                    IF SQL%rowcount = 0 THEN
                        pl_text_log.ins_msg_async('WARN', l_function_name, 'LMC ORACLE Unable to update LM batch' || SQLERRM, SQLCODE, SQLERRM);
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to update LM batch' || SQLERRM, SQLCODE, SQLERRM);
                        l_ret_val := rf.STATUS_DATA_ERROR;
                END;

            ELSIF l_status = 'N' THEN
                /*
        		** The batch has a status 'N'.  A user should never be signing onto
        		** a batch with this status.  This status is used to mark the batch
        		** the user is getting ready to sign onto when completing the
        		** previous batch.  The batch only has this status for a very short
        		** time and if a batch is left with this status then a breakdown in
        		** processing occurred.
        		*/
                pl_text_log.ins_msg_async('WARN', l_function_name, 'Batch ' || i_batch_no || ' has status ' || l_status ||
                ' which should not happen.' || SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_LM_N_STATUS_BATCH;

            ELSE
                /*
        		** The batch has a status that it should not at this point in the
        		** processing.
        		*/
                pl_text_log.ins_msg_async('WARN', l_function_name, 'Batch ' || i_batch_no || ' has status ' || l_status ||
                ' which is invalid at this point in the processing.' || SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;

            END IF;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to find LM batch' || SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_NO_LM_BATCH_FOUND;

        END;

        RETURN l_ret_val;

  END Lmc_Signon_To_Batch;

/*******************************************************************************
**Function:
**        Lmc_Insert_Into_Float_Hist
**
** Description:
**        This function loads a float history record for the specified batch
**     	  that has been completed.
**
** Parameters:
**
** Input:
**     i_batch_no     -  The labor mgmt batch to insert the FLOAT_HIST record for.
**
*******************************************************************************/

  FUNCTION Lmc_Insert_Into_Float_Hist (
		i_batch_no			IN	   batch.batch_no%TYPE )
	RETURN rf.status IS

		l_function_name         VARCHAR2(60) := 'LMC_INSERT_INTO_FLOAT_HIST';
		l_ret_val               rf.status := rf.STATUS_NORMAL;
		l_psz_float_no          VARCHAR2(9);
		l_batch_type            VARCHAR2(1);

	BEGIN
		pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Insert_Into_Float_Hist with batch_no : ' || i_batch_no ||
        SQLERRM, SQLCODE, SQLERRM);

		l_psz_float_no := SUBSTR(i_batch_no, 3, 9);
		l_batch_type := SUBSTR(i_batch_no, 2, 1);

		/*
		** The float batch number is needed.
		*/
		BEGIN
			INSERT INTO float_hist (batch_no,
									route_no,
                                    user_id,
									prod_id,
                                    cust_pref_vendor,
									order_id,
                                    order_line_id,
									cust_id,
                                    qty_order,
									qty_alloc,
                                    merge_alloc_flag,
									stop_no,
                                    src_loc,
									uom,
                                    ship_date,
                                    float_no)
                            SELECT TO_CHAR(f.batch_no),
									f.route_no,
                                    USER,
									fd.prod_id,
                                    fd.cust_pref_vendor,
									fd.order_id,
                                    fd.order_line_id,
									o.cust_id,
                                    fd.qty_order,
									fd.qty_alloc,
                                    fd.merge_alloc_flag,
									fd.stop_no,
                                    fd.src_loc,
									NVL(fd.uom, 2),
                                    o.ship_date,
                                    f.float_no
                                FROM ordm o,
									 float_detail fd,
									 floats f
								WHERE o.order_id = fd.order_id
									  AND fd.qty_alloc <> 0
									  AND fd.merge_alloc_flag <> 'M'
									  AND fd.float_no = f.float_no
									  AND f.pallet_pull IN ('Y', 'B')
									  AND f.float_no = TO_NUMBER(l_psz_float_no);

			/*IF no errors, Insert successful.*/

		EXCEPTION
			WHEN DUP_VAL_ON_INDEX THEN
				/*
				** Unique constraint violation.  This is not a show stopper.
				*/
				pl_text_log.ins_msg_async('WARN', l_function_name, 'LMC ORACLE Unable to create float hist entry for LM batch because
                of unique constraint.  This is not a fatal error.' || SQLERRM, SQLCODE, SQLERRM);

			WHEN ORACLE_PRIMARY_KEY_CONSTRAINT THEN
				/*
				** Primary key constraint violation.  This is not a show stopper.
				*/
				pl_text_log.ins_msg_async('WARN', l_function_name, 'LMC ORACLE Unable to create float hist entry for LM batch because
                of primary key constraint.  This is not a fatal error.' || SQLERRM, SQLCODE, SQLERRM);

			WHEN OTHERS THEN
				pl_text_log.ins_msg_async('ERROR', l_function_name, 'LMC ORACLE Unable to create float hist entry for LM batch' ||
                SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_LM_BATCH_UPD_FAIL;

		END;

		RETURN l_ret_val;

  END Lmc_Insert_Into_Float_Hist;

/*******************************************************************************
**Function:
**        Lmc_Signoff_From_batch
**
** Description:
**        This function completes a forklift batch.
**
** Input:
**     i_batch_no            -  Batch to complete.
**
*******************************************************************************/

  FUNCTION Lmc_Signoff_From_batch (
        i_batch_no          IN     batch.batch_no%TYPE )
  RETURN rf.status IS

        l_function_name         VARCHAR2(40) := 'LMC_SIGNOFF_FROM_BATCH';
        l_ret_val               rf.status := rf.STATUS_NORMAL;
        l_time_spent            NUMBER := 00.00;
        l_batch_no              batch.batch_no%TYPE ;
        l_batch_no_1              batch.batch_no%TYPE ;

  BEGIN
        pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Signoff_From_batch with batch_no : ' || i_batch_no
        || SQLERRM, SQLCODE, SQLERRM);

        /*
        **  Call database procedure to signoff the batch.  The procedure
        **  insert breaks/lunches and sets the batch to completed.  It passes
        **  back the time spent which is not needed but we need a variable
        **  to store it in.
        */
        BEGIN
            select batch_no into l_batch_no from batch where batch_no = i_batch_no;

            pl_lm1.create_schedule(i_batch_no, SYSDATE, l_time_spent);
        EXCEPTION
            WHEN OTHERS THEN
                pl_text_log.ins_msg_async('FATAL', l_function_name, 'LMC ORACLE Unable to complete LM batch.  pl_lm1.create_schedule
                generated an error.' || SQLERRM, SQLCODE, SQLERRM);

                l_ret_val := rf.STATUS_LM_BATCH_UPD_FAIL;

        END;

        IF l_ret_val = 0 THEN
            IF (SUBSTR(i_batch_no, 2, 1 ) = 'U') THEN
                l_ret_val := lmc_insert_into_float_hist(i_batch_no);
            END IF;
        END IF;

        RETURN l_ret_val;

  END Lmc_Signoff_From_batch;

/*******************************************************************************
**Function:
**        Lmc_Get_Haul_Location
**
** Description:
**        This function gets the current location of a pallet if
**        if has been hauled.  The location is selected from the TRANS table
**        where trans_type = HAL.  If the pallet was never hauled then
**        o_dest_loc is set to a null string.  The calling function will need
**        to check the length of the destination location variable to see if
**        the pallet was hauled.
**
**
** Input:
**     i_pallet    -- The pallet being processed.
**
** Output:
**     o_dest_loc  -- The location the pallet was hauled to.
**
*******************************************************************************/

  FUNCTION Lmc_Get_Haul_Location (
		i_pallet_id			IN     trans.pallet_id%TYPE,
		o_dest_loc			OUT	   trans.dest_loc%TYPE )
  RETURN rf.status IS

		l_function_name         VARCHAR2(40) := 'LMC_GET_HAUL_LOCATION';
		l_status                rf.status := rf.STATUS_NORMAL;

		CURSOR c_dest_loc_cur IS
			SELECT dest_loc
            FROM trans t1
            WHERE pallet_id = i_pallet_id
                AND trans_type = 'HAL'
                AND trans_date =
                    (SELECT MAX(trans_date)
                    FROM trans t2
                    WHERE t2.pallet_id = t1.pallet_id
                        AND t2.trans_type = t1.trans_type);
		/* This cursor select the dest_loc from the TRANS table for the last
		haul for a pallet. */

  BEGIN
		pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Get_Haul_Location with pallet_id : ' || i_pallet_id || SQLERRM, SQLCODE, SQLERRM);

		BEGIN
			OPEN c_dest_loc_cur;
			/* Cursor opened.  Get the dest loc. */

				FETCH c_dest_loc_cur INTO o_dest_loc;

				IF c_dest_loc_cur%rowcount = 0 THEN
					/* The pallet was never hauled.  Show this by setting the dest
					loc to a null string. */
					l_status := rf.STATUS_NORMAL;  /* It's OK if pallet never hauled. */
					o_dest_loc := '';
					pl_text_log.ins_msg_async('WARN', l_function_name, 'No data found for Pallet ' || i_pallet_id || '.' || SQLERRM, SQLCODE, SQLERRM);

				ELSE
					pl_text_log.ins_msg_async('INFO', l_function_name, 'Pallet ' || i_pallet_id || ' was hauled to ' || o_dest_loc || SQLERRM, SQLCODE, SQLERRM);
				END IF;

				/* Close the cursor. */
				CLOSE c_dest_loc_cur;

		EXCEPTION
			WHEN OTHERS THEN
				/* Opening the cursor failed. */
				pl_text_log.ins_msg_async('FATAL', l_function_name, 'Opening cursor dest_loc_cur failed' || SQLERRM, SQLCODE, SQLERRM);

				l_status := rf.STATUS_DATA_ERROR;

		END;

		RETURN l_status;

  END Lmc_Get_Haul_Location;

/*******************************************************************************
**Procedure:
**        Lmc_Sel_3_Part_Move_Syspar
**
** Description:
**        This function selects syspar 3_PART_MOVE.
**        This syspar is used with demand replenishments to designate if time
**        is given to first travel to the destination location then travel to
**        the source location.
**
** Parameters:
**
** Output:
**     o_3_part_move_bln    -
**
*******************************************************************************/

  Procedure Lmc_Sel_3_Part_Move_Syspar (
		o_3_part_move_bln   OUT    NUMBER ) IS

		l_function_name         VARCHAR2(60) := 'LMC_SEL_3_PART_MOVE_SYSPAR';
		l_config_flag_name      sys_config.config_flag_name%TYPE;
		l_syspar_value          sys_config.config_flag_val%TYPE;

  BEGIN
		pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Sel_3_Part_Move_Syspar.......' || SQLERRM, SQLCODE, SQLERRM);

		l_config_flag_name := '3_PART_MOVE';

        l_syspar_value := pl_common.f_get_syspar(l_config_flag_name, 'N');

        IF l_syspar_value = 'Y' THEN
			o_3_part_move_bln := 1;
		ELSE
			o_3_part_move_bln := 0;
		END IF;

  EXCEPTION
    WHEN OTHERS THEN
        /* Either an error or no data found.  Use "N" as the value. */
        l_syspar_value := 'N';

        pl_text_log.ins_msg_async('WARN', l_function_name, 'Selecting syspar GIVE_STACK_ON_DOCK_TIME failed, N will be used.'
        || SQLERRM, SQLCODE, SQLERRM);

  END Lmc_Sel_3_Part_Move_Syspar;

/*******************************************************************************
**Function:
**        Lmc_Is_Three_Part_Move_Active
**
** Description:
**        This function determines if 3 part move is active for the pallet type
**        of a slot.  If an error occurs a message is logged and FALSE is
**        returned.
**
** Input:
**     i_psz_loc        - Location to check.  It should be a home slot but
**                        no check of this is taking place.
**
*******************************************************************************/

  FUNCTION Lmc_Is_Three_Part_Move_Active (
		i_psz_loc			IN	   loc.logi_loc%TYPE )
  RETURN rf.status IS

		l_function_name             VARCHAR2(60) := 'LMC_IS_THREE_PART_MOVE_ACTIVE';
		l_ret_val                   rf.status := rf.STATUS_NORMAL;
		l_three_part_move_active    VARCHAR2(1);
		l_loc                       loc.logi_loc%TYPE;

  BEGIN
		pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Is_Three_Part_Move_Active with psz_loc : ' || i_psz_loc
		|| SQLERRM, SQLCODE, SQLERRM);

		l_loc := i_psz_loc;

		BEGIN
			SELECT three_part_move_for_demand_rpl
            INTO l_three_part_move_active
            FROM pallet_type pt,
                loc l
            WHERE l.logi_loc = l_loc
                AND pt.pallet_type = l.pallet_type;

			IF l_three_part_move_active = 'Y' THEN
				l_ret_val := 1;
                pl_text_log.ins_msg_async('INFO', l_function_name, 'Three part move is active for slot : ' || i_psz_loc || SQLERRM, SQLCODE, SQLERRM);
			ELSE
				l_ret_val := 0;
                pl_text_log.ins_msg_async('INFO', l_function_name, 'Three part move is not active for slot : ' || i_psz_loc  || SQLERRM, SQLCODE, SQLERRM);
			END IF;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				/*
				** Got an error in the select.  Log a message then set the
				** return value to FALSE.
				*/
				pl_text_log.ins_msg_async('WARN', l_function_name, 'LMF ORACLE Failed determining if three part move is active
				for the pallet type of the slot.  Will default to not active.' || SQLERRM, SQLCODE, SQLERRM);

				l_ret_val := 0;

		END;

		RETURN l_ret_val;

  END Lmc_Is_Three_Part_Move_Active;

/*******************************************************************************
**Function:
**        Lmc_Is_Forklift
**
** Description:
**        Check if the input batch is a forklift batch or not.
**
**
** Input:
**     i_batch_no    -  Batch assigned.
**
*******************************************************************************/

  FUNCTION Lmc_Is_Forklift (
		i_batch_no			IN	   batch.batch_no%TYPE )
  RETURN NUMBER IS

		l_function_name         VARCHAR2(40) := 'LMC_IS_FORKLIFT';
        l_batch_no              batch.batch_no%TYPE;
		l_status                NUMBER := 0;

  BEGIN
		pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Is_Forklift with batch_no : ' || i_batch_no
		|| SQLERRM, SQLCODE, SQLERRM);

		IF i_batch_no IS NULL THEN
			l_status:= BATCH_TYPE_NOBATCH;
		END IF;

		IF ((SUBSTR(i_batch_no, 1, 1) IS NOT NULL) AND

           ((lmf.DropToHomeBatch(i_batch_no) != 0) OR
                (lmf.PalletPullBatch(i_batch_no) != 0) OR
                (lmf.PutawayBatch(i_batch_no) != 0) OR
                (lmf.DemandReplBatch(i_batch_no) != 0) OR
                (lmf.NonDemandReplBatch(i_batch_no) != 0) OR
                (lmf.HomeSlotBatch(i_batch_no) != 0) OR

                ((SUBSTR(i_batch_no, 1, 1) = lmf.HAUL_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_PUTAWAY)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.HAUL_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_TRANSFER)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.HAUL_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = 'L')) OR			/* Break Away Haul*/
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_INV_ADJ)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_SWAP)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_COMBINE_PULL)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_TRANSFER)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_CYCLE_COUNT)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = 'M')) OR			 /*MSKU back to rsv*/
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = 'E')) OR			/*DMD RPL back to rsv*/
                (SUBSTR(i_batch_no, 1, 1) = 'T') OR			/*Returns putaway*/
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_MSKU_RTN_TO_RESERVE)) OR
                ((SUBSTR(i_batch_no, 1, 1) = lmf.FORKLIFT_BATCH_ID) AND
                    (SUBSTR(i_batch_no, 2, 1) = lmf.FORKLIFT_RETURNS_PUTAWAY))  )   ) THEN

			l_status := BATCH_TYPE_FK;

		ELSE

            l_status :=  BATCH_TYPE_NOTFK;

        END IF;
     RETURN l_status;
  END Lmc_Is_Forklift;

/*******************************************************************************
**Function:
**        Lmc_Get_Last_Batch
**
** Description:
**        Handle logout processing for forklift batch.
**
** Input:
**     i_user_id     -  User being assigned to batch.
**     i_batch_no    -  Batch assigned to the user.
**
** Output:
**     o_batch_no    -  Current active batch returned to calling function.
**	   o_status      -  Status of the batch.
**     o_job_code    -  Job code of the batch.
**     o_equip_id    -  Equipment id used for the batch.
**     o_is_parent   - Parent batch no of the current batch.
**
** Modification history:
**
**    Date          Developer    Comment
**    ------------------------------------------------------------------------
**    24-Mar-2021   pkab6563     Added replace to batch table query to remove
**                               'OPS$' from user id before comparing.
*******************************************************************************/

  FUNCTION Lmc_Get_Last_Batch (
        i_user_id         IN     batch.user_id%TYPE,
        i_batch_no        IN     batch.batch_no%TYPE,
        o_batch_no        OUT    batch.batch_no%TYPE,
        o_status          OUT    VARCHAR2,
        o_job_code        OUT    batch.jbcd_job_code%TYPE,
        o_equip_id        OUT    batch.equip_id%TYPE,
        o_is_parent       OUT    VARCHAR2 )
  RETURN NUMBER IS

        l_function_name         VARCHAR2(40) := 'LMC_GET_LAST_BATCH';
        l_hi_exists             NUMBER := 0;
        l_status                NUMBER := 0;
        l_parent_batch          batch.parent_batch_no%TYPE;
  BEGIN
		pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Get_Last_Batch...with user_id : ' || i_user_id || SQLERRM, SQLCODE, SQLERRM);

        BEGIN
            SELECT 1 INTO l_hi_exists
            FROM usr
            WHERE REPLACE(user_id, 'OPS$', '') = REPLACE(i_user_id, 'OPS$', '');

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('FATAL', l_function_name, 'Invalid user ID' || SQLERRM, SQLCODE, SQLERRM);
                Return -1;
        END;

        BEGIN
            SELECT batch_no,
                   status,
                   jbcd_job_code,
                   equip_id,
                   parent_batch_no
            INTO o_batch_no,
                 o_status,
                 o_job_code,
                 o_equip_id,
                 l_parent_batch
            FROM batch b
            WHERE REPLACE(user_id, 'OPS$') = REPLACE(i_user_id, 'OPS$')
                AND (((i_batch_no IS NULL) AND
                (b.status = 'A') AND
                (b.actl_start_time = (SELECT MAX(actl_start_time)
                                      FROM batch b2
                                      WHERE REPLACE(b2.user_id, 'OPS$') = REPLACE(i_user_id, 'OPS$')
				                        AND b2.status = 'A'))) OR
                ((i_batch_no IS NOT NULL) AND (batch_no = i_batch_no)));

            pl_text_log.ins_msg_async('DEBUG', l_function_name, 'Before get back to caller from lm_get_last_batch.... user_id : ' || i_user_id ||
                ' and batch_no : ' || i_batch_no || ' o_batch_no : ' || o_batch_no || ', o_status : ' || o_status || ', o_job_code : '
                || o_job_code || ', o_equip_id : ' || o_equip_id || ', o_is_parent : ' || o_is_parent || SQLERRM, SQLCODE, SQLERRM);

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_function_name, 'Error. No data found for getting users last active batch'
                    || SQLERRM, SQLCODE, SQLERRM);

                /*
                ** Cannot find the specific batch or no batch for user or db error
                ** or no active batch for user.
                ** See if the user has any completed/merged batch
                */

                BEGIN
                    SELECT batch_no,
                           status,
                           jbcd_job_code,
                           equip_id,
                            parent_batch_no
                    INTO o_batch_no,
                         o_status,
                         o_job_code,
                         o_equip_id,
                         l_parent_batch
                    FROM batch b
                    WHERE user_id = i_user_id
                        AND batch_no = (SELECT batch_no FROM batch b2
                                        WHERE user_id = b.user_id
                                            AND (rowid, actl_stop_time) =
                                                (SELECT MAX(rowid), MAX(actl_stop_time) FROM batch b3
                                                 WHERE user_id = b2.user_id
                                                    AND status IN ('C','M')));

                    /* Found the last user batch as either completed or merged */
                    l_status := -3;

                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        pl_text_log.ins_msg_async('FATAL', l_function_name, 'Error. No data found for getting users last completed/merge batch' ||
                        SQLERRM, SQLCODE, SQLERRM);
                        l_status := -2;

                    WHEN OTHERS THEN
                        pl_text_log.ins_msg_async('FATAL', l_function_name, 'Error getting users last completed/merge batch' ||
                        SQLERRM, SQLCODE, SQLERRM);
                        l_status := -4;
            END;

        END;

        IF l_parent_batch = o_batch_no THEN
            o_is_parent := 'Y';
        ELSE
            o_is_parent := 'N';
        END IF;

        RETURN l_status;

  END Lmc_Get_Last_Batch;

/*******************************************************************************
**Procedure:
**        Lmc_Rf_Logout
**
** Description:
**        Handle logout processing for forklift batch.
**
**
** Input:
**     i_user_id       -  User being assigned to batch.
**	   i_logout_option -  Log out option
**     i_logout_from   -  Log out from
**
** Output:
**     o_status        -  log out status
**
*******************************************************************************/

  PROCEDURE Lmc_Rf_Logout (
        i_user_id           IN     batch.user_id%TYPE,
        i_logout_option     IN     VARCHAR2,
        i_logout_from       IN     NUMBER,
        o_status            OUT    NUMBER ) IS

        l_function_name             VARCHAR2(40) := 'LMC_RF_LOGOUT';
        l_ibatch_no                 batch.batch_no%TYPE;
        l_batch_status_old          batch.status%TYPE;
        l_batch_status              batch.status%TYPE;
        l_equip_id                  batch.equip_id%TYPE;
        l_parent_batch              batch.parent_batch_no%TYPE;
        l_obatch_no                 batch.batch_no%TYPE;
        l_job_code                  batch.jbcd_job_code%TYPE;
        l_is_parent                 VARCHAR2(1);
        l_status                    NUMBER := 0;
        l_ibatch_status             NUMBER := 0;
        l_ret_val                   rf.status := 0;

        o_msg                       VARCHAR2(400);
        vr_batch                    batch%ROWTYPE;

  BEGIN
        pl_text_log.ins_msg_async('INFO', l_function_name, 'Starting Lmc_Rf_Logout with user_id : ' || i_user_id || SQLERRM, SQLCODE, SQLERRM);

        o_status := 0;

        pl_text_log.ins_msg_async('DEBUG', l_function_name, 'Begin Logout with logout option : ' || i_logout_option || ' and logout from :'
        || i_logout_from || SQLERRM, SQLCODE, SQLERRM);

        IF i_logout_option = LOGOUT_OPTION_L THEN
            /*
            ** Logout with L option and 2 buttons (Yes/No) which:
            ** For RF: 1) Exit in the login screen (without even logout);
            **         2) Some equipment check failed/equipment reentry but logout.
            ** We just do nothing.
            */
            RETURN;
        END IF;

        /*
        ** Retrieve the last batch that user was doing if any
        */
        l_status := 0;
		l_is_parent := 'N';

        /*
        ** l_ibatch_no is used as input and l_obatch_no is used as output
        */
        l_status := Lmc_Get_Last_Batch(i_user_id, l_ibatch_no, l_obatch_no, l_batch_status, l_job_code, l_equip_id, l_is_parent);

        pl_text_log.ins_msg_async('DEBUG', l_function_name, 'after (com) lmc_get_last_batch... user_id : ' || i_user_id ||
         ', l_obatch_no : ' || l_obatch_no || ', l_batch_status :' || l_batch_status || '. l_status is ' || l_status
         || SQLERRM, SQLCODE, SQLERRM);

        IF l_status = -1 OR l_status = -4 THEN

            pl_text_log.ins_msg_async('DEBUG', l_function_name, 'Invalid user ID or user not set up in LM or DB error (lmcom)'
            || SQLERRM, SQLCODE, SQLERRM);

            o_status := rf.STATUS_LM_INVALID_USERID;
            RETURN;

        END IF;

        IF l_status = -2 THEN
            /*
            User doesn't have any previous batch
            */
            RETURN;
        END IF;

        IF (Lmc_Is_Forklift(l_obatch_no) = BATCH_TYPE_FK) THEN
            /*
            ** This is a forklift type batch
            */
            pl_text_log.ins_msg_async('DEBUG', l_function_name, 'Batch is a forklift type batch' || SQLERRM, SQLCODE, SQLERRM);

            /*
            ** step 1: Update batch status to N for user and batch. Return the old
            **         status
            */

            l_ibatch_status := 0;

            BEGIN
                pl_task_assign.change_status(l_obatch_no, 'N', l_batch_status_old);

                IF l_batch_status_old not in ('A', 'C', 'M', 'X', 'F', 'N', 'W') THEN  --(l_ibatch_status = -1)
                    l_batch_status_old := NULL;
                END IF;

                pl_text_log.ins_msg_async('DEBUG', l_function_name, 'Update batch status to N' || SQLERRM, SQLCODE, SQLERRM);

            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('FATAL', l_function_name, 'Unable to update batch status to N' || SQLERRM, SQLCODE, SQLERRM);

                    o_status := rf.STATUS_LM_BATCH_UPD_FAIL;

            END;

            /*
            ** step 2: lm_signoff_from_forklift_batch(batch,equip,user,is_parent)
            */

            pl_text_log.ins_msg_async('DEBUG', l_function_name, 'Ready to lm_signoff_from_forklift_batch' || SQLERRM, SQLCODE, SQLERRM);

            l_ret_val := pl_lm_forklift.lm_signoff_from_forklift_batch (l_obatch_no, l_equip_id, i_user_id, l_is_parent);
            -- change the package name in the above line

            /*
            ** Update batch status and user to previous status from step 1
            */

            BEGIN
                pl_task_assign.change_status(l_obatch_no, l_batch_status_old, l_batch_status);
            EXCEPTION
                WHEN OTHERS THEN
                    pl_text_log.ins_msg_async('FATAL', l_function_name, 'Unable to update batch status from N to previous status'
                    || SQLERRM, SQLCODE, SQLERRM);

                    o_status := rf.STATUS_LM_BATCH_UPD_FAIL;
            END;

        ELSE
            /*
            ** Not a forklift batch
            */

            -- 9/9/21 mc add below
            pl_text_log.ins_msg_async('DEBUG', l_function_name, 'Batch is not a forklift type batch' || SQLERRM, SQLCODE, SQLERRM);


            IF (SUBSTR(l_obatch_no, 1, 1) = 'S' AND SUBSTR(l_obatch_no, 2, 1) != 'S') OR
               (SUBSTR(l_obatch_no, 1, 1) = 'S' AND SUBSTR(l_obatch_no, 2, 1) = 'S') OR
               (SUBSTR(l_obatch_no, 1, 1) = 'L' AND SUBSTR(l_obatch_no, 2, 1) != 'R') THEN  -- 9/9/21 m.c add != 'R'

                /*
                ** SOS/SLS batch; Let another process handle it
                */
                o_status := 0;
                RETURN;
            END IF; /** SOS/SLS batch **/

        END IF; /** Lmc_Is_Forklift(l_obatch_no) = BATCH_TYPE_FK **/



        vr_batch.batch_no := l_obatch_no;

        -- 9/9/21 mc add msg
        pl_text_log.ins_msg_async('DEBUG',  l_function_name, 'in pl_rf_lm_common.lmc_rf_logout before call pl_lmc.pl_rf_logout' || SQLERRM, SQLCODE, SQLERRM);
        pl_lmc.pl_rf_logout (i_user_id, vr_batch, i_logout_option, i_logout_from, o_status, o_msg);


  END Lmc_Rf_Logout;

/*******************************************************************************
**  FUNCTION:                                                                 **
**      lmc_labor_mgmt_active()                                               **
**  DESCRIPTION:                                                              **
**      This function determines whether or not Labor Management is active on **
**      the system.                                                           **
**  PARAMETERS:                                                               **
**      None.                                                                 **
*******************************************************************************/

    FUNCTION lmc_labor_mgmt_active RETURN rf.status AS

        l_func_name          VARCHAR2(50) := 'lmc_labor_mgmt_active';
        l_config_flag_name   sys_config.config_flag_name%TYPE;
        l_syspar_value       sys_config.config_flag_val%TYPE;
        l_ret_val            rf.status := rf.status_normal;

    BEGIN
        l_config_flag_name := 'LBR_MGMT_FLAG';

        l_syspar_value := pl_common.f_get_syspar(l_config_flag_name, 'N');

        IF l_syspar_value = 'N' THEN
			l_ret_val := -1;
		ELSE
			l_ret_val := rf.status_normal;
		END IF;

        return(l_ret_val);

    EXCEPTION
        WHEN OTHERS THEN
            pl_text_log.ins_msg_async('ERROR', l_func_name, 'LMC ORACLE Failed to get syspar LBR_MGMT_FLAG.', sqlcode, sqlerrm);

            l_ret_val := rf.status_sel_syscfg_fail;

            return(l_ret_val);

    END lmc_labor_mgmt_active;


/*******************************************************************************
**  FUNCTION:                                                                 **
**      lmc_get_duration()                                                    **
**                                                                            **
**  DESCRIPTION:                                                              **
**      This function validates the user for the jobcode for upcoming batch   **
**      assignment                                                            **
**                                                                            **
**  PARAMETERS:                                                               **
**      i_user_id char(30):     User performing operation.                    **
**      i_jobcode char(6):      Jobcode of batch.                             **
**      i_labor_group char(2):  Labor group user is in.                       **
**      o_dur int:              Duration from schedule.                       **
*******************************************************************************/

    FUNCTION lmc_get_duration (
        i_user_id           IN     batch.user_id%TYPE,
        i_jobcode           IN     batch.jbcd_job_code%TYPE,
        i_labor_group       IN     usr.lgrp_lbr_grp%TYPE,
        o_dur               OUT    sched_type.start_dur%TYPE )
    RETURN rf.status AS

        l_func_name   VARCHAR2(50) := 'lmc_get_duration';
        l_ret_val     rf.status := rf.status_normal;
        l_dur         sched_type.start_dur%TYPE := 0;
    BEGIN
    pl_text_log.ins_msg_async('INFO', l_func_name, 'lmc_get_duration rf_status = '||l_ret_val||' i_user_id = '||i_user_id, sqlcode, sqlerrm);

     BEGIN
        SELECT
            nvl(st.start_dur, 0)
        INTO l_dur
        FROM
            sched_type   st,
            usr          u,
            sched        s,
            job_code     j
        WHERE
            ROWNUM = 1
            AND st.sctp_sched_type = s.sched_type
            AND u.lgrp_lbr_grp = i_labor_group
            AND u.user_id = i_user_id
            AND u.lgrp_lbr_grp = s.sched_lgrp_lbr_grp
            AND s.sched_jbcl_job_class = j.jbcl_job_class
            AND j.jbcd_job_code = i_jobcode;

        o_dur := l_dur;
pl_text_log.ins_msg_async('INFO', l_func_name, 'lmc_get_duration rf_status = '||l_ret_val||' i_user_id = '||i_user_id, sqlcode, sqlerrm);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pl_text_log.ins_msg_async('WARN', l_func_name, 'LMC ORACLE Setup of user is incorrect for jobcode', sqlcode, sqlerrm);
            o_dur := 0;
            l_ret_val := rf.status_lm_bad_user;

      END;
        return(l_ret_val);

    END lmc_get_duration;


/*******************************************************************************
**  FUNCTION:                                                                 **
**      lmc_batch_istart()                                                    **
**  DESCRIPTION:                                                              **
**      This function checks for an ISTART batch for the user.  If one does   **
**      not exists, one is created.                                           **
**  PARAMETERS:                                                               **
**      i_user_id         - User performing operation.                        **
**      o_supervisor_id   - User's supervisor.                                **
**      o_prev_batch_no   - New batch created.                                **
*******************************************************************************/

    FUNCTION lmc_batch_istart (
        i_user_id           IN     batch.user_id%TYPE,
        o_prev_batch_no     OUT    batch.batch_no%TYPE,
        o_supervisor_id     OUT    batch.user_supervsr_id%TYPE )
    RETURN rf.status AS

        l_func_name     VARCHAR2(50) := 'lmc_batch_istart';
        l_ret_val       rf.status := rf.status_normal;
        l_dur           NUMBER := 0;
        l_dummy         VARCHAR(1);
        l_bcount        NUMBER := 0;
        l_user_name     usr.user_name%TYPE;
        l_labor_group   usr.lgrp_lbr_grp%TYPE;
        l_m_user_name   usr.user_name%TYPE;
        l_m_supervisr   usr.suprvsr_user_id%TYPE;
        l_m_labor_grp   usr.lgrp_lbr_grp%TYPE;
    BEGIN
        BEGIN
        pl_text_log.ins_msg_async('INFO', l_func_name, 'i_user_id'||i_user_id||'length :'||length(i_user_id), sqlcode, sqlerrm);
            SELECT
                user_name,
                suprvsr_user_id,
                lgrp_lbr_grp
            INTO
                l_m_user_name,
                l_m_supervisr,
                l_m_labor_grp
            FROM
                usr
            WHERE
                ( i_user_id = user_id
                  OR 'OPS$' || i_user_id = user_id
                  OR i_user_id = badge_no
                  OR 'OPS$' || i_user_id = badge_no )
                AND lgrp_lbr_grp IS NOT NULL;

            o_supervisor_id := l_m_supervisr;
            l_user_name := l_m_user_name;
            l_labor_group := l_m_labor_grp;

            pl_text_log.ins_msg_async('WARN', l_func_name, 'i_user_id 1'||i_user_id, sqlcode, sqlerrm);

		/*
        **  Check to see if an ISTART record already exists.
        **
        *
        */
            BEGIN
                SELECT
                    'X'
                INTO l_dummy
                FROM
                    batch b
                WHERE
                    ( b.user_id = replace(i_user_id, 'OPS$', NULL)
                      OR b.user_id = 'OPS$' || i_user_id )
                    AND b.jbcd_job_code = 'ISTART';

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'LMC ORACLE ISTART not found for user', sqlcode, sqlerrm);

	 /*
            **  Check for active batch for user.

            */
                    SELECT
                        COUNT(*)
                    INTO l_bcount
                    FROM
                        batch b
                    WHERE
                        ( b.user_id = replace(i_user_id, 'OPS$', NULL)
                          OR b.user_id = 'OPS$' || i_user_id )
                        AND b.status = 'A';

                    pl_text_log.ins_msg_async('WARN', l_func_name, 'i_user_id 2'||i_user_id, sqlcode, sqlerrm);
                    IF ( l_bcount = 0 ) THEN
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'LMC No active batch found for user', sqlcode, sqlerrm);

	/*
                **  Now for every time automatically inserting ISTART.
                */
                        l_ret_val := lmc_get_duration(i_user_id, 'ISTART', l_labor_group, l_dur);
                        pl_text_log.ins_msg_async('INFO', l_func_name, 'l_ret_val' || l_ret_val, sqlcode, sqlerrm);
                        IF ( l_ret_val = rf.status_normal ) THEN
                            BEGIN
                                SELECT
                                    'I' || TO_CHAR(seq1.NEXTVAL)
                                INTO o_prev_batch_no
                                FROM
                                    dual;

                                INSERT INTO batch (
                                    batch_no,
                                    batch_date,
                                    jbcd_job_code,
                                    status,
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
                                    no_lunches,
                                    no_breaks,
                                    damage
                                ) VALUES (
                                    o_prev_batch_no,
                                    trunc(SYSDATE),
                                    'ISTART',
                                    'A',
                                    SYSDATE - l_dur / 1440,
                                    replace(i_user_id, 'OPS$', NULL),
                                    o_supervisor_id,
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
                                    0
                                );
                             pl_text_log.ins_msg_async('INFO', l_func_name, 'ISTART created for LM batch number = '||o_prev_batch_no, sqlcode
                                    , sqlerrm);
                            EXCEPTION
                                WHEN DUP_VAL_ON_INDEX THEN
                                    pl_text_log.ins_msg_async('ERROR', l_func_name, 'LMC ORACLE Unable to create ISTART LM batch number - Unique constraint', sqlcode
                                    , sqlerrm);
                                    l_ret_val := rf.status_lm_ins_istart_fail;


                                WHEN ORACLE_PRIMARY_KEY_CONSTRAINT THEN
                                    pl_text_log.ins_msg_async('ERROR', l_func_name, 'LMC ORACLE Unable to create ISTART LM batch number - Primary Key Constraint', sqlcode
                                    , sqlerrm);
                                    l_ret_val := rf.status_lm_ins_istart_fail;


                                WHEN OTHERS THEN
                                    pl_text_log.ins_msg_async('ERROR', l_func_name, 'LMC ORACLE Unable to create ISTART LM batch number', sqlcode
                                    , sqlerrm);
                                    l_ret_val := rf.status_data_error;

                            END;
                        END IF; /** l_ret_val = rf.status_normal **/

                    END IF; /** l_bcount = 0 **/

            END;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'LMC ORACLE Unable to get supervisor for user for indirect', sqlcode, sqlerrm
                );
                l_ret_val := rf.status_lm_bad_user;

        END;
        pl_text_log.ins_msg_async('WARN', l_func_name, 'l_ret_val '||l_ret_val, sqlcode, sqlerrm);
        return(l_ret_val);

    END lmc_batch_istart;

END pl_rf_lm_common;
/
