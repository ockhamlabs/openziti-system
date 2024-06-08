## clone this chart https://github.com/sadathknorket/trino-charts

## install with helm 

## after that exec into coordinator 

## run 

trino --debug

show catalogs;

CREATE CATALOG memory USING postgresql with (
    "connection-url"='jdbc:postgresql://postgres.ziti.internal:5432/mydb', 
    "connection-user"='myuser', 
    "connection-password"='mypassword'
);

select * from memory.public.employees;

## should be succeess

