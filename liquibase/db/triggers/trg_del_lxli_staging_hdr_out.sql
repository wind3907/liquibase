------------------------------------------------------------------------------
-- @(#) src/schema/triggers/trg_del_lxli_staging_hdr_out
--
-- Table:
--    lxli_staging_hdr_ou
--
-- Description:
--   Deleting the child first before the parent to avoid constraint violation 
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/28/2017  knha8378  deleting child LXLI tables
--    02/06/2017  mpha8134  Change trigger to compound trigger
------------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER swms.trg_del_lxli_staging_hdr_out
  FOR DELETE ON swms.lxli_staging_hdr_out 
    COMPOUND TRIGGER

  seq_no    lxli_staging_hdr_out.sequence_number%TYPE;
  lbr_func  lxli_staging_hdr_out.lfun_lbr_func%TYPE;

  BEFORE EACH ROW IS 
  BEGIN
    seq_no := :old.sequence_number;
    lbr_func := :old.lfun_lbr_func;
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
  BEGIN

    if lbr_func = 'SL' then
      delete from lxli_staging_sl_out
      where sequence_number = seq_no;

    elsif lbr_func = 'LD' then
      delete from lxli_staging_ld_out
      where sequence_number = seq_no;

    elsif lbr_func = 'FL' then
      delete from lxli_staging_fl_inv_out 
      where sequence_number = seq_no;

      delete from lxli_staging_fl_header_out 
      where sequence_number = seq_no;

    end if;

  END AFTER STATEMENT;

END trg_del_lxli_staging_hdr_out;
/