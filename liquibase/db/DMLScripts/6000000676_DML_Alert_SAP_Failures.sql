SET DEFINE OFF;
Insert into SWMS.SWMS_ALERT_NOTIFICATION
   (MODULES, ERROR_TYPE, CREATE_TICKET, SEND_EMAIL, PRIMARY_RECIPIENT, ALTERNATE_RECIPIENT)
 Values
   ('SWMSPOREADER', 'CRIT', 'Y', 'N', '000-INFOSYS-SWMS_Support@corp.sysco.com', 
    '000-IT-APPDEV-SWMS@corp.sysco.com');
Insert into SWMS.SWMS_ALERT_NOTIFICATION
   (MODULES, ERROR_TYPE, CREATE_TICKET, SEND_EMAIL, PRIMARY_RECIPIENT, ALTERNATE_RECIPIENT)
 Values
   ('SWMSPOREADER', 'WARN', 'N', 'N', '000-INFOSYS-SWMS_Support@corp.sysco.com', 
    '000-IT-APPDEV-SWMS@corp.sysco.com');
Insert into SWMS.SWMS_ALERT_NOTIFICATION
   (MODULES, ERROR_TYPE, CREATE_TICKET, SEND_EMAIL, PRIMARY_RECIPIENT, ALTERNATE_RECIPIENT)
 Values
   ('SWMSPOREADER', 'INFO', 'N', 'N', '000-INFOSYS-SWMS_Support@corp.sysco.com', 
    '000-IT-APPDEV-SWMS@corp.sysco.com');
Insert into SWMS.SWMS_ALERT_NOTIFICATION
   (MODULES, ERROR_TYPE, CREATE_TICKET, SEND_EMAIL, PRIMARY_RECIPIENT, ALTERNATE_RECIPIENT)
 Values
   ('SWMSORREADER', 'WARN', 'N', 'N', '000-INFOSYS-SWMS_Support@corp.sysco.com', 
    '000-IT-APPDEV-SWMS@corp.sysco.com');
Insert into SWMS.SWMS_ALERT_NOTIFICATION
   (MODULES, ERROR_TYPE, CREATE_TICKET, SEND_EMAIL, PRIMARY_RECIPIENT, ALTERNATE_RECIPIENT)
 Values
   ('SWMSORREADER', 'CRIT', 'Y', 'N', '000-INFOSYS-SWMS_Support@corp.sysco.com', 
    '000-IT-APPDEV-SWMS@corp.sysco.com');
Insert into SWMS.SWMS_ALERT_NOTIFICATION
   (MODULES, ERROR_TYPE, CREATE_TICKET, SEND_EMAIL, PRIMARY_RECIPIENT, ALTERNATE_RECIPIENT)
 Values
   ('SWMSORREADER', 'INFO', 'N', 'N', '000-INFOSYS-SWMS_Support@corp.sysco.com', 
    '000-IT-APPDEV-SWMS@corp.sysco.com');

COMMIT;
