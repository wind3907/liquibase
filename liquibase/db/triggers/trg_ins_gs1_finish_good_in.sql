/********************************************************************
**
** This trigger inserts a row into inv_cases when a
** row is inserted into gs1_finish_good_in.
**
** Modification History:
**
**    Date     Designer       Comments
**    -------- -------------- --------------------------------------
**    4/15/19  P. Kabran      Created
**
*********************************************************************/
CREATE OR REPLACE TRIGGER swms.trg_ins_gs1_finish_good_in
    BEFORE INSERT ON swms.gs1_finish_good_in 
    FOR EACH ROW

DECLARE
    l_logi_loc              swms.inv_cases.logi_loc%TYPE;
    l_tmp_logi_loc          swms.inv_cases.logi_loc%TYPE;
    l_lpn_count             NUMBER;
    l_error_msg             VARCHAR2(300);
    l_timestamp             DATE;
    l_user                  swms.inv_cases.add_user%TYPE;
    l_sequence_no           swms.gs1_finish_good_in.sequence_number%TYPE;
    l_record_status         swms.gs1_finish_good_in.record_status%TYPE;
    l_func_code             swms.gs1_finish_good_in.func_code%TYPE;
    l_count                 NUMBER;

    CURSOR c_lpn_list IS
        SELECT i.logi_loc, 
               p.spc,
               floor(i.qoh/p.spc) case_cnt,
               floor(nvl(i.sigma_qty_produced, 0)/p.spc) sigma_produced_case_cnt
        FROM   swms.inv i, swms.pm p
        WHERE  p.prod_id      = :NEW.prod_id
          AND  i.prod_id      = :NEW.prod_id
          AND  i.rec_id       = :NEW.po_no
          AND  i.inv_order_id = :NEW.order_id
          order by i.logi_loc;

BEGIN
    IF :NEW.record_status IS NULL THEN
        :NEW.record_status := 'N'; 
    END IF;

    IF :NEW.record_status = 'N' THEN
        l_lpn_count     := 0;
        l_tmp_logi_loc  := NULL;
        l_logi_loc      := NULL;
        l_error_msg     := NULL;
        l_count         := 0;

        SELECT sysdate, 
               replace(user, 'OPS$'), 
               swms.gs1_finish_good_in_seq.nextval
        INTO   l_timestamp, 
               l_user,
               l_sequence_no
        FROM   dual;

        :NEW.datetime        := l_timestamp;
        :NEW.add_date        := l_timestamp;
        :NEW.upd_date        := l_timestamp;
        :NEW.add_user        := l_user;
        :NEW.upd_user        := l_user;
        :NEW.sequence_number := l_sequence_no;
        :NEW.func_code       := 'A'; 

        SELECT COUNT(*)
        INTO   l_count
        FROM   swms.inv_cases
        WHERE  prod_id  = :NEW.prod_id
          AND  box_id   = :NEW.box_id
          AND  rec_id   = :NEW.po_no;

        IF l_count > 0 THEN
            l_error_msg := 'inv_cases record already exists for ' || 
                           'prod_id [' || :NEW.prod_id || '] ' ||
                           'box_id [' || :NEW.box_id || '] ' ||
                           'rec_id [' || :NEW.po_no || '] '; 
            pl_log.ins_msg('WARN', 'trg_ins_gs1_finish_good_in', l_error_msg, NULL, NULL);
            :NEW.error_msg := l_error_msg;
            :NEW.record_status := 'F';
        ELSIF :NEW.order_id IS NULL THEN
            l_error_msg := 'order_id is null. This record is not for custom cut.';     
            pl_log.ins_msg('WARN', 'trg_ins_gs1_finish_good_in', l_error_msg, NULL, NULL);
            :NEW.error_msg := l_error_msg;
            :NEW.record_status := 'X';
        ELSIF :NEW.weight IS NULL OR :NEW.po_no IS NULL THEN
            l_error_msg := 'po_no or weight is null. Cannot be null';     
            pl_log.ins_msg('WARN', 'trg_ins_gs1_finish_good_in', l_error_msg, NULL, NULL);
            :NEW.error_msg := l_error_msg;
            :NEW.record_status := 'F';
        ELSE
            l_logi_loc := NULL;
            FOR r_lpn IN c_lpn_list LOOP
                l_lpn_count := l_lpn_count + 1;

                IF r_lpn.sigma_produced_case_cnt < r_lpn.case_cnt THEN
                    l_logi_loc := r_lpn.logi_loc;
                    exit;
                END IF;
            END LOOP;

            IF l_lpn_count >= 1 THEN
                IF l_logi_loc IS NOT NULL THEN
                    INSERT INTO swms.inv_cases(prod_id, rec_id, order_id, box_id, 
                                               pack_date, weight, upc, logi_loc,
                                               add_user, add_date,
                                               upd_user, upd_date)
                                VALUES(:NEW.prod_id, :NEW.po_no, :NEW.order_id, :NEW.box_id,
                                       :NEW.pack_date, :NEW.weight, :NEW.upc, l_logi_loc,
                                       l_user, l_timestamp,
                                       l_user, l_timestamp);

                    :NEW.record_status := 'S';
                ELSE
                    l_error_msg := 'There are [' || l_lpn_count || '] LPNs; but they could not be used for this box. ' ||
                                   'Please check inventory cases vs. sigma_qty_produced to confirm.';
                    pl_log.ins_msg('WARN', 'trg_ins_gs1_finish_good_in', l_error_msg, NULL, NULL);
                    :NEW.error_msg := l_error_msg;
                    :NEW.record_status := 'F';
                END IF;
            ELSE
                l_error_msg := 'No inventory record found for given prod_id, order_id, and po_no combination. ' ||
                               'Therefore cannot create inv_cases record.';
                pl_log.ins_msg('WARN', 'trg_ins_gs1_finish_good_in', l_error_msg, NULL, NULL);
                :NEW.error_msg := l_error_msg;
                :NEW.record_status := 'F';
            END IF;
        END IF;
    END IF;

EXCEPTION
   WHEN OTHERS THEN
       l_error_msg := 'Trigger trg_ins_gs1_finish_good_in FAILED. ' ||
                    'Sequence# = [' || :NEW.sequence_number || '] ' ||
                    'Prod_id = [' || :NEW.prod_id || '] ' ||
                    'Po_no = [' || :NEW.po_no || '] ' ||
                    'Order_id = [' || :NEW.order_id || '] ' ||
                    'Box_id = [' || :NEW.box_id || ']'; 
       pl_log.ins_msg('FATAL', 'trg_ins_gs1_finish_good_in', l_error_msg, SQLCODE, SQLERRM);

END trg_ins_gs1_finish_good_in;
/
