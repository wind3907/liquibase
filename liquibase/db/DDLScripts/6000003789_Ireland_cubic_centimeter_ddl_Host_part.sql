/****************************************************************************
** Date:       23-OCT-2014
** File:       6000003789_Ireland_cubic_centimeter_ddl.sql
**
** Script to MODIFY table fields for Ireland Cubic value metric conversion.
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    10/23/14 Infosys  Modified the below table fields for Ireland metric conversion
**
****************************************************************************/
ALTER TABLE CUBITRON_ITEMMASTER_OUT MODIFY CASE_CUBE VARCHAR2(13);
ALTER TABLE CUBITRON_MEASUREMENT_IN MODIFY CASE_CUBE VARCHAR2(13);
ALTER TABLE CUBITRON_MEASUREMENT_IN_BK MODIFY CASE_CUBE VARCHAR2(13);
ALTER TABLE PM MODIFY CASE_CUBE NUMBER(12,4);
ALTER TABLE PM_DIM_EXCEPTION MODIFY CASE_CUBE NUMBER(12,4);
ALTER TABLE SAP_IM_IN MODIFY CASE_CUBE VARCHAR2(13);
ALTER TABLE SYNTELIC_MATERIAL_OUT MODIFY CASE_CUBE VARCHAR2(13);
ALTER TABLE T_CURR_BATCH MODIFY CASE_CUBE NUMBER(12,4);
ALTER TABLE T_CURR_BATCH_SHORT MODIFY CASE_CUBE NUMBER(12,4);
ALTER TABLE FLOATS MODIFY FLOAT_CUBE NUMBER(12,4);
ALTER TABLE FLOATS_BCKUP MODIFY FLOAT_CUBE NUMBER(12,4);
ALTER TABLE T_CURR_BATCH MODIFY FLOAT_CUBE NUMBER(12,4);
ALTER TABLE T_CURR_BATCH_SHORT MODIFY FLOAT_CUBE NUMBER(12,4);