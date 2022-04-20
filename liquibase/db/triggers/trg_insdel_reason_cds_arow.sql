rem *****************************************************
rem @(#) src/schema/triggers/trg_insdel_reason_cds_arow.sql, swms, swms.9, 10.1.1 9/8/06 1.2

rem @(#) File :  trg_insdel_reason_cds_arow.sql
rem @(#) Usage: sqlplus USR/PWD  trg_insdel_reason_cds_arow.sql
rem Description:
rem ---  Maintenance history  ---
rem 21-OCT-2005 prpakp Initial Creation.

rem *****************************************************
create or replace trigger swms.trg_insdel_reason_cds_arow
 after insert or delete on swms.reason_cds for each row

begin
  IF INSERTING THEN
    if :new.reason_cd_type ='RTN' then
       insert into wis_reason_cds (REASON_CD_TYPE, REASON_CD, REASON_DESC, CC_REASON_CODE,
				   LBR_SL, LBR_LD, LBR_FL)
       values (:new.reason_cd_type, :new.reason_cd, :new.reason_desc, :new.cc_reason_code, 'Y','Y','Y'); 
    end if;
  ELSIF DELETING THEN
    if :old.reason_cd_type ='RTN' then
       delete wis_reason_cds
       where reason_cd_type = :old.reason_cd_type
       and   reason_cd = :old.reason_cd
       and cc_reason_code = :old.cc_reason_code;
    end if;
  END IF;

end trg_insdel_reason_cds_arow;
/

