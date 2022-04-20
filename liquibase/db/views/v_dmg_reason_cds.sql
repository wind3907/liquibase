REM @(#) src/schema/views/v_dmg_reason_cds.sql, swms, swms.9, 11.1 3/2/09 1.2 
REM File : @(#) src/schema/views/v_dmg_reason_cds.sql, swms, swms.9, 11.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_dmg_reason_cds.sql, swms, swms.9, 11.1
REM
REM      MODIFICATION HISTORY
REM  03/30/10 Infosys D#12554 New View Created for fetching reason codes for  
REM                   tracking damages

CREATE OR REPLACE VIEW swms.v_dmg_reason_cds AS 
SELECT 
    reason_cd_type,
    reason_cd, 
    reason_desc,
    resale,
    reason_group,
    misc,
    cc_reason_code,
    DECODE(reason_cd, 'WH', 1,'SP', 2,'TD', 3,'SR', 4, 5) reason_ord
FROM reason_cds
WHERE reason_cd_type  = 'ADJ'
AND resale = 'Y'
ORDER BY  reason_ord, reason_cd;
