---------------------------------------------------------------------
--     Date   Charm             Description 
--
-- 02/01/16   6000008476        Adding a new column to ROUTE table for
--                              holding auto route close status
--
--
--
----------------------------------------------------------------------

ALTER TABLE SWMS.ROUTE ADD AUTO_CLOSE_STATUS VARCHAR2(1 BYTE);
ALTER TABLE SWMS.ROUTE_BCKUP ADD AUTO_CLOSE_STATUS VARCHAR2(1 BYTE);
 
