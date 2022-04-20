CREATE OR REPLACE TRIGGER SWMS.TRG_INSUPD_HACCP_CODES_TEMP
BEFORE INSERT OR UPDATE OF TEMP_TRK ON SWMS.HACCP_CODES
FOR EACH ROW
------------------------------------------------------------------------------
--
-- Table:
--    HACCP_CODES
--
-- Description:
--    This trigger performs task when the HACCP_CODES table is updated.
--
-- Exceptions raised:
--    Inserting into Unix log file.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/13/2013 mdev3739 Initial version for temp_trk flag issue.
--	  11/17/2021 ecla1411 OPCOF-3559-Prevent TEMP_TRK from reverting back to N (Pallas)
------------------------------------------------------------------------------
BEGIN

IF pl_common.f_get_syspar('ENABLE_PM_TEMP_TRK', 'N') = 'N' THEN
	UPDATE SWMS.PM 
	   SET TEMP_TRK = NVL(:NEW.TEMP_TRK,'N')
	 WHERE HAZARDOUS = :NEW.HACCP_CODE;   
END IF;
	 
EXCEPTION

WHEN OTHERS THEN
  pl_log.ins_msg('WARN', 'TRG_INSUPD_HACCP_CODES_TEMP',
           'Final WHEN-OTHERS catch all error update of temp_trk record.',
           SQLCODE, SQLERRM, 'INVENTORY', 'TRG_INSUPD_HACCP_CODES_TEMP');
       
END TRG_INSUPD_HACCP_CODES_TEMP;
/
