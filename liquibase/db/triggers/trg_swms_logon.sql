CREATE OR REPLACE TRIGGER "SWMS"."TRG_SWMS_LOGON" AFTER
LOGON ON DATABASE DECLARE
  l_terminal V$SESSION.TERMINAL%TYPE;
  l_osuser V$SESSION.OSUSER%TYPE;
  l_machine V$SESSION.MACHINE%TYPE;

  db_company VARCHAR2(3);
  term_company VARCHAR2(3);
  mach_company VARCHAR2(3);
  user_company VARCHAR2(3);
BEGIN
  -- Log time of user's logon to DB_USER_LOGON.
  BEGIN
    INSERT INTO DB_USER_LOGON (USERNAME, LAST_LOGON_DATE)
    VALUES (USER, SYSDATE);
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      UPDATE DB_USER_LOGON
         SET LAST_LOGON_DATE = SYSDATE
       WHERE USERNAME = USER;
  END;

  -- Get this user's session info.
  SELECT TERMINAL, OSUSER, MACHINE
    INTO l_terminal, l_osuser, l_machine
    FROM V$SESSION
   WHERE AUDSID = USERENV('sessionid')
     AND ROWNUM < 2;

  -- Get company number from database
  SELECT SUBSTR(ATTRIBUTE_VALUE,1,3)
    INTO db_company
    FROM MAINTENANCE M
   WHERE ATTRIBUTE = 'MACHINE'
     AND APPLICATION = 'SWMS'
     AND COMPONENT = 'COMPANY'
     AND CREATE_DATE = ( SELECT MAX(CREATE_DATE)
                           FROM MAINTENANCE D
                          WHERE D.ATTRIBUTE = M.ATTRIBUTE
                            AND D.COMPONENT = M.COMPONENT
                            AND D.APPLICATION = M.APPLICATION)
     AND ROWNUM < 2;

  -- Get company number of PC
  term_company := SUBSTR(l_terminal, 1, 3);
  mach_company := SUBSTR(l_machine, 1, 3);
  user_company := SUBSTR(l_osuser, -3, 3);

  IF l_machine LIKE 'rs%' THEN -- Allow any logon from a RISC box
    NULL;
  ELSIF USER IN ('SWMS','SYSTEM','SYS','EDW') THEN -- Allow logon from priviledged accounts
    INSERT INTO DB_LOGON (TERMINAL, OSUSER, MACHINE, STATUS)
    VALUES (l_terminal, l_osuser, l_machine,'ACCEPT ' || USER);
    COMMIT;
  ELSIF LOWER(l_osuser) = 'oracle' THEN -- Allow logon oracle AIX username
    INSERT INTO DB_LOGON (TERMINAL, OSUSER, MACHINE, STATUS)
    VALUES (l_terminal, l_osuser, l_machine,'ACCEPT ORACLE AIX ID');
    COMMIT;
  ELSIF l_terminal LIKE '000%' THEN -- Allow any logon from anyone at corporate
    INSERT INTO DB_LOGON (TERMINAL, OSUSER, MACHINE, STATUS)
    VALUES (l_terminal, l_osuser, l_machine,'ACCEPT CORP TERM');
    COMMIT;
  ELSIF l_osuser LIKE '%000' THEN -- Allow logon from any corporate user
    INSERT INTO DB_LOGON (TERMINAL, OSUSER, MACHINE, STATUS)
    VALUES (l_terminal, l_osuser, l_machine,'ACCEPT CORP USER');
    COMMIT;
  ELSIF USER IN ('BUSOBJ','SWMSVIEW') AND
       (db_company = term_company OR
        db_company = mach_company OR
        db_company = user_company) THEN -- Allow logons from same opco only.
    INSERT INTO DB_LOGON (TERMINAL, OSUSER, MACHINE, STATUS)
    VALUES (l_terminal, l_osuser, l_machine,'ACCEPT OPCO USER');
    COMMIT;
  ELSE
    -- Kick user out of database
    INSERT INTO DB_LOGON (TERMINAL, OSUSER, MACHINE, STATUS)
    VALUES (l_terminal, l_osuser, l_machine,'REJECT');
    COMMIT;
--  raise_application_error(-20001,'This user cannot connect via ODBC');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
END;
/

