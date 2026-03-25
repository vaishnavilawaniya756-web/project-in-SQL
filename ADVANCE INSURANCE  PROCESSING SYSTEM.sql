USE Insurance_DB


-- =====================================
-- TABLES
-- =====================================

CREATE TABLE Customers (
    customer_id INT PRIMARY KEY IDENTITY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15),
    address VARCHAR(255),
    date_of_birth DATE,
    min_premium DECIMAL(10,2) CHECK (min_premium > 0),
    status VARCHAR(10) DEFAULT 'INACTIVE',
    CONSTRAINT chk_status CHECK (status IN ('ACTIVE','INACTIVE'))
);

CREATE TABLE Agents (
    agent_id INT PRIMARY KEY IDENTITY,
    agent_name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15),
    commission_rate DECIMAL(5,2) CHECK (commission_rate >= 0)
);

CREATE TABLE Policies (
    policy_id INT PRIMARY KEY IDENTITY,
    policy_name VARCHAR(100),
    policy_type VARCHAR(50),
    premium_amount DECIMAL(10,2) CHECK (premium_amount > 0),
    start_date DATE,
    end_date DATE,
    customer_id INT,
    agent_id INT,
    policy_duration AS DATEDIFF(YEAR, start_date, end_date),
    CONSTRAINT chk_dates CHECK (end_date > start_date),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES Agents(agent_id)
);

CREATE TABLE Claims (
    claim_id INT PRIMARY KEY IDENTITY,
    claim_date DATE,
    claim_amount DECIMAL(10,2),
    claim_status VARCHAR(50),
    policy_id INT,
    CONSTRAINT chk_claim_status CHECK (claim_status IN ('Approved','Pending','Rejected')),
    FOREIGN KEY (policy_id) REFERENCES Policies(policy_id) ON DELETE CASCADE
);

CREATE TABLE Payments (
    payment_id INT PRIMARY KEY IDENTITY,
    payment_date DATE DEFAULT GETDATE(),
    amount DECIMAL(10,2) CHECK (amount > 0),
    payment_method VARCHAR(50),
    policy_id INT,
    FOREIGN KEY (policy_id) REFERENCES Policies(policy_id) ON DELETE CASCADE
);


-- =====================================
-- INSERT STRUCTURED DATA
-- =====================================

-- CUSTOMERS
INSERT INTO Customers 
(full_name, email, phone, address, date_of_birth, min_premium)
VALUES
('Rahul Sharma', 'rahul@gmail.com', '9876543210', 'Delhi', '1990-05-15', 10000),
('Priya Verma', 'priya@gmail.com', '9123456780', 'Mumbai', '1988-09-22', 8000),
('Amit Singh', 'amit@gmail.com', '9988776655', 'Bangalore', '1992-12-05', 5000),
('Sneha Rao', 'sneha@gmail.com', '9112233445', 'Chennai', '1995-07-18', 7000);

INSERT INTO Customers 
(full_name, email, phone, address, date_of_birth, min_premium)
VALUES ('Neha Gupta', 'neha.gupta@gmail.com', '9840040040', 'Lucknow', '1995-01-18', 7000);

-- AGENTS
INSERT INTO Agents 
(agent_name, email, phone, commission_rate)
VALUES
('Anil Kapoor', 'anil@gmail.com', '9001122334', 5.5),
('Sunita Mehta', 'sunita@gmail.com', '9012233445', 4.5),
('Rohit Jain', 'rohit@gmail.com', '9023344556', 6.0);

INSERT INTO Agents 
(agent_name, email, phone, commission_rate)
VALUES
('Meera Singh', 'meera.agent@gmail.com', '9001112233', 5.2);

-- POLICIES
INSERT INTO Policies
(policy_name, policy_type, premium_amount, start_date, end_date, customer_id, agent_id)
VALUES
('Life Plan', 'Life', 15000, '2025-01-01', '2035-01-01', 1, 1),
('Health Plan', 'Health', 9000, '2025-01-01', '2027-01-01', 2, 2),
('Car Plan', 'Vehicle', 6000, '2025-01-01', '2026-01-01', 3, 3);

INSERT INTO Policies
(policy_name, policy_type, premium_amount, start_date, end_date, customer_id, agent_id)
VALUES
('Premium Life Plan', 'Life', 12000, '2025-07-01', '2035-07-01', 1, 1);


-- CLAIMS
INSERT INTO Claims
(claim_date, claim_amount, claim_status, policy_id)
VALUES
('2025-02-01', 5000, 'Approved', 1);
INSERT INTO Claims
(claim_date, claim_amount, claim_status, policy_id)
VALUES
('2025-08-01', 4000, 'Pending', 1);

