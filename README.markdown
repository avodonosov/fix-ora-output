The output produced by SQL*Plus or TOAD with the default value of the LINESIZE 
system variable is quite nasty. Similar to the following:
```
SQL> select * from users;

        ID
----------
NAME                                                                            
--------------------------------------------------------------------------------
SURNAME                                                                         
--------------------------------------------------------------------------------
LOGIN                                                                           
--------------------------------------------------------------------------------
PASSWORD                                                                        
--------------------------------------------------------------------------------
REGISTRATION_TIME            
-----------------------------
         1
ivan                                                                            
ivanov                                                                          
vanya                                                                           
123                                                                             
26.06.08 21:16:12,000000     
                                                                                
         2
petr                                                                            
petrov                                                                          
petya                                                                           

        ID
----------
NAME                                                                            
--------------------------------------------------------------------------------
SURNAME                                                                         
--------------------------------------------------------------------------------
LOGIN                                                                           
--------------------------------------------------------------------------------
PASSWORD                                                                        
--------------------------------------------------------------------------------
REGISTRATION_TIME            
-----------------------------
qwerty                                                                          
26.06.08 21:16:12,000000     
                                                                                
         3
sidor                                                                           
sidorov                                                                         
sid                                                                             
password                                                                        
26.06.08 21:16:12,000000     
                                                                                


3 rows selected.

SQL> spool off;

```

Sometimes we need to deal with such data when we have no direct access to the database,
for example when the output is sent to you by customer.

The ```fix-ora-output``` utility converts such an output to a pretty thing like this:
```
ID         NAME                                                                             SURNAME                                                                          LOGIN                                                                            PASSWORD                                                                         REGISTRATION_TIME             
---------- -------------------------------------------------------------------------------- -------------------------------------------------------------------------------- -------------------------------------------------------------------------------- -------------------------------------------------------------------------------- ----------------------------- 
         1 ivan                                                                             ivanov                                                                           vanya                                                                            123                                                                              26.06.08 21:16:12,000000      
         2 petr                                                                             petrov                                                                           petya                                                                            qwerty                                                                           26.06.08 21:16:12,000000      
         3 sidor                                                                            sidorov                                                                          sid                                                                              password                                                                         26.06.08 21:16:12,000000      

```
Usage instructions are at the top of the file.
