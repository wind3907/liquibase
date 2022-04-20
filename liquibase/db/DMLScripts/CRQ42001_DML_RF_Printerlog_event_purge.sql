/****************************************************************************
**
** Insert into purge table rf event logs for printer.
**
***************************************************************************/
BEGIN

INSERT INTO sap_interface_purge (table_name, retention_days, description)
VALUES ('RF_PRINTERLOG_EVENT', 30, 'RF Printer Log event');

EXCEPTION

        WHEN DUP_VAL_ON_INDEX THEN

        NULL;
END;

/

COMMIT;
