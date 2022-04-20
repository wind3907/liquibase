
/********************************************************************
** Name: r47_jira3394_xdock_seq_ddl
** Script to create new xdock sequences  
**
** Modification History:
** 
**    Date     Comments
**    -------- -------------- --------------------------------------
**    7/11/2  vkal9662 Created
*********************************************************************/
 DECLARE
    v_seq_exists NUMBER := 0;
	v_seq2_exists NUMBER := 0;
BEGIN
	
 BEGIN 
    SELECT COUNT(*)
    INTO   v_seq_exists
    FROM   all_objects
    WHERE  object_name = 'XDOCK_BATCH_SEQ'
      AND  owner = 'SWMS';
 End;
 
 IF (v_seq_exists = 0) THEN  
                                 
   EXECUTE IMMEDIATE     
     'CREATE SEQUENCE  "SWMS"."XDOCK_BATCH_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE';
 END If;
 
 
 BEGIN 
    SELECT COUNT(*)
    INTO   v_seq2_exists
    FROM   all_objects
    WHERE  object_name = 'XDOCK_SEQNO_SEQ'
      AND  owner = 'SWMS';
 End;             
 IF (v_seq2_exists = 0) THEN  
	EXECUTE IMMEDIATE     
     'CREATE SEQUENCE  "SWMS"."XDOCK_SEQNO_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE' ;
	
End If;	 

End;
/