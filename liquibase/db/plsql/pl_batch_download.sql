CREATE OR REPLACE PACKAGE pl_batch_download AS

/*******************************************************************************
**  src/pgms/lib/libswmslm/lm_down.pc, swms, swms.9, 10.1.1
**   1.2
********************************************************************************
** Library
**   libswmslm.a
**
** File
**   lm_down.pc
**
** Parameters
**
** Description
**
** precompiler version of GAGNON and ASSOC. download processor
**
**  Add SCCC ID,
**                                  Increase Batch# size by 5 chars.
** Changes for ORA7; batches not being created in
**               oracle 7 conversion. Fix batch_no being sent.
**  added tmu cart, cart 
**                           pcs. and pallet pcs.
**
**  Add function to sum and count the parent and child value of
**                   total_count, total_pallet and total_piece.
**   Changed the datatype of kvi_distance from int
**                   to a double.
**   Modified function lm_download to handle cases
**                   where parameter p_batch has embedded spaces.  Before only
**                   the value up to the first space was being read.
**
**                   Changed datatype of host variable actl_time_spent
**                   from an  to a float.  The actl_time_spent will be
**                   stored in the database to two decimal places.  This is
**                   a change for DN# 9987 but is was implemented now because
**                   I did not want to backout the change.
**
**  
**                   Project: CRT-Carton Flow replenishments
**                   Fixed an aplog message.  Does not have anything
**                   to do with the CRT-Carton Flow replenishments project.
**                   Just tagging along this change to the defect.
**                  
**  Ireland Cubic values - Metric conversion project
**                                              Increased length of below variables to hold Cubic centimeter. 
**                                              kvi_cube 	int	to 	float
**												tmu_cube	int	to	float
**												tot_cube	int	to	float
**												std		float 	to 	double
*******************************************************************************/
    PROCEDURE p_lm_download (
        i_batch      IN           VARCHAR2,
        out_status   OUT          VARCHAR2
    );

END pl_batch_download;
/

