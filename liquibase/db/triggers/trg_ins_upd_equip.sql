create or replace TRIGGER swms.TRG_INS_UPD_EQUIP_OUT
BEFORE INSERT OR UPDATE ON swms.sap_equip_out
FOR EACH ROW
DECLARE

message VARCHAR2(80);
l_status Varchar2(2000);

BEGIN

IF (INSERTING OR UPDATING) AND :NEW.RECORD_STATUS = 'N' THEN
  

 BEGIN
 
  SWMS.PL_EQUIP_OUT.EQUIP_OUT_EAI ( :NEW.SEQUENCE_NUMBER, :NEW.EQUIP_ID, :NEW.EQUIP_NAME, :NEW.ADD_USER, :NEW.INSPECTION_DATE);
  
  EXCEPTION
  WHEN OTHERS THEN
        :NEW.RECORD_STATUS := 'F';
        :NEW.STATUS := 'Fail';
        message := 'SAP_TRACE_STAGING_TBL:INSERT FAILED:Sequence-no :' || :NEW.sequence_number;
        pl_log.ins_msg('FATAL', 'trg_ins_upd_equip_out at pl_equip_out.equip_out_eai', message, SQLCODE, SQLERRM, 'MAINTENANCE', 'trg_ins_upd_equip_out.sql', 'Y');
  
  END;
  
  :NEW.RECORD_STATUS := 'S';
  
END IF;


EXCEPTION

    WHEN OTHERS THEN
        message := 'SAP_TRACE_STAGING_TBL:INSERT FAILED:Sequence-no :' || :NEW.sequence_number;
        pl_log.ins_msg('FATAL', 'trg_ins_upd_equip_out', message, SQLCODE, SQLERRM, 'MAINTENANCE', 'trg_ins_upd_equip_out.sql', 'Y');
      
END trg_ins_upd_equip_out;
/