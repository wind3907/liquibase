/****************************************************************************
** Date:       06-JUN-2013
** File:       CRQ43501_sts_trip_master.sql
**
**             Script for creating adding two fields status and err_comment in
**             in RETURNS table as part of validating item number, reason code etc.
**
**    - SCRIPTS
**
**    Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    06/06/13   aver0639  CRQ43501_sts_trip_master.sql
**    15-Sept-13 knha8378 adding prefix swms in front of table                 

****************************************************************************/
ALTER TABLE SWMS.RETURNS 
ADD (Status varchar2(4),
     Err_Comment varchar2(500));


/*****End of Script*****/
