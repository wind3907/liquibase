
CREATE SEQUENCE SWMS.LXLI_STAGING_SEQ
  START WITH 1
  MAXVALUE 99999999999
  MINVALUE 1
  CYCLE
  CACHE 20
  ORDER;


CREATE OR REPLACE PUBLIC SYNONYM LXLI_STAGING_SEQ FOR SWMS.LXLI_STAGING_SEQ;


GRANT SELECT ON SWMS.LXLI_STAGING_SEQ TO SWMS_USER;


