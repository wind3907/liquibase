/********************************************************************
**
** Script to create new rpt_inv_stgng_out table
**
** Modification History:
**
**    Date     Designer       Comments
**    -------- -------------- --------------------------------------
**    4/1/2020 D. Betancourt  Created for Jira card 2714.
*********************************************************************/
 DECLARE
    v_sequence_exists NUMBER := 0;
 BEGIN
    SELECT COUNT(*)
    INTO   v_sequence_exists
    FROM   all_sequences
    WHERE  lower(sequence_name) = 'rpt_inv_stgng_out_batch_seq'
      AND  sequence_owner = 'SWMS';
              
    IF (v_sequence_exists = 0) THEN
                                 
        EXECUTE IMMEDIATE 'CREATE SEQUENCE rpt_inv_stgng_out_batch_seq
						MINVALUE 1
						START WITH 1
						INCREMENT BY 1
						CACHE 50';
    END IF;
END;
/
