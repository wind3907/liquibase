SET ECHO OFF
REM
REM Purpose: This script will create new transaction types needed for 
REM          exp and mfg dates override.
REM
SET DEFINE OFF;
SET LINESIZE 132
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED

  BEGIN
    INSERT INTO swms.trans_type ( trans_type, descrip, retention_days, inv_affecting )
      VALUES ( 'DTO', 'Override Exp-Mfg Dates', 55, 'N' );
    DBMS_Output.Put_Line( 'DTO trans_type created.' );
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      DBMS_Output.Put_Line( 'DTO trans_type already exists.' );
  END;
/