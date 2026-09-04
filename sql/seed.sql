-- Generates the dataset. No download: generate_series builds it in the database.
-- ~400,000 orders. Takes about 10 seconds.

INSERT INTO stores (name, city, opened_on) VALUES
  ('Bandra Flagship','Mumbai','2019-03-01'),
  ('Koregaon Park','Pune','2020-07-15'),
  ('Indiranagar','Bengaluru','2018-11-20'),
  ('Hauz Khas','Delhi','2021-01-10'),
  ('T Nagar','Chennai','2022-06-05'),
  ('Banjara Hills','Hyderabad','2023-02-14');

INSERT INTO drinks (name, size, price_inr, category) VALUES
  ('latte','small',160,'espresso'),      ('latte','medium',200,'espresso'),
  ('latte','large',220,'espresso'),      ('mocha','medium',260,'espresso'),
  ('mocha','large',290,'espresso'),      ('espresso','small',150,'espresso'),
  ('cappuccino','large',240,'espresso'), ('flat white','medium',230,'espresso'),
  ('americano','small',170,'espresso'),  ('cold brew','large',280,'cold'),
  ('iced latte','medium',240,'cold'),    ('frappe','large',310,'cold'),
  ('masala chai','small',90,'tea'),      ('green tea','medium',120,'tea'),
  ('matcha latte','large',300,'tea'),
  -- three drinks nobody will ever order. Phase 3 asks you to find them.
  ('turmeric latte','medium',270,'seasonal'),
  ('rose cardamom','large',330,'seasonal'),
  ('affogato','small',350,'dessert');

INSERT INTO customers (name, email, joined_on, store_id)
SELECT
  'customer_' || g,
  'customer_' || g || '@example.com',
  DATE '2022-01-01' + (g % 900),
  1 + (g % 6)
FROM generate_series(1, 20000) g;

INSERT INTO orders (customer_id, drink_id, store_id, qty, ordered_at, status)
SELECT
  1 + (g % 20000),
  1 + (g % 15),                                  -- only drinks 1..15 ever ordered
  1 + (g % 6),
  1 + (g % 3),
  TIMESTAMPTZ '2025-01-01 08:00:00+05:30' + (g % 250) * INTERVAL '1 day'
                                              + (g % 600) * INTERVAL '1 minute',
  (ARRAY['placed','ready','collected','collected','cancelled'])[1 + (g % 5)]
FROM generate_series(1, 400000) g;

-- Only 80% of orders get a delivery row -> 80,000 orders have none.
INSERT INTO deliveries (order_id, courier, delivered_at, status)
SELECT
  o.id,
  (ARRAY['swift','dash','pronto'])[1 + (o.id % 3)],
  CASE WHEN o.id % 7 = 0 THEN NULL ELSE o.ordered_at + INTERVAL '25 minutes' END,
  (ARRAY['delivered','delivered','delivered','pending','failed'])[1 + (o.id % 5)]
FROM orders o
WHERE o.id % 5 <> 0;

ANALYZE;
