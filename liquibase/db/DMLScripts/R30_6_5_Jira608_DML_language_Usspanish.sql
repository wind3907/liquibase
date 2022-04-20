/****************************************************************************
** Date:       04-Oct-2018
** File:       Jira608_DML_Insert_Language_spanish.sql
**
** Script to add Spanish language to the United States territory.
**
**
** Modification History:
**    Date        Designer           Comments
**    ----------- -------- ---------------------------------------------------
**    04-Oct-2018 Sban3548  Initial script
**
****************************************************************************/
set serveroutput on;

INSERT INTO LANGUAGE(ID_LANGUAGE, DESC_LANGUAGE, CURRENT_LANGUAGE) 
SELECT 14, 'American Spanish', 'N' FROM DUAL 
WHERE NOT EXISTS (SELECT 1 FROM LANGUAGE WHERE ID_LANGUAGE = 14);

INSERT INTO GLOBAL_LANGUAGE_MAPPING(LANGUAGE, TERRITORY, LANG_ID, CODE) 
SELECT 'SPANISH', 'AMERICA', 14, 'es_US' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM GLOBAL_LANGUAGE_MAPPING WHERE LANG_ID=14);
    
COMMIT;
