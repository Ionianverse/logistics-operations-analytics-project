import mysql.connector
from faker import Faker
import random
from datetime import timedelta

fake = Faker()

conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="Usz@123456",
    database="sales_ops_analytics"
)

cur = conn.cursor()

# ---------- Customers ----------
def insert_customers(n=100):
    for _ in range(n):
        cur.execute("""
        INSERT INTO customers (customer_name, city, state, segment)
        VALUES (%s, %s, %s, %s)
        """, (
            fake.name(),
            fake.city(),
            fake.state(),
            random.choice(["Retail", "Corporate", "Online", "Wholesale"])
        ))
    conn.commit()

# ---------- Products ----------

PRODUCT_CATALOG = {
    "Electronics": ["Laptop", "Mouse", "Keyboard", "Monitor", "Printer", "Router", "Webcam"],
    "Furniture": ["Office Chair", "Desk", "Table", "Bookshelf", "Sofa"],
    "Clothing": ["T-Shirt", "Jeans", "Jacket", "Shoes", "Cap"],
    "Office": ["Pen", "Notebook", "Stapler", "Calculator", "File Folder"]
}

def insert_products(n=40):
    for _ in range(n):
        category = random.choice(list(PRODUCT_CATALOG.keys()))
        product_name = random.choice(PRODUCT_CATALOG[category])

        # realistic price ranges per category
        if category == "Electronics":
            price = random.randint(3000, 60000)
        elif category == "Furniture":
            price = random.randint(2000, 30000)
        elif category == "Clothing":
            price = random.randint(500, 5000)
        else:  # Office
            price = random.randint(200, 3000)

        cur.execute("""
        INSERT INTO products (product_name, category, price)
        VALUES (%s, %s, %s)
        """, (product_name, category, price))

    conn.commit()


# ---------- Orders ----------
def insert_orders(n=300):
    cur.execute("SELECT customer_id FROM customers")
    customers = [c[0] for c in cur.fetchall()]

    for _ in range(n):
        cur.execute("""
        INSERT INTO orders (order_date, customer_id, order_status, sales_rep)
        VALUES (%s, %s, %s, %s)
        """, (
            fake.date_between(start_date="-6M", end_date="today"),
            random.choice(customers),
            random.choice(["Completed", "Pending", "Cancelled"]),
            fake.first_name()
        ))
    conn.commit()

# ---------- Order Items ----------
def insert_order_items():
    cur.execute("SELECT order_id FROM orders ORDER BY order_id DESC LIMIT 300")
    orders = [o[0] for o in cur.fetchall()]

    cur.execute("SELECT product_id, price FROM products")
    products = cur.fetchall()

    for o in orders:
        for _ in range(random.randint(1, 4)):
            p = random.choice(products)
            qty = random.randint(1, 5)
            cur.execute("""
            INSERT INTO order_items (order_id, product_id, quantity, unit_price)
            VALUES (%s, %s, %s, %s)
            """, (o, p[0], qty, p[1]))
    conn.commit()

# ---------- Shipments ----------
def insert_shipments():
    cur.execute("SELECT order_id, order_date FROM orders ORDER BY order_id DESC LIMIT 300")
    rows = cur.fetchall()

    for r in rows:
        ship = r[1] + timedelta(days=random.randint(1, 4))
        deliver = ship + timedelta(days=random.randint(2, 7))
        cur.execute("""
        INSERT INTO shipments (order_id, ship_date, delivery_date, status)
        VALUES (%s, %s, %s, %s)
        """, (
            r[0], ship, deliver,
            random.choice(["Delivered", "In Transit"])
        ))
    conn.commit()

# ---------- RUN ----------
insert_customers(80)
insert_products(40)
insert_orders(250)
insert_order_items()
insert_shipments()

print("✅ 200–500 realistic business rows inserted!")



