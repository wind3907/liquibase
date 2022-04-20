/* CRQ47475 - QA requests Food Safety to use HACCP CODE for temperature collection */
/* Added a new coulmn called food_safety_trk in haccp_codes table */

ALTER TABLE swms.haccp_codes ADD (food_safety_trk VARCHAR2(1) DEFAULT 'N');

