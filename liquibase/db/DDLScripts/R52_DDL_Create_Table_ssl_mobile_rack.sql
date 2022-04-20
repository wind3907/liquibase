SET ECHO OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*******************************************************************************
**  Script:  R52_DDL_Create_Table_ssl_mobile_rack.sql
**
**  Purpose: Creation of table SMWS.ssl_mobile_rack to serve as the master table
**           of mobile racks. Additional AC added to story to guarantee that the
**           MAX_POSITIONS and MAX_LEVELS values are the same for multiple rows.
**           I recommended creating a RACK_TYPE table containing these two
**           attributes, but it was backlogged as a future enhancement.
**
**  Modification History:
**
**    ChangeDate  Author    Change Description
**    ----------  --------  ----------------------------------------------------
**    2022/03/01  bgil6182  Created initial script.
**    2022/03/08  bgil6182  Modified script according to template standard.
*******************************************************************************/

DECLARE
  n_count   NATURAL;
BEGIN
  SELECT COUNT(*)
    INTO n_count
    FROM all_tables t
   WHERE t.owner      = 'SWMS'
     AND t.table_name = 'SSL_MOBILE_RACK';

  IF ( n_count = 0 ) THEN
    EXECUTE IMMEDIATE 'CREATE TABLE swms.ssl_mobile_rack ( rack_id         VARCHAR2(6 CHAR)  NOT NULL ENABLE
                                                         , description     VARCHAR2(50 CHAR)
                                                         , max_positions   NUMBER(2)         NOT NULL ENABLE
                                                         , max_levels      NUMBER(2)         NOT NULL ENABLE
                                                         , start_position  VARCHAR2(1 CHAR)                   DEFAULT ''A''
                                                         , start_level     VARCHAR2(1 CHAR)                   DEFAULT ''1''
	                                                       , add_date        DATE                               DEFAULT SYSDATE
	                                                       , add_user        VARCHAR2(30 CHAR)                  DEFAULT REPLACE( USER, ''OPS$'' )
	                                                       , upd_date        DATE
	                                                       , upd_user        VARCHAR2(30 CHAR)
                                                         )';

    EXECUTE IMMEDIATE 'COMMENT ON TABLE swms.ssl_mobile_rack IS ''Master table for cross dock fulfillment site mobile racks.''';

    EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX swms.ssl_mobile_rack_pk
                         ON swms.ssl_mobile_rack (rack_id)
                         TABLESPACE swms_its2';

    EXECUTE IMMEDIATE 'ALTER TABLE swms.ssl_mobile_rack ADD
                         ( CONSTRAINT ssl_mobile_rack_pk
                           PRIMARY KEY (rack_id)
                           USING INDEX TABLESPACE swms_its2
                         )';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM ssl_mobile_rack FOR swms.ssl_mobile_rack';

    EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON swms.ssl_mobile_rack TO swms_user';

    EXECUTE IMMEDIATE 'GRANT SELECT ON swms.ssl_mobile_rack TO swms_viewer';

    DBMS_Output.Put_Line( 'Table SWMS.SSL_MOBILE_RACK created.' );
  ELSE
    DBMS_Output.Put_Line( 'Table SWMS.SSL_MOBILE_RACK already exists.' );
  END IF;
END;
/
