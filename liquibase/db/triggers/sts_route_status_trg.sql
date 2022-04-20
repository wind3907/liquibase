CREATE OR REPLACE TRIGGER "SWMS"."STS_ROUTE_STATUS_TRG" BEFORE 
    UPDATE OF "ROUTE_NO", "STS_STATUS" 
    ON "SWMS"."ROUTE" 
    FOR EACH ROW 
DECLARE
-- local declarations
LAS_Active     SYS_CONFIG.config_flag_val%TYPE;
STS_Active     SYS_CONFIG.config_flag_val%TYPE;
RouteNo        INTEGER;

BEGIN

BEGIN
   /* Obtain the LAS_ACTIVE parameter from within SYS_CONFIG  */
   SELECT CONFIG_FLAG_VAL INTO LAS_Active FROM SYS_CONFIG
          WHERE CONFIG_FLAG_NAME = 'LAS_ACTIVE';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
      LAS_Active := 'N';
END;

BEGIN
/* Obtain the STS_ACTIVE parameter from within SYS_CONFIG  */
   SELECT CONFIG_FLAG_VAL INTO STS_Active FROM SYS_CONFIG
          WHERE CONFIG_FLAG_NAME = 'STS_ACTIVE';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
   STS_Active := 'N';
END;

/* Convert the route into a number */
BEGIN
   RouteNo := TO_NUMBER(:new.route_no);
EXCEPTION
   WHEN OTHERS THEN
    RouteNo := 0;
END;

/* The Sysco Loading System (SLS) will set the STS_Status  */
/* to 'L' when the trailer is loaded before the manifest   */
/* comes down.  SWMS Manifest Reader will set STS_Status   */
/* to 'M' when the manifest comes down before loading is   */
/* completed.  If either step detects the other has        */
/* already occurred, then it will set STS_Status to 'B'    */
/*                                                         */
/* If the manifest comes down, have the trigger call       */
/* STS_POPULATE_ROUTE.                                     */
/* In both cases STS has to be active, the route needs to  */
/* be a number 4 digits or less                            */

IF RouteNo > 0  AND
   RouteNo < 10000 AND
   STS_Active = 'Y' AND
   :new.STS_Status IN ('B','M') THEN

     /* Log that the trigger has fired */
    STS_WRITE_LOG( SYSDATE, 'TRIG', 'Route ' || :new.route_no ||
                                  ' STS Route Trigger Fired');

    /* Call the STS_Populate_Route procedure to populate     */
    /* the STS Historical Tables.  These tables are used     */
    /* to create the STS Route View which ultimately builds  */
    /* the STS Route Files on the STS Host.                  */
    STS_POPULATE_ROUTE(:new.route_no, :new.method_id);
    :new.sts_status := 'P';
END IF;

END;
/
