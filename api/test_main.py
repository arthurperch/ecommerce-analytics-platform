import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from main import app, get_db, Base
import tempfile
import os

# Create a temporary database for testing
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture
def client():
    Base.metadata.create_all(bind=engine)
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(bind=engine)

def test_health_check(client):
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ["healthy", "unhealthy"]
    assert "timestamp" in data
    assert "database_status" in data

def test_root_endpoint(client):
    """Test the root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "version" in data

def test_sales_analytics_endpoint(client):
    """Test the sales analytics endpoint"""
    response = client.get("/api/v1/analytics/sales")
    assert response.status_code == 200
    data = response.json()
    assert "total_revenue" in data
    assert "total_transactions" in data
    assert "avg_transaction_value" in data
    assert "top_selling_products" in data
    assert "revenue_by_region" in data
    assert "revenue_by_channel" in data

def test_customer_analytics_endpoint(client):
    """Test the customer analytics endpoint"""
    response = client.get("/api/v1/analytics/customers")
    assert response.status_code == 200
    data = response.json()
    assert "total_customers" in data
    assert "active_customers" in data
    assert "avg_customer_lifetime_value" in data
    assert "customer_retention_rate" in data
    assert "top_customers" in data

def test_product_analytics_endpoint(client):
    """Test the product analytics endpoint"""
    response = client.get("/api/v1/analytics/products")
    assert response.status_code == 200
    data = response.json()
    assert "total_products" in data
    assert "top_performing_products" in data
    assert "category_performance" in data
    assert "inventory_insights" in data

def test_sales_analytics_with_filters(client):
    """Test sales analytics with query parameters"""
    response = client.get("/api/v1/analytics/sales?region=US&channel=online")
    assert response.status_code == 200

def test_product_analytics_with_category_filter(client):
    """Test product analytics with category filter"""
    response = client.get("/api/v1/analytics/products?category=Electronics")
    assert response.status_code == 200