create or replace PACKAGE BODY                   pl_batch_download AS

    std                       NUMBER;
    parent_status             VARCHAR2(15);
    engr_std_flag             VARCHAR2(2);
    tmu_doc_time              NUMBER;
    tmu_cube                  NUMBER;
    tmu_wt                    NUMBER;
    tmu_no_piece              NUMBER;
    tmu_no_pallet             NUMBER;
    tmu_no_item               NUMBER;
    tmu_no_data_capture       NUMBER;
    tmu_no_po                 NUMBER;
    tmu_no_stop               NUMBER;
    tmu_no_zone               NUMBER;
    tmu_no_loc                NUMBER;
    tmu_no_case               NUMBER;
    tmu_no_split              NUMBER;
    tmu_no_merge              NUMBER;
    tmu_no_aisle              NUMBER;
    tmu_no_drop               NUMBER;
    tmu_no_cart               NUMBER;
    tmu_no_cart_piece         NUMBER;
    tmu_no_pal_piece          NUMBER;
    tmu_order_time            NUMBER;
    tot_cube                  NUMBER;
    tot_wt                    NUMBER;
    tot_no_piece              NUMBER;
    tot_no_pallet             NUMBER;
    tot_no_item               NUMBER;
    tot_no_data_capture       NUMBER;
    tot_no_po                 NUMBER;
    tot_no_stop               NUMBER;
    tot_no_zone               NUMBER;
    tot_no_loc                NUMBER;
    tot_no_case               NUMBER;
    tot_no_split              NUMBER;
    tot_no_merge              NUMBER;
    tot_no_aisle              NUMBER;
    tot_no_drop               NUMBER;
    tot_no_cart               NUMBER;
    tot_no_cart_piece         NUMBER;
    tot_no_pal_piece          NUMBER;
    l_total_piece               NUMBER;
    l_total_pallet              NUMBER;
  /* **  Declares for jobcode table Indicator   */
    ind_batch_no              VARCHAR2(13);
    ind_job_code              VARCHAR2(6);
    ind_status                VARCHAR2(1);
    ind_ref_no                VARCHAR2(40);
    ind_parent_batch_no       VARCHAR2(13);
    ind_user_id               VARCHAR2(30);
    ind_user_supervsr_id      VARCHAR2(30);
  /*   **  Declares for jobcode table Indicator   */
    ind_jbcd_job_code         VARCHAR2(6);
    ind_kvi_doc_time          NUMBER;
    ind_kvi_cube              NUMBER;
    ind_kvi_wt                NUMBER;
    ind_kvi_no_piece          NUMBER;
    ind_kvi_no_pallet         NUMBER;
    ind_kvi_no_item           NUMBER;
    ind_kvi_no_data_capture   NUMBER;
    ind_kvi_no_po             NUMBER;
    ind_kvi_no_stop           NUMBER;
    ind_kvi_no_zone           NUMBER;
    ind_kvi_no_loc            NUMBER;
    ind_kvi_no_case           NUMBER;
    ind_kvi_no_split          NUMBER;
    ind_kvi_no_merge          NUMBER;
    ind_kvi_no_aisle          NUMBER;
    ind_kvi_no_drop           NUMBER;
    ind_kvi_no_cart           NUMBER;
    ind_kvi_no_cart_piece     NUMBER;
    ind_kvi_no_pal_piece      NUMBER;
    ind_kvi_order_time        NUMBER;
    ind_kvi_distance          NUMBER;
    ind_goal_time             NUMBER;
    ind_target_time           NUMBER;
    ind_actl_time_spent       NUMBER;
    ind_print_goal_flag       VARCHAR2(1);
  /*************************************************************************
  **
  **    File: lm_down.pc converted to pl_batch_download
  **
  **    Description: to download the batches
  **    Called By : pl_rcv_po_open
  ****************************************************************/

    PROCEDURE p_lm_download (
        i_batch        IN           VARCHAR2,
        out_status   OUT          VARCHAR2
    ) IS
        l_func_name VARCHAR2(30) := 'p_lm_download';
    BEGIN
        BEGIN
            SELECT
                batch_no,
                jbcd_job_code,
                status,
                ref_no,
                parent_batch_no,
                nvl(kvi_doc_time, 0),
                nvl(kvi_cube, 0),
                nvl(kvi_wt, 0),
                nvl(kvi_no_piece, 0),
                nvl(kvi_no_pallet, 0),
                nvl(kvi_no_item, 0),
                nvl(kvi_no_data_capture, 0),
                nvl(kvi_no_po, 0),
                nvl(kvi_no_stop, 0),
                nvl(kvi_no_zone, 0),
                nvl(kvi_no_loc, 0),
                nvl(kvi_no_case, 0),
                nvl(kvi_no_split, 0),
                nvl(kvi_no_merge, 0),
                nvl(kvi_no_aisle, 0),
                nvl(kvi_no_drop, 0),
                nvl(kvi_order_time, 0),
                nvl(kvi_distance, 0),
                nvl(goal_time, 0),
                nvl(target_time, 0),
                user_id,
                user_supervsr_id,
                nvl(actl_time_spent, 0),
                nvl(kvi_no_cart, 0),
                nvl(kvi_no_pallet_piece, 0),
                nvl(kvi_no_cart_piece, 0)
            INTO
                ind_batch_no,
                ind_job_code,
                ind_status,
                ind_ref_no,
                ind_parent_batch_no,
                ind_kvi_doc_time,
                ind_kvi_cube,
                ind_kvi_wt,
                ind_kvi_no_piece,
                ind_kvi_no_pallet,
                ind_kvi_no_item,
                ind_kvi_no_data_capture,
                ind_kvi_no_po,
                ind_kvi_no_stop,
                ind_kvi_no_zone,
                ind_kvi_no_loc,
                ind_kvi_no_case,
                ind_kvi_no_split,
                ind_kvi_no_merge,
                ind_kvi_no_aisle,
                ind_kvi_no_drop,
                ind_kvi_order_time,
                ind_kvi_distance,
                ind_goal_time,
                ind_target_time,
                ind_user_id,
                ind_user_supervsr_id,
                ind_actl_time_spent,
                ind_kvi_no_cart,
                ind_kvi_no_pal_piece,
                ind_kvi_no_cart_piece
            FROM
                batch
            WHERE
                batch_no = i_batch;

        EXCEPTION
            WHEN no_data_found THEN
                pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch ORACLE 1 unable to get batch information.', sqlcode, sqlerrm);
                out_status := 'ORACLE 1 unable to get batch information.';
                return;
        END;

