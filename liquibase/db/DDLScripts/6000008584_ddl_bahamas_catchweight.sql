--
-- Charm for enabling item level weight units for Bahamas
-- Add a new column to catch weight table for storing weight in different weight unit
-- Date :17-Sep-15
-- Done by : Infosys 

ALTER TABLE ORDCW ADD (CW_KG_LB NUMBER(9,3));

