/***  Creation OF Audit Table for ML_MODULE and ML_VALUES Record Auditing  ***/
CREATE TABLE SWMS.ML_AUDIT
(
  AUDIT_FUNC  VARCHAR2(3 CHAR)                  NOT NULL,
  DESCRIP     VARCHAR2(80 CHAR)                 NOT NULL,
  UPD_USER    VARCHAR2(15 CHAR)                 DEFAULT REPLACE(USER, 'OPS$') NOT NULL,
  UPD_DATE    DATE
);


CREATE OR REPLACE PUBLIC SYNONYM ML_AUDIT FOR SWMS.ML_AUDIT;

GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.ML_AUDIT TO SWMS_USER;

GRANT SELECT ON SWMS.ML_AUDIT TO SWMS_VIEWER;
