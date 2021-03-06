CREATE TABLE "SWMS"."KILL_SESSION_EXCEPTION" ("MODULE" 
    VARCHAR2(48 byte) NOT NULL, 
    CONSTRAINT "KILL_SESSION_EXCEPTION_PK" PRIMARY KEY("MODULE") 
    USING INDEX  
    TABLESPACE "SWMS_ITS2" 
    STORAGE ( INITIAL 16K NEXT 16K MINEXTENTS 2 MAXEXTENTS 255 
    PCTINCREASE 0) PCTFREE 10 INITRANS 2 MAXTRANS 255)  
    TABLESPACE "SWMS_DTS2" PCTFREE 10 PCTUSED 0 INITRANS 1 
    MAXTRANS 255 
    STORAGE ( INITIAL 16K NEXT 16K MINEXTENTS 1 MAXEXTENTS 255 
    PCTINCREASE 0) 
    LOGGING 
    MONITORING;

CREATE OR REPLACE PUBLIC SYNONYM KILL_SESSION_EXCEPTION FOR SWMS.KILL_SESSION_EXCEPTION;
