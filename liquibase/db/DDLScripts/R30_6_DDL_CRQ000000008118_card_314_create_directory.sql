/****************************************************************************
**
** Description:
**    Project:
**       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_314_unit_test
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    02/27/17 aalb7675 Adi Al Bataineh
**                      Created for Live Receiving.
**                      
**
****************************************************************************/

DECLARE
   l_count NUMBER;
BEGIN
   SELECT count(*) INTO l_count
     FROM dba_directories
    WHERE DIRECTORY_NAME = 'TEST_RP1RN_DIR';

   IF (l_count = 0) THEN
   execute immediate 'CREATE or REPLACE DIRECTORY test_rp1rn_dir AS ''/var/rpts''';
   execute immediate 'GRANT READ ON DIRECTORY test_rp1rn_dir TO swms_user,swms_viewer';
   execute immediate 'GRANT WRITE ON DIRECTORY test_rp1rn_dir TO swms_user,swms_viewer';
   END IF;
END;
/