-- PAYMENTS
INSERT INTO Payments
(payment_date, amount, payment_method, policy_id)
VALUES
('2025-01-01', 15000, 'Card', 1);
INSERT INTO Payments
(payment_date, amount, payment_method, policy_id)
VALUES
('2025-07-10', 6000, 'UPI', 1);


-- =====================================
-- QUERIES
-- =====================================


SELECT * FROM Customers;
SELECT * FROM Agents;
SELECT * FROM Policies;
SELECT * FROM Claims;
SELECT * FROM Payments;


--CUSTOMER NAME AND POLICY NAME WITH PREMIUM AMOUNT
SELECT c.full_name, p.policy_name, p.premium_amount
FROM Customers c
JOIN Policies p ON c.customer_id = p.customer_id;


--CUSTOMER DETAIL WHOSE CLAIM HAS APPROVED
SELECT c.full_name,c.email,c.min_premium,p.policy_duration
FROM Customers c
JOIN Policies p ON c.customer_id = p.customer_id
JOIN Claims cl ON p.policy_id = cl.policy_id
WHERE cl.claim_status = 'Approved';


--TOTAL PREMIUM AMOUNT
SELECT SUM(premium_amount) AS total_revenue
FROM Policies;

--HIGHEST PREMIUM POLICY
SELECT TOP 1 *
FROM Policies
ORDER BY premium_amount DESC;

--AGENT'S POLICIES
SELECT 
    a.agent_name,
    COUNT(p.policy_id) AS total_policies
FROM Agents a
LEFT JOIN Policies p ON a.agent_id = p.agent_id
GROUP BY a.agent_name;


--PROCEDURE FOR CUSTOMER DETAIL
CREATE PROCEDURE GetCustomerDetails
    @customer_id INT
AS
BEGIN
    SELECT 
        c.customer_id, c.full_name, c.email,c.status,p.policy_name,p.premium_amount,p.start_date, p.end_date
    FROM Customers c
    LEFT JOIN Policies p 
        ON c.customer_id = p.customer_id
    WHERE c.customer_id = @customer_id;
END;

EXEC GetCustomerDetails 2;


-- =====================================
-- TRIGGERS
-- =====================================

-- POLICY TRIGGER
CREATE TRIGGER trg_policy_validation
ON Policies
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE end_date < CAST(GETDATE() AS DATE)
    )
    BEGIN
        RAISERROR ('Cannot insert expired policy', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Customers c ON i.customer_id = c.customer_id
        WHERE i.premium_amount < c.min_premium
    )
    BEGIN
        RAISERROR ('Premium below customer minimum', 16, 2);
        RETURN;
    END;

    INSERT INTO Policies (policy_name, policy_type, premium_amount, start_date, end_date, customer_id, agent_id)
    SELECT policy_name, policy_type, premium_amount, start_date, end_date, customer_id, agent_id
    FROM inserted;

    UPDATE c
    SET status = 'ACTIVE'
    FROM Customers c
    WHERE c.customer_id IN (SELECT customer_id FROM inserted);
END;


-- =====================================
-- TRIGGER TEST CASES
-- =====================================

-- Expired policy (will fail)
INSERT INTO Policies
VALUES ('health Plan','Life',5000,'2020-01-01','2021-01-01',1,1);

-- Low premium (will fail)
INSERT INTO Policies
VALUES ('life Plan','Life',1000,'2025-01-01','2030-01-01',1,1);

--valid premium
insert into policies values ('Health Plan', 'Health', 9000, '2025-01-01', '2027-01-01', 2, 2)

-- Invalid payment (will fail)
INSERT INTO Payments
VALUES ('2025-01-01',-500,'Cash',1);

--  Valid payment
INSERT INTO Payments
VALUES ('2025-01-01',5000,'Cash',1);


--DYNAMIC TRIGGER FOR MINIMUM PAID PREMIUM
CREATE TRIGGER trg_minimum_premium_payment
ON Payments
INSTEAD OF INSERT
AS
BEGIN
    -- Check if total payment is less than customer's minimum premium
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Policies p ON i.policy_id = p.policy_id
        JOIN Customers c ON p.customer_id = c.customer_id
        WHERE (
            i.amount + ISNULL(
                (SELECT SUM(amount) 
                 FROM Payments 
                 WHERE policy_id = i.policy_id), 0
            )
        ) < c.min_premium
    )
    BEGIN
        RAISERROR ('Total payment is less than customer minimum premium', 16, 1);
        RETURN;
    END;

    --  Insert valid payments
    INSERT INTO Payments (payment_date, amount, payment_method, policy_id)
    SELECT payment_date, amount, payment_method, policy_id
    FROM inserted;
END;
--CHECK TRIGGER FOR VALID PAYMENT
INSERT INTO Payments (payment_date, amount, payment_method, policy_id)
VALUES ('2025-01-01', 3000, 'UPI', 1);





