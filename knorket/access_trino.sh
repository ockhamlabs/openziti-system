## access trino with trino.ziti.internal 

## install trino-cli using devbox 

trino --server trino.ziti.internal:8080

show catalogs;

select * from memory.public.employees;