CREATE OR REPLACE TRIGGER swms.trg_upd_float_detail_brow
------------------------------------------------------------------------------
-- Trigger Name:
--    trg_upd_float_detail_brow
--
-- Table:
--    FLOAT_DETAIL
--
-- Description:
--    Before update row trigger on the FLOAT_DETAIL table.
--    Assign:
--      - upd_user
--      - upd_date
--
-- Exceptions Raised:
--    None.  Error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                      Created.
------------------------------------------------------------------------------
BEFORE UPDATE ON swms.float_detail
FOR EACH ROW
BEGIN
   :NEW.upd_user := REPLACE(USER, 'OPS$');
   :NEW.upd_date := SYSDATE;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it but don't stop processing.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => 'trg_upd_float_detail_brow',
                i_msg_text         => 'Error occurred in trigger.'
                               || '  NEW.float_no['  || TO_CHAR(:NEW.float_no)  || ']'
                               || '  NEW.seq_no['    || TO_CHAR(:NEW.seq_no)    || ']'
                               || '  Processing will continue.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => 'ORDER PROCESSING',
                i_program_name     => 'trg_upd_float_detail_brow',
                i_msg_alert        => 'N');

END trg_upd_float_detail_brow;
/

