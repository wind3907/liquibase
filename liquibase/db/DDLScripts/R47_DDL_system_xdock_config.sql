/****************************************************************************

  File:
    xdock_sys_config.sql

  Desc:
    Table to store the configuration values of the xdock message hub

****************************************************************************/

DECLARE
	v_table_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_table_exists
  FROM all_tables
  WHERE table_name = 'SYSTEM_XDOCK_CONFIG'
  AND owner = 'SWMS';

  IF (v_table_exists = 0) THEN

    EXECUTE IMMEDIATE 'CREATE TABLE SWMS.SYSTEM_XDOCK_CONFIG (
        config_flag_name          VARCHAR2(30 CHAR)     NOT NULL,
        config_flag_desc          VARCHAR2(100 CHAR)    NOT NULL,
        config_flag_val           VARCHAR2(200 CHAR)    NOT NULL,
        add_date                  DATE DEFAULT SYSDATE  NOT NULL,
        add_user                  VARCHAR2(30 CHAR)     NOT NULL,
        upd_date                  DATE,
        upd_user                  VARCHAR2(30 CHAR)
      )';

    EXECUTE IMMEDIATE 'ALTER TABLE SYSTEM_XDOCK_CONFIG ADD CONSTRAINT SYSTEM_XDOCK_CONFIG_PK PRIMARY KEY (config_flag_name)';

  END IF;
END;
/
