CREATE OR REPLACE
PACKAGE        SWMS.STS      AS 

SWMS_MF_READER			constant INTEGER := 0;
SLS            			constant INTEGER := 1;

MANIFEST_RECEIVED     constant INTEGER := 0;
LOAD_COMPLETE         constant INTEGER := 1;


PROCEDURE UpdateRouteStatus( i_process IN INTEGER, 
                             i_action IN INTEGER,
                             i_route_no IN VARCHAR2 );

PROCEDURE Cleanup;
                             
end STS;
/

CREATE OR REPLACE
PACKAGE BODY        SWMS.STS         AS

PROCEDURE UpdateRouteStatus( i_process IN INTEGER,
                             i_action IN INTEGER,
                             i_route_no IN VARCHAR2 )
IS
--This routine start a new transaction separate from
--the caller
PRAGMA AUTONOMOUS_TRANSACTION;
UNDEF_ROUTEDATE EXCEPTION;
PRAGMA EXCEPTION_INIT( UNDEF_ROUTEDATE, -20501 );

UNDEF_PICKUPS EXCEPTION;
PRAGMA EXCEPTION_INIT( UNDEF_PICKUPS,   -20502 );

QUERY_ERR EXCEPTION;
PRAGMA EXCEPTION_INIT( QUERY_ERR,       -20503 );

BUILDROUTE_ERR EXCEPTION;
PRAGMA EXCEPTION_INIT( BUILDROUTE_ERR,  -20504 );

l_sts_status      ROUTE.sts_status%TYPE;
l_new_status      ROUTE.sts_status%TYPE;
l_route_no        ROUTE.route_no%TYPE;
l_program_name    SWMS_LOG.PROGRAM_NAME%TYPE;
begin

  l_new_status := NULL;
  l_program_name := 'UNKOWN';
  l_route_no := i_route_no;

  IF i_process = SWMS_MF_READER THEN
    l_program_name := 'SWMSMFREADER';
  END IF;

  IF i_process = SLS THEN
    l_program_name := 'SLS';
    
    -- SLS might send an old Route may be old make sure it is the latest for the truck 
    BEGIN
      SELECT SUBSTR( route_no, 1, 4 ) INTO l_route_no  FROM ordm WHERE truck_no = 
               (SELECT truck_no FROM route WHERE route_no = i_route_no 
                  AND rownum = 1 )and rownum = 1 ORDER BY ship_date DESC;    

      EXCEPTION WHEN NO_DATA_FOUND THEN

         PL_LOG.ins_msg( 'W', 'STS.UpdateRouteStatus',
          'Route ' || i_route_no || ' not found.', NULL,  NULL, 'O', l_program_name );
         COMMIT;
         RETURN;
    END;
  END IF;

  begin

    SELECT ROUTE.STS_STATUS INTO l_sts_status FROM ROUTE
    WHERE ROUTE_NO = l_route_no;

    EXCEPTION WHEN NO_DATA_FOUND THEN

      PL_LOG.ins_msg( 'W', 'STS.UpdateRouteStatus',
       'Route ' || l_route_no || ' not found.', NULL,  NULL, 'O', l_program_name );
      COMMIT;
      RETURN;
  end;

  IF i_process = SWMS_MF_READER AND i_action = MANIFEST_RECEIVED THEN

    IF l_sts_status IS NULL THEN
     l_new_status := 'M';
    END IF;

    IF l_sts_status = 'L' THEN
     l_new_status := 'B';
    END IF;
  END IF;

  IF i_process = SLS AND i_action = LOAD_COMPLETE THEN

    IF l_sts_status IS NULL THEN
     l_new_status := 'L';
    END IF;

    IF l_sts_status = 'M' THEN
     l_new_status := 'B';
    END IF;
  END IF;

  IF NOT l_new_status IS NULL THEN
     begin
        UPDATE ROUTE SET STS_STATUS = l_new_status WHERE ROUTE_NO = l_route_no;

        EXCEPTION

           --Failed to build the route file
           WHEN BUILDROUTE_ERR THEN

              STS_WRITE_LOG( SYSDATE, 'SQER',
                            substr( SQLERRM( SQLCODE ), 1, 2000 ) );

              PL_LOG.ins_msg( 'W', 'STS.UpdateRouteStatus',
                               'Error updating STSStatus for Route ' ||
                                l_route_no,
                                SQLCODE,
                                substr(SQLERRM( SQLCODE ), 1, 1000 ),
                                'O', l_program_name );

              --We failed to build the route file, but commit the rest of the activity
              COMMIT;
              UPDATE ROUTE SET STS_STATUS = 'E' WHERE ROUTE_NO = l_route_no;              
              COMMIT;
              RETURN;

           WHEN OTHERS THEN

              STS_WRITE_LOG( SYSDATE, 'SQER',
                           substr( SQLERRM( SQLCODE ), 1, 2000) );

              PL_LOG.ins_msg( 'W', 'STS.UpdateRouteStatus',
                               'Error updating STSStatus for Route ' ||
                                l_route_no,
                                SQLCODE,
                                substr(SQLERRM( SQLCODE ), 1, 1000 ),
                                'O', l_program_name );

              -- Rollback what we have done so far
              ROLLBACK;
              UPDATE ROUTE SET STS_STATUS = 'E' WHERE ROUTE_NO = l_route_no;              
              COMMIT;
              RETURN;
     end;
  END IF;

   -- Must either do a commit or a rollback when returning from an atonomous trans
  COMMIT;

