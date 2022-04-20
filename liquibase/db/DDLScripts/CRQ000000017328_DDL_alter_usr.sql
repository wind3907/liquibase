PROMPT Modify table USR for JOB_DESC to 256 and ROLE_NAME to 30
alter table usr modify (job_desc varchar2(256 CHAR), role_name varchar2(30 CHAR));

PROMPT Modify table SWMS_ROLE for ROLE_NAME 30 and add_user-upd_user to 30
alter table swms_role modify (role_name varchar2(30 CHAR), add_user varchar2(30 CHAR), upd_user varchar2(30 CHAR));

PROMPT Add new column to SWMS_ROLE called CORP_APPDEV_FLAG
alter table swms_role add (corp_appdev_flag varchar2(1 CHAR));
