Insert Into Print_Reports (Report,Queue_Type,Descrip,Command,Fifo,Filter,Copies,Duplex) 
Values ('mx1ii','SQLP','Symbotic Inventory Sync Exception Report by Item','runsqlrpt -c :c :p/:f :r','N',NULL,1,'N');

COMMIT;
