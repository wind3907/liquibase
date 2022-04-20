create or replace FUNCTION "GET_DOC_ID" (pfilename IN VARCHAR2) return Number 
AS
  src_file VARCHAR2 (256) := pfilename;
  Id_ret   NUMBER;
Begin
  $if swms.platform.SWMS_REMOTE_DB $then
    src_file := '/tmp/swms/reports/' || pfilename;
  $end
  Select ID into Id_ret from report_data where fname = src_file;
  Return Id_ret;
End;
/
