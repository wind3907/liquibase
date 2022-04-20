REM @(#) src/schema/views/v_sos_training.sql, swms, swms.9, 10.1.1 9/7/06 1.3
REM File : @(#) src/schema/views/v_sos_training.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_sos_training.sql, swms, swms.9, 10.1.1
REM
REM      MODIFICATION HISTORY
REM  acpakp 9/29/03  New view to sum kvi values for multi batches.
REM                  This will allow all MULTI batches to get displayed in the
REM                  SOS->TRaining screen.

create or replace view swms.v_sos_training as
select nvl(PARENT_BATCH_NO,BATCH_NO) BATCH_NO,
       SUM(KVI_NO_STOP) KVI_NO_STOP,
       SUM(KVI_NO_ITEM) KVI_NO_ITEM,
       SUM(KVI_NO_CASE) KVI_NO_CASE,
       SUM(KVI_CUBE) KVI_CUBE,
       SUM(KVI_WT) KVI_WT
from   BATCH
where  BATCH_NO like 'S%'
and    STATUS in ('F','M')
group  by nvl(PARENT_BATCH_NO,BATCH_NO)
/

