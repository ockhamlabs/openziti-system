docker run --name my_postgres_container -e POSTGRES_USER=myuser -e POSTGRES_PASSWORD=mypassword -p 5432:5432 -d postgres

docker exec -it my_postgres_container psql -U myuser

CREATE DATABASE mydb;

\c mydb

CREATE TABLE employee (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    hire_date DATE
);

INSERT INTO employee (first_name, last_name, email, hire_date)
VALUES 
('John', 'Doe', 'john.doe@example.com', '2020-01-15'),
('Jane', 'Smith', 'jane.smith@example.com', '2019-07-23'),
('Robert', 'Brown', 'robert.brown@example.com', '2021-03-10');
