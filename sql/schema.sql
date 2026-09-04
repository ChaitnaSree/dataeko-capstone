-- DATAEKO capstone schema.
-- Five tables. Foreign keys are real and they are enforced.

DROP TABLE IF EXISTS deliveries, orders, customers, drinks, stores CASCADE;

CREATE TABLE stores (
  id        serial PRIMARY KEY,
  name      text NOT NULL,
  city      text NOT NULL,
  opened_on date NOT NULL
);

CREATE TABLE drinks (
  id        serial PRIMARY KEY,
  name      text NOT NULL,
  size      text NOT NULL CHECK (size IN ('small','medium','large')),
  price_inr integer NOT NULL CHECK (price_inr > 0),
  category  text NOT NULL
);

CREATE TABLE customers (
  id        serial PRIMARY KEY,
  name      text NOT NULL,
  email     text UNIQUE NOT NULL,
  joined_on date NOT NULL,
  store_id  integer NOT NULL REFERENCES stores(id)
);

CREATE TABLE orders (
  id          serial PRIMARY KEY,
  customer_id integer NOT NULL REFERENCES customers(id),
  drink_id    integer NOT NULL REFERENCES drinks(id),
  store_id    integer NOT NULL REFERENCES stores(id),
  qty         integer NOT NULL CHECK (qty > 0),
  ordered_at  timestamptz NOT NULL,
  status      text NOT NULL CHECK (status IN ('placed','ready','collected','cancelled'))
);

-- Deliberately NOT every order has a delivery row.
-- That is what makes the anti-join question in Phase 3 a real question.
CREATE TABLE deliveries (
  id           serial PRIMARY KEY,
  order_id     integer NOT NULL REFERENCES orders(id),
  courier      text NOT NULL,
  delivered_at timestamptz,
  status       text NOT NULL CHECK (status IN ('pending','delivered','failed'))
);