/* **  Check to make sure not processed by checking status = x    */

        IF ( ind_status = 'X' ) THEN
            BEGIN
                SELECT
                    nvl(lf.print_goal_flag, 'Y')
                INTO ind_print_goal_flag
                FROM
                    lbr_func   lf,
                    job_code   jc
                WHERE
                    jc.lfun_lbr_func = lf.lfun_lbr_func
                    AND jc.jbcd_job_code = ind_job_code;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=lbr_func Unable to get labor function print goal flag.', sqlcode, sqlerrm
                    );
                    ind_print_goal_flag := 'N';
                    
            END;
/*   **  Select jobcode from JOBCODE table    */

            BEGIN
                SELECT
                    jbcd_job_code,
                    engr_std_flag,
                    nvl(tmu_doc_time, 0),
                    nvl(tmu_cube, 0),
                    nvl(tmu_wt, 0),
                    nvl(tmu_no_piece, 0),
                    nvl(tmu_no_pallet, 0),
                    nvl(tmu_no_item, 0),
                    nvl(tmu_no_data_capture, 0),
                    nvl(tmu_no_po, 0),
                    nvl(tmu_no_stop, 0),
                    nvl(tmu_no_zone, 0),
                    nvl(tmu_no_loc, 0),
                    nvl(tmu_no_case, 0),
                    nvl(tmu_no_split, 0),
                    nvl(tmu_no_merge, 0),
                    nvl(tmu_no_aisle, 0),
                    nvl(tmu_no_drop, 0),
                    nvl(tmu_order_time, 0),
                    nvl(tmu_no_cart, 0),
                    nvl(tmu_no_cart_piece, 0),
                    nvl(tmu_no_pallet_piece, 0)
                INTO
                    ind_jbcd_job_code,
                    engr_std_flag,
                    tmu_doc_time,
                    tmu_cube,
                    tmu_wt,
                    tmu_no_piece,
                    tmu_no_pallet,
                    tmu_no_item,
                    tmu_no_data_capture,
                    tmu_no_po,
                    tmu_no_stop,
                    tmu_no_zone,
                    tmu_no_loc,
                    tmu_no_case,
                    tmu_no_split,
                    tmu_no_merge,
                    tmu_no_aisle,
                    tmu_no_drop,
                    tmu_order_time,
                    tmu_no_cart,
                    tmu_no_cart_piece,
                    tmu_no_pal_piece
                FROM
                    job_code
                WHERE
                    jbcd_job_code = ind_job_code;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch ORACLE unable to get job code information.', sqlcode, sqlerrm
                    );
                    out_status := 'ORACLE unable to get job code information.';
                    return;
            END;
/*   ** calculate standard from jobcode tmu's and batches kvi's    */

            std := 0.0;
