Insert Into Print_Reports (Report,Queue_Type,Descrip,Command,Fifo,Filter,Copies,Duplex) 
Values ('mx1is','SQLP','Symbotic Inventory Sync Exception Report','runsqlrpt -c :c :p/:f :r','Y','l',1,'N');

COMMIT;
