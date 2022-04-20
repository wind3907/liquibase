CREATE OR REPLACE PACKAGE      swms.pl_short AS

PROCEDURE CREATE_SYS14_ADDORDER
    (i_batch_no  IN  VARCHAR2,
     o_status    OUT  NUMBER);

END pl_short;
/

CREATE OR REPLACE PACKAGE BODY      swms.pl_short AS

   PROCEDURE CREATE_SYS14_ADDORDER
    (i_batch_no  IN  VARCHAR2,
     o_status    OUT  NUMBER)
   IS
        l_fname             VARCHAR2 (50)       := 'create_SYS14_addorder';

      ----------------------------------------Correct the Query-------------------------------------------------------------
        CURSOR c_sos_batch_info IS
            SELECT vs.order_id, vs.route_no, vs.stop_no, vs.order_seq, vs.prod_id, TRUNC(vs.qty_alloc/vs.spc) case_qty,
                   vs.batch_seq, vs.float_char, vs.zone, vs.cust_name, vs.cust_id, vs.item_descrip, vs.pack, vs.float_seq,
                   vs.door_no, vs.src_loc, vs.bc_st_piece_seq, vs.qty_alloc, vs.batch_no, vs.truck_no, vs.price, vs.cust_po,
                   vs.ship_date, vs.fd_qty_short, vs.order_type, vs.orig_batch_no, vs.spc, vs.float_no, vs.fd_seq_no,
                   decode(vs.uom, 1, vs.label_max_seq, vs.label_max_seq / vs.spc) label_max_seq
              FROM loc l, v_sos_batch_info_short vs
             WHERE vs.short_batch_no = i_batch_no
               AND l.logi_loc = vs.src_loc
               AND l.slot_type IN ('MXF','MXC','MXS')
             ORDER BY vs.order_id ;

        CURSOR c_short_cases (p_batch_no  VARCHAR2,
                              p_orderseq NUMBER,
                              p_float_no NUMBER,
                              p_fd_seq_no NUMBER) IS
            SELECT case_barcode, to_number(substr(case_barcode,-3,3)) bc_st_piece_seq
              FROM loc l, sos_short_detail ssd
             WHERE batch_no = p_batch_no
               AND orderseq = p_orderseq
               AND float_no = p_float_no
               AND float_detail_seq_no = p_fd_seq_no