/*  **  Add in document time and order time only once!     */
            std := std + tmu_doc_time;
            std := std + tmu_order_time;
            IF ( ind_ref_no != 'MULTI' ) THEN
                std := std + tmu_cube * ind_kvi_cube;
                std := std + tmu_wt * ind_kvi_wt;
                std := std + tmu_no_piece * ind_kvi_no_piece;
                std := std + tmu_no_pallet * ind_kvi_no_pallet;
                std := std + tmu_no_item * ind_kvi_no_item;
                std := std + tmu_no_data_capture * ind_kvi_no_data_capture;
                std := std + tmu_no_po * ind_kvi_no_po;
                std := std + tmu_no_stop * ind_kvi_no_stop;
                std := std + tmu_no_zone * ind_kvi_no_zone;
                std := std + tmu_no_loc * ind_kvi_no_loc;
                std := std + tmu_no_case * ind_kvi_no_case;
                std := std + tmu_no_split * ind_kvi_no_split;
                std := std + tmu_no_merge * ind_kvi_no_merge;
                std := std + tmu_no_aisle * ind_kvi_no_aisle;
                std := std + tmu_no_drop * ind_kvi_no_drop;
                std := std + tmu_no_cart * ind_kvi_no_cart;
                std := std + tmu_no_cart_piece * ind_kvi_no_cart_piece;
                std := std + tmu_no_pal_piece * ind_kvi_no_pal_piece;
/*  Check to see if this is a pre-merged batch.  If so need to do some  more processing.   */
            ELSE
                BEGIN
                    UPDATE batch
                    SET
                        parent_batch_no = i_batch
                    WHERE
                        batch_no = i_batch;

                    parent_status := 0;
                EXCEPTION
                    WHEN no_data_found THEN
                        pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch Error assigning the parent_batch_no to parent batch itself.'
                        , sqlcode, sqlerrm);
                      parent_status := 1;
                        out_status := 'Error assigning the parent_batch_no to parent batch itself.';
                        return;
                END;

                IF ( parent_status < 1 ) THEN
                    BEGIN
                        SELECT
                            nvl(SUM(kvi_cube), 0),
                            nvl(SUM(kvi_wt), 0),
                            nvl(SUM(kvi_no_piece), 0),
                            nvl(SUM(kvi_no_pallet), 0),
                            nvl(SUM(kvi_no_item), 0),
                            nvl(SUM(kvi_no_data_capture), 0),
                            nvl(SUM(kvi_no_po), 0),
                            nvl(SUM(kvi_no_stop), 0),
                            nvl(SUM(kvi_no_zone), 0),
                            nvl(SUM(kvi_no_loc), 0),
                            nvl(SUM(kvi_no_case), 0),
                            nvl(SUM(kvi_no_split), 0),
                            nvl(SUM(kvi_no_merge), 0),
                            nvl(SUM(kvi_no_aisle), 0),
                            nvl(SUM(kvi_no_drop), 0),
                            nvl(SUM(kvi_no_cart), 0),
                            nvl(SUM(kvi_no_cart_piece), 0),
                            nvl(SUM(kvi_no_pallet_piece), 0)
                        INTO
                            tot_cube,
                            tot_wt,
                            tot_no_piece,
                            tot_no_pallet,
                            tot_no_item,
                            tot_no_data_capture,
                            tot_no_po,
                            tot_no_stop,
                            tot_no_zone,
                            tot_no_loc,
                            tot_no_case,
                            tot_no_split,
                            tot_no_merge,
                            tot_no_aisle,
                            tot_no_drop,
                            tot_no_cart,
                            tot_no_cart_piece,
                            tot_no_pal_piece
                        FROM
                            batch
                        WHERE
                            parent_batch_no = i_batch;

                        std := std + tmu_cube * tot_cube;
                        std := std + tmu_wt * tot_wt;
                        std := std + tmu_no_piece * tot_no_piece;
                        std := std + tmu_no_pallet * tot_no_pallet;
                        std := std + tmu_no_item * tot_no_item;
                        std := std + tmu_no_data_capture * tot_no_data_capture;
                        std := std + tmu_no_po * tot_no_po;
                        std := std + tmu_no_stop * tot_no_stop;
                        std := std + tmu_no_zone * tot_no_zone;
                        std := std + tmu_no_loc * tot_no_loc;
                        std := std + tmu_no_case * tot_no_case;
                        std := std + tmu_no_split * tot_no_split;
                        std := std + tmu_no_merge * tot_no_merge;
                        std := std + tmu_no_aisle * tot_no_aisle;
                        std := std + tmu_no_drop * tot_no_drop;
                        std := std + tmu_no_cart * tot_no_cart;
                        std := std + tmu_no_cart_piece * tot_no_cart_piece;
                        std := std + tmu_no_pal_piece * tot_no_pal_piece;


                    EXCEPTION
                        WHEN no_data_found THEN
                            pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch ORACLE unable to get child information for pre-merged batch.'
                            , sqlcode, sqlerrm);
                            out_status := 'ORACLE unable to get child information for pre-merged batch.';
                            return;
                    END;

                END IF;

            END IF;
            
            /*       **  Turn tmu's into minutes       */
                        IF ( std != 0 ) THEN
                            std := std / 1667.0;
                        END IF;
