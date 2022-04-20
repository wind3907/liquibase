--------------------------------------------------------------------
-- File Name : Charm_6000008481_DDL_swms_role_add_corp_usr_flg.sql
-- Description : Adding corp_usr_flg to SWMS_ROLE
--
-- Change History:
--    Date     Authour   Description
-- 01-11-16    skam7488  Charm #6000008481. Initial Version
--------------------------------------------------------------------

ALTER TABLE swms.SWMS_ROLE ADD (CORP_USR_FLG VARCHAR2(1));
