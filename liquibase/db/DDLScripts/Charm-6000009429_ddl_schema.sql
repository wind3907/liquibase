/****************************************************************************
** Date:       25-SEP-2015
**
**             Indexes created to improve performance on the tables.  
**
****************************************************************************/


CREATE INDEX SWMS.STS_ROUTE_OUT_IDX3 ON SWMS.STS_ROUTE_OUT
(ROUTE_NO, ROUTE_DATE)
LOGGING
TABLESPACE SWMS_DTS2
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
NOPARALLEL;

CREATE INDEX SWMS.STS_ROUTE_OUT_IDX4 ON SWMS.STS_ROUTE_OUT
(ROUTE_NO, ROUTE_DATE, RECORD_TYPE)
LOGGING
TABLESPACE SWMS_DTS2
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
NOPARALLEL;

CREATE INDEX SWMS.STS_ROUTE_OUT_IDX5 ON SWMS.STS_ROUTE_OUT
(BATCH_ID, ROUTE_NO, ROUTE_DATE)
LOGGING
TABLESPACE SWMS_DTS2
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
NOPARALLEL;



GRANT EXECUTE, DEBUG ON SWMS.STS_ROUTE_OUT_OBJECT_TABLE TO SWMS_SAP;