/*
** Set either goal time or target time, depending on the Eng stds
** flag. Y = goal time  N = target time
*/

                        IF ( engr_std_flag = 'Y' ) THEN
                            ind_target_time := 0;
                            ind_goal_time := std;
                        ELSE
                            ind_goal_time := 0;
                            ind_target_time := std;
                        END IF;
            
/* update BATCHES table */

            BEGIN
                IF ( ind_print_goal_flag = 'Y' ) THEN
                    UPDATE batch
                    SET
                        status = 'F',
                        goal_time = ind_goal_time,
                        target_time = ind_target_time
                    WHERE
                        batch_no = i_batch;

                ELSE
                    UPDATE batch
                    SET
                        status = 'F',
                        goal_time = 0,
                        target_time = 0
                    WHERE
                        batch_no = i_batch;
                END IF;

                pl_text_log.ins_msg_async('DEBUG', l_func_name, 'TABLE=Batch batch No=[' || i_batch || ']. Goal time calculated for batch=['
                    || ind_goal_time || ']', sqlcode, sqlerrm);
                pl_text_log.ins_msg_async('DEBUG', l_func_name, 'TABLE=Batch batch No=[' || i_batch || ']. Target time calculated for batch=['
                    || ind_target_time || ']', sqlcode, sqlerrm);
            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch ORACLE unable to update of batch with calculated times.', sqlcode
                    , sqlerrm);
                    out_status := 'ORACLE unable to update of batch with calculated times.';
                    return;
            END;
/* Select total parent and child kvi values */

            BEGIN
                SELECT
                    SUM(nvl(kvi_no_piece, 0)),
                    SUM(nvl(kvi_no_pallet, 0))
                INTO
                    l_total_piece,
                    l_total_pallet
                FROM
                    batch
                WHERE
                    nvl(parent_batch_no, batch_no) = i_batch;

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch ORACLE 2 unable to get batch information.', sqlcode, sqlerrm
                    );
                    out_status := 'ORACLE 2 unable to get batch information.';
                    return;
            END;

            BEGIN
                UPDATE batch
                SET
                    total_count = DECODE(status, 'F', 1, 0),
                    total_pallet = l_total_pallet,
                    total_piece = l_total_piece
                WHERE
                    batch_no = i_batch;

                pl_text_log.ins_msg_async('DEBUG', l_func_name, 'TABLE=Batch Total pallet and piece= '                                                     
                                                     || l_total_pallet
                                                     || l_total_piece, sqlcode, sqlerrm);

            EXCEPTION
                WHEN no_data_found THEN
                    pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch ORACLE unable to update of batch with TOTAL count,pallet and piece'
                    , sqlcode, sqlerrm);
                    out_status := 'ORACLE unable to update of batch with TOTAL count,pallet and piece';
                    return;
            END;

            out_status := 'SUCCESS';
        ELSE
            pl_text_log.ins_msg_async('WARN', l_func_name, 'TABLE=Batch Request inconsistent with status of batch.', sqlcode, sqlerrm);
            out_status := 'FAILURE';
        END IF;

        return;
    END p_lm_download;

END pl_batch_download;
/

GRANT Execute on pl_batch_download to swms_user;
