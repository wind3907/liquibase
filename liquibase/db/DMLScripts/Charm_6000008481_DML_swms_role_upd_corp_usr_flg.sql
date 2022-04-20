--------------------------------------------------------------------
-- File Name : Charm_6000008481_DDL_swms_role_upd_corp_usr_flg.sql
-- Description : Adding corp_usr_flg to SWMS_ROLE
--
-- Change History:
--    Date     Authour   Description
-- 01-11-16    skam7488  Charm #6000008481. Initial Version
--                       Updating corp_usr_flg to 'Y' in swms_role table
--                       for the CORP_USER role.     
--------------------------------------------------------------------

UPDATE swms.SWMS_ROLE 
SET corp_usr_flg = 'Y',
    upd_date = SYSDATE,
    upd_user = REPLACE(USER,'OPS$',NULL)
WHERE ROLE_NAME = 'CORP_USER';

COMMIT;
