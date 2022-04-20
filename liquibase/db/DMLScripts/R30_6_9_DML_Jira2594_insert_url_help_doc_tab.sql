/****************************************************************************
** Date:       09-Oct-2019
** Programmer: Elaine Zheng
** File:       
** 
** 
**
** Records are inserted into tables:
**    - URL_HELP_DOC
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**
****************************************************************************/

DECLARE
  v_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_exists
  FROM URL_HELP_DOC
  WHERE SEQ = 1000
  AND PROGRAM_NAME='SYSCO_MENU'
  AND SUB_PROGRAM_NAME='HELP';
 

  IF (v_exists = 0)
  THEN

INSERT INTO URL_HELP_DOC (
           SEQ                ,
           MODULE_NAME        ,
           LEVEL_TYPE         ,
           PROGRAM_NAME       ,
           SUB_PROGRAM_NAME   ,
           HELP_URL           ,
           ENABLE_FLAG    )   
SELECT
    1000, 
    'HOME'  ,    
    'MENU' ,          
    'SYSCO_MENU',   
    'HELP',
    'https://maincourse.cloud.sysco.com/SWMSPortal/Content/Home.htm',
    'Y'
  FROM DUAL;
  COMMIT;
 END IF;
 
 END;
/