end UpdateRouteStatus;

PROCEDURE Cleanup  
IS                                                     
PRAGMA AUTONOMOUS_TRANSACTION; 
DaysToRetain   INTEGER;
ExpiredDate    DATE;
del_table_name VARCHAR2(20);
begin
   begin
      SELECT TO_NUMBER(CONFIG_FLAG_VAL) INTO DaysToRetain FROM SYS_CONFIG 
      WHERE CONFIG_FLAG_NAME = 'STS_TMPTABLES_HIST';          

      EXCEPTION WHEN NO_DATA_FOUND THEN
         DaysToRetain := 14;
   end;

   ExpiredDate := SYSDATE - DaysToRetain;

   begin
      del_table_name := 'STS_ITEMS';
      DELETE FROM STS_ITEMS      WHERE ROUTE_DATE < ExpiredDate;
      
      del_table_name := 'STS_PICKUPS';
      DELETE FROM STS_PICKUPS    WHERE ROUTE_DATE < ExpiredDate;
      
      del_table_name := 'STS_CASES';
      DELETE FROM STS_CASES      WHERE ROUTE_DATE < ExpiredDate;
      
      del_table_name := 'STS_DUP_LABEL';
      DELETE FROM STS_DUP_LABEL  WHERE ROUTE_DATE < ExpiredDate;
      
      del_table_name := 'STS_CASH_BATCH';
      DELETE FROM STS_CASH_BATCH WHERE ROUTE_DATE < ExpiredDate AND
                                       UPLOAD_TIME IS NOT NULL;
      del_table_name := 'STS_LOG';
      DELETE FROM STS_LOG WHERE LOG_TIME < ExpiredDate;
      
      del_table_name := 'STS_STOP_EQUIPMENT';
      DELETE FROM STS_STOP_EQUIPMENT WHERE ROUTE_DATE < ExpiredDate;
                                       
      EXCEPTION WHEN OTHERS THEN
         ROLLBACK;
         PL_LOG.ins_msg( 'W', 'STS.Cleanup',
                                        'Error deleting STS table ' ||
                                         del_table_name || ' for date ' ||
                                         TO_CHAR( ExpiredDate ),
                                         SQLCODE,
                                         substr(SQLERRM( SQLCODE ), 1, 1000 ),
                                         'O', 'STS' );         
         return;
   end;

   PL_LOG.ins_msg( 'I', 'STS.Cleanup',
                        'Purged STS Temp Tables for Dates older than ' ||
                         TO_CHAR( ExpiredDate ),
                         0, '', 'O', 'STS' );
   COMMIT;
   return;
end Cleanup; 

end STS;
/

grant execute on SWMS.STS to PUBLIC;

create or replace public synonym STS for SWMS.STS;

