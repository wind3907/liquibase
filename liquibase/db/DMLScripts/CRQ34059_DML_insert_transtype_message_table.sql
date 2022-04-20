
/****************************************************************************
** File:       CRQ34059_DDL_INSERT_transtype_message_table.sql
**
** Desc: This scripts 
**			1.inserts a new transaction(STC) for stop close 
**		 	2.inserts a new message into message_table to handle (RTNSDTL)form error
**		
** 		
**
** Modification History:
**    Date        Designer           Comments
**    -------- 	  -------- 		---------------------------------------------------
**    17/07/17 	  chyd9155    	CRQ34059-POD project iteration 2
**	  05/10/17    chyd9155		changed message_id from 119980 to 120037
**    06/12/17	  CHYD9155      DDL and DML standardization for merge  
****************************************************************************/

DECLARE
  v_row_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_row_exists
  FROM SWMS.TRANS_TYPE
  WHERE TRANS_TYPE = 'STC';
        

  IF (v_row_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'Insert into trans_type (TRANS_TYPE, DESCRIP, RETENTION_DAYS, INV_AFFECTING) 
	values (''STC'',''POD stop close'', 55,''N'')';
	COMMIT;
  END IF;
END;
/

DECLARE
  v_row_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_row_exists
  FROM SWMS.MESSAGE_TABLE
  WHERE ID_MESSAGE = '120037';
        

  IF (v_row_exists = 0)
  THEN
  
    EXECUTE IMMEDIATE 'Insert into MESSAGE_TABLE (ID_MESSAGE, V_MESSAGE,ID_LANGUAGE) 
values 
(''120037'',''Stop already closed. Further returns or updates are not allowed.'', 3)';

    EXECUTE IMMEDIATE 'Insert into MESSAGE_TABLE (ID_MESSAGE, V_MESSAGE,ID_LANGUAGE) 
values 
(''120037'',''Arrêtez déjà fermé. D''''autres retours ou mises à jour ne sont pas autorisés.'', 12)';
	COMMIT;
	
	
  END IF;
END;
/


