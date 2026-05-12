CREATE TABLE authors (
    id SERIAL PRIMARY KEY,
    author_name VARCHAR(100) NOT NULL,
	country VARCHAR(100) NOT NULL,
	birth_date DATE NOT NULL
);

CREATE TABLE books (
    id SERIAL PRIMARY KEY,
	author_id INT NOT NULL,
	title VARCHAR(100) NOT NULL,
	isbn VARCHAR(20) UNIQUE NOT NULL,
	price NUMERIC(10,2) NOT NULL,
	publication_date DATE NOT NULL,

	CONSTRAINT fk_books_authors
        FOREIGN KEY (author_id)
        REFERENCES authors(id)

);
CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    email VARCHAR(100) UNIQUE NOT NULL,
	country VARCHAR(100) NOT NULL,
	created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE orders
(
    id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_status VARCHAR(20) NOT NULL
        CHECK (order_status IN ('new', 'paid', 'shipped', 'cancelled')),
    amount INT NOT NULL,
    price NUMERIC(10,2) NOT NULL,

    CONSTRAINT fk_orders_clients
        FOREIGN KEY (client_id)
        REFERENCES clients(id)
);

CREATE TABLE clients_orders
(
    order_id INT NOT NULL,
    client_id INT NOT NULL,
    amount INT NOT NULL,
	price NUMERIC(10,2) NOT NULL,

	PRIMARY KEY (order_id, client_id),

    CONSTRAINT fk_clients_orders_orders
        FOREIGN KEY (order_id)
        REFERENCES orders(id),

    CONSTRAINT fk_clients_orders_clients
        FOREIGN KEY (client_id)
        REFERENCES clients(id)
);
