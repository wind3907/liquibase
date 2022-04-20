ALTER TABLE swms.batch
  RENAME COLUMN plus_goaltime_upload TO lxli_goaltime_upload
/
ALTER TABLE swms.batch
  RENAME COLUMN lxli_send_date TO lxli_send_time1
/
ALTER TABLE swms.batch
  RENAME COLUMN lxli_man_send_date TO lxli_send_time2
/
ALTER TABLE swms.batch
  ADD (swms_goal_time NUMBER(8,2),
      lxli_goal_upd_time DATE)
/
ALTER TABLE swms.arch_batch
  RENAME COLUMN lxli_send_date TO lxli_send_time1
/
ALTER TABLE swms.arch_batch
  RENAME COLUMN plus_goaltime_upload TO lxli_goaltime_upload
/
ALTER TABLE swms.arch_batch
  ADD (swms_goal_time NUMBER(8,2),
      lxli_goal_upd_time DATE,
      lxli_send_time2 DATE)
/
