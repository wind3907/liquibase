CREATE OR REPLACE
PROCEDURE        SWMS.STS_WRITE_LOG   ( log_date IN STS_LOG.LOG_TIME%TYPE,
  event    IN STS_LOG.EVENT%TYPE,
  msg      IN STS_LOG.TEXT%TYPE )

  IS
  PRAGMA AUTONOMOUS_TRANSACTION;  
  
  /* local variables */
  STSLogVal         SYS_CONFIG.config_flag_val%TYPE;
  
  BEGIN

     BEGIN     
      SELECT CONFIG_FLAG_VAL INTO STSLogVal FROM SYS_CONFIG
             WHERE CONFIG_FLAG_NAME = 'STS_LOG';
      
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            STSLogVal := 'N';    
     END;

     --Check if logging is turned on
     IF ( STSLogVal IS NULL OR STSLogVal = 'N' ) THEN
        -- No
        return;
     END IF;

     
     BEGIN
       /* insert a new log record into STS_LOG */
       INSERT INTO sts_log VALUES
              ( log_date, event, msg );
   
     
       EXCEPTION
         WHEN OTHERS THEN
           ROLLBACK;
           Return;
     END;
   COMMIT;     
END;
/
grant execute on SWMS.STS_WRITE_LOG to PUBLIC;

create or replace public synonym STS_WRITE_LOG for SWMS.STS_WRITE_LOG;

