CREATE TABLE swms.user_downloaded_tasks
(user_id	VARCHAR2 (30) DEFAULT USER,
 task_id	NUMBER (10))
/
CREATE INDEX swms.user_downloaded_tasks_ni
ON user_downloaded_tasks (user_id)
/
GRANT ALL ON swms.user_downloaded_tasks TO swms_user
/
CREATE OR REPLACE PUBLIC SYNONYM user_downloaded_tasks FOR swms.user_downloaded_tasks
/
ALTER TABLE swms.trans ADD (replen_task_id NUMBER (10))
/
ALTER TABLE swms.replenlst ADD (
	replen_type	VARCHAR2 (1),
	replen_aisle VARCHAR (3),
	replen_area VARCHAR2 (1))
/
CREATE INDEX trans_bulk_pull_ind ON swms.trans (
        DECODE (order_id, 'PP', trans_type, NULL),
        DECODE (order_id, 'PP', trans_date, NULL),
        DECODE (order_id, 'PP', order_id, NULL),
        DECODE (order_id, 'PP', prod_id, NULL),
        DECODE (order_id, 'PP', qty, NULL))
/
CREATE SEQUENCE swms.repl_cond_seq
START WITH 1
INCREMENT BY 1
/
CREATE PUBLIC SYNONYM repl_cond_seq FOR swms.repl_cond_seq
/
GRANT SELECT ON repl_cond_seq TO swms_user
/
ALTER TABLE dts
  ADD (add_date	DATE DEFAULT SYSDATE)
/
INSERT INTO swms.sap_interface_purge (table_name, retention_days, description)
VALUES ('DTS', 30, 'Logon Info from RF devices')
/
