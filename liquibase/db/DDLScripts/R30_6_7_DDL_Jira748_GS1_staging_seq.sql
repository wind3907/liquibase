/**********************************************************************************
**
** Script to create sequence GS1_FINISH_GOOD_IN_SEQ for GS1_finish_good_in table.
**
** Modification History:
**
**  Date     Designer       Comments
**  -------- -------------- --------------------------------------
**  4/17/19  P. Kabran      Created
**  6/11/19  P. Kabran      Added logic to not attempt to create the sequence
**                          if it already exists.
***********************************************************************************/
DECLARE
    v_seq_exists NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_seq_exists
    FROM all_sequences
    WHERE sequence_name  = 'GS1_FINISH_GOOD_IN_SEQ'
      AND sequence_owner = 'SWMS'; 

    IF (v_seq_exists = 0) THEN
        EXECUTE IMMEDIATE 'CREATE SEQUENCE SWMS.GS1_FINISH_GOOD_IN_SEQ
            START WITH 1
            MAXVALUE 9999999999999999999999999999
            MINVALUE 1
            CYCLE
            CACHE 20
            ORDER';

        EXECUTE IMMEDIATE '
            CREATE OR REPLACE PUBLIC SYNONYM GS1_FINISH_GOOD_IN_SEQ FOR SWMS.GS1_FINISH_GOOD_IN_SEQ';

        EXECUTE IMMEDIATE '
            GRANT SELECT ON SWMS.GS1_FINISH_GOOD_IN_SEQ TO SWMS_USER';
    END IF;
END;
/