--               AND pick_location IS NOT NULL
               AND l.logi_loc = ssd.location
               AND l.slot_type IN ('MXF','MXC','MXS')
               AND NOT EXISTS (SELECT 1 FROM mx_float_detail_cases mfd
                                WHERE mfd.case_id = ssd.case_barcode
                                  AND mfd.order_seq = ssd.orderseq
                                  AND mfd.float_no = ssd.float_no
                                  AND mfd.float_detail_seq_no = ssd.float_detail_seq_no
                                  AND mfd.case_skip_flag = 'Y'
                                  AND mfd.case_skip_reason = 'DELAY');
        ------------------------------------------------------------------------------------------------------------
        e_fail              EXCEPTION;
        l_sys_msg_id        NUMBER;
        l_ret_val           NUMBER;
        l_pick_loc          VARCHAR(10);
        l_pallet_id         VARCHAR2(18);
        l_slot_type         VARCHAR2(3);
        l_rec_cnt           NUMBER := 0;
        l_print_stream      CLOB;
        l_case_barcode      VARCHAR2(20);
        l_sequence_number   NUMBER;
        l_exact_pallet_imp  VARCHAR2(4);
        l_is_short          BOOLEAN;
        l_print_logo        BOOLEAN;
        l_print_logo_yn     VARCHAR2(1);
        l_msg_text          VARCHAR2(512);
        l_rowid             ROWID;
        l_no_of_floats      NUMBER;
        l_encode_print_stream    RAW(32767);
        l_qoh               NUMBER;
        l_qty_alloc         NUMBER;
        l_qty_planned       NUMBER;

        C_SUCCESS           NUMBER := 0;
        C_FAILURE           NUMBER := -1;
        gl_pkg_name         VARCHAR2(30) := 'create_SYS14_addorder';   -- Procedure name.

   BEGIN
        o_status := C_SUCCESS;
        l_sys_msg_id := mx_sys_msg_id_seq.NEXTVAL;

            l_rec_cnt := 0;

            l_print_logo_yn := pl_matrix_common.get_sys_config_val('PRINT_LOGO_ON_SOS_LABEL');

            IF l_print_logo_yn = 'Y' THEN
                l_print_logo := TRUE;
            ELSE
                l_print_logo := FALSE;
            END IF;

            SELECT no_of_floats
              INTO l_no_of_floats
              FROM sos_batch
             WHERE batch_no = i_batch_no;

            FOR rc IN c_sos_batch_info LOOP

                SELECT DECODE(rc.order_type,'VRT','ABS','LOW')
                  INTO l_exact_pallet_imp
                  FROM ordm
                 WHERE order_id = rc.order_id;

                --Populate case number and Label in table matrix_out_label

                BEGIN
                    FOR r_sc IN c_short_cases (rc.orig_batch_no, rc.order_seq, rc.float_no, rc.fd_seq_no) LOOP
                         l_case_barcode := r_sc.case_barcode;

                        IF rc.fd_qty_short > 0 THEN
                            l_is_short := TRUE;
                        ELSE
                            l_is_short := FALSE;
                        END IF;

                        -- Find item in inventory

                        BEGIN
                          SELECT rowid, plogi_loc, logi_loc, slot_type, qoh, qty_alloc, qty_planned
                            INTO l_rowid, l_pick_loc, l_pallet_id, l_slot_type, l_qoh, l_qty_alloc, l_qty_planned
                            FROM (SELECT i.rowid, i.plogi_loc, i.logi_loc, l.slot_type,
                                         i.qoh, i.qty_alloc, i.qty_planned
                                    FROM loc l, inv i
                                   WHERE l.logi_loc = i.plogi_loc
                                     AND l.slot_type IN ('MXF','MXC')
                                     AND i.prod_id = rc.prod_id
                                     AND i.qoh > 0
                                   ORDER BY i.exp_date, i.logi_loc)
                           WHERE ROWNUM = 1;

                          UPDATE inv
                             SET qoh = qoh - rc.spc
                           WHERE ROWID = l_rowid;

                          -- Delete the inventory record if quantities are now zero.

                          IF l_qoh = rc.spc AND l_qty_alloc = 0 AND l_qty_planned = 0 THEN
                            DELETE FROM inv
                             WHERE ROWID = l_rowid;
                          END IF;

                          -- Update the new pick location and pallet ID in the SOS_SHORT_DETAIL record.

                          UPDATE sos_short_detail
                             SET pick_location = l_pick_loc,
                                 pallet_id = l_pallet_id
                          WHERE orderseq = rc.order_seq
                            AND case_barcode = l_case_barcode;

                          IF l_slot_type = 'MXF' OR l_slot_type = 'MXC' THEN
                            l_rec_cnt := l_rec_cnt + 1;
                            l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                              i_interface_ref_doc => 'SYS14',
                                                                              i_rec_ind => 'D',
                                                                              i_order_id => rc.order_id,
                                                                              i_prod_id => rc.prod_id,
                                                                              i_case_qty => 1,
                                                                              i_float_id => rc.batch_seq,
                                                                              i_pallet_id => l_pallet_id, --- Need Pallet ID
                                                                              i_exact_pallet_imp => l_exact_pallet_imp
                                                                             );
                            BEGIN
                              SELECT sequence_number
                                INTO  l_sequence_number
                                FROM (  SELECT sequence_number
                                          FROM matrix_out
                                         WHERE prod_id = rc.prod_id
                                           AND float_id = rc.batch_seq
                                           AND order_id = rc.order_id
                                           AND sys_msg_id = l_sys_msg_id
                                           AND interface_ref_doc = 'SYS14'
                                         ORDER BY sequence_number DESC)
                               WHERE rownum = 1;
                            EXCEPTION
                              WHEN NO_DATA_FOUND THEN
                                 l_msg_text := 'Prog Code: ' || l_fname ||
                                               ' Unable to find sequence number of detail record (SYS14) record for prod_id '||
                                               rc.prod_id || ' and sys_msg_id '||l_sys_msg_id;
                                 RAISE e_fail;
                            END;
                          END IF;
                        EXCEPTION
                          WHEN NO_DATA_FOUND THEN
                            CONTINUE;
                        END;

                        l_print_stream := pl_mx_gen_label.ZplPickLabel(printLogo => l_print_logo,
                                                                       doFloatShading => FALSE ,
                                                                       isShort => l_is_short,
                                                                       isMulti => FALSE,
                                                                       floatChar => rc.float_char,
                                                                       floatZone => rc.zone,
                                                                       numFloats => l_no_of_floats,
                                                                       custName => rc.cust_name,
                                                                       custNumber => rc.cust_id,
                                                                       itemDesc => rc.item_descrip,
                                                                       pack => rc.pack,
                                                                       floatNum => rc.float_seq,
                                                                       dockDoor => rc.door_no,
                                                                       slotNo => rc.src_loc,
                                                                       userId => 'SYMBOTIC',
                                                                       qtySec => r_sc.bc_st_piece_seq,
                                                                       totQty => rc.label_max_seq,
                                                                       invoice => rc.order_id,
                                                                       batch => rc.batch_no,
                                                                       truck => rc.truck_no,
                                                                       stop => rc.stop_no,
                                                                       caseBarCode => l_case_barcode,
                                                                       item => rc.prod_id,
                                                                       price => rc.price,
                                                                       custPo => rc.cust_po,
                                                                       invoiceDate => rc.ship_date
                                                                      );

                        l_encode_print_stream := utl_encode.base64_encode(utl_raw.cast_to_raw(l_print_stream));

                        INSERT INTO matrix_out_label (sequence_number,
                                                      barcode,
                                                      print_stream,
                                                      encoded_print_stream)
                                              VALUES (l_sequence_number,
                                                      l_case_barcode ,
                                                      l_print_stream,
                                                      utl_raw.cast_to_varchar2(l_encode_print_stream)
                                                     );

                    END LOOP;
                END;

            END LOOP;

            IF l_rec_cnt > 0 THEN
                l_ret_val := pl_matrix_common.populate_matrix_out(i_sys_msg_id => l_sys_msg_id,
                                                                  i_interface_ref_doc => 'SYS14',
                                                                  i_rec_ind => 'H',
                                                                  i_batch_id => i_batch_no
                                                                 );
                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname
                                   || ' Unable to insert header record (SYS14) into matrix_out for batch_no ' || i_batch_no;
                    RAISE e_fail;
                END IF;

                l_ret_val := pl_matrix_common.send_message_to_matrix(i_sys_msg_id => l_sys_msg_id);

                IF l_ret_val = 1 THEN
                    l_msg_text := 'Prog Code: ' || l_fname
                                    || ' Unable to send the message SYS14 for batch_no ' || i_batch_no;
                    RAISE e_fail;
                END IF;

                UPDATE sos_batch
                   SET status = 'X'
                 WHERE batch_no = i_batch_no;

                IF SQL%ROWCOUNT > 0 THEN
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' SOS_BATCH status updated to Pending for batch ' || i_batch_no;
                    pl_Text_Log.ins_msg ('INFO', l_fname, l_msg_text, NULL, NULL);
                ELSE
                    l_msg_text := 'Prog Code: ' || l_fname ||
                                  ' Unable to update SOS_BATCH status to Pending for batch ' || i_batch_no;
                    pl_Text_Log.ins_msg ('WARN', l_fname, l_msg_text, NULL, NULL);
                END IF;
            END IF;

   EXCEPTION
        WHEN e_fail THEN
             Pl_Text_Log.ins_msg ('FATAL', l_fname, l_msg_text, NULL, NULL);
            o_status := C_FAILURE;
        WHEN OTHERS THEN
             l_msg_text := 'Prog Code: ' || l_fname
                || ' Error in executing create_unassign_matrix_rpl.';
            Pl_Text_Log.ins_msg('FATAL', gl_pkg_name, l_msg_text, SQLCODE, SQLERRM);
            o_status := C_FAILURE;
   END create_SYS14_addorder;

BEGIN
   pl_log.g_application_func := 'PL_SHORT';

END pl_short;
/
