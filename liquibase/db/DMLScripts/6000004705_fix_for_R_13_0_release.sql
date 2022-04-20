-- fix as part of r_13_0 release

Insert into SWMS.GLOBAL_DATE_FORMAT
   (FORMAT_SEQ, FORMAT_MASK)
 Values
   (21, 'mm/dd/rrrr');
COMMIT;
