ALTER TABLE sales.order_item DROP CONSTRAINT IF EXISTS fk_order_item_previous_subscription;
DROP TABLE IF EXISTS sales.subscription;
DROP TABLE IF EXISTS sales.order_item;
DROP TABLE IF EXISTS sales.orders;
