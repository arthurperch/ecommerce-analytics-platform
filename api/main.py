from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime, date, timedelta
import logging
import os
import asyncio
import uvicorn
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.sql import text
import pandas as pd
from contextlib import asynccontextmanager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./analytics.db")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database Models
class SalesTransaction(Base):
    __tablename__ = "sales_transactions"
    
    id = Column(Integer, primary_key=True, index=True)
    transaction_id = Column(String(50), unique=True, index=True)
    customer_id = Column(String(50), index=True)
    product_id = Column(String(50), index=True)
    product_name = Column(String(200))
    category = Column(String(100))
    quantity = Column(Integer)
    unit_price = Column(Float)
    total_amount = Column(Float)
    transaction_date = Column(DateTime)
    region = Column(String(50))
    channel = Column(String(50))  # online, store, mobile
    created_at = Column(DateTime, default=datetime.utcnow)

class CustomerMetrics(Base):
    __tablename__ = "customer_metrics"
    
    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(String(50), unique=True, index=True)
    total_orders = Column(Integer, default=0)
    total_spent = Column(Float, default=0.0)
    avg_order_value = Column(Float, default=0.0)
    last_purchase_date = Column(DateTime)
    customer_lifetime_value = Column(Float, default=0.0)
    is_active = Column(Boolean, default=True)
    acquisition_date = Column(DateTime)
    updated_at = Column(DateTime, default=datetime.utcnow)

# Pydantic Models
class SalesMetricsResponse(BaseModel):
    total_revenue: float
    total_transactions: int
    avg_transaction_value: float
    top_selling_products: List[Dict[str, Any]]
    revenue_by_region: Dict[str, float]
    revenue_by_channel: Dict[str, float]

class CustomerAnalyticsResponse(BaseModel):
    total_customers: int
    active_customers: int
    avg_customer_lifetime_value: float
    customer_retention_rate: float
    top_customers: List[Dict[str, Any]]

class ProductPerformanceResponse(BaseModel):
    total_products: int
    top_performing_products: List[Dict[str, Any]]
    category_performance: Dict[str, float]
    inventory_insights: Dict[str, Any]

class HealthResponse(BaseModel):
    status: str
    timestamp: datetime
    database_status: str
    environment: str

# Dependency to get database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Lifespan manager for startup and shutdown events
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting E-commerce Analytics Platform API")
    Base.metadata.create_all(bind=engine)
    yield
    # Shutdown
    logger.info("Shutting down E-commerce Analytics Platform API")

# FastAPI app initialization
app = FastAPI(
    title="E-commerce Analytics Platform",
    description="AWS-powered analytics platform for e-commerce businesses",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health", response_model=HealthResponse)
async def health_check(db: Session = Depends(get_db)):
    """Health check endpoint for load balancer and monitoring"""
    try:
        # Test database connection
        db.execute(text("SELECT 1"))
        db_status = "healthy"
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        db_status = "unhealthy"
    
    return HealthResponse(
        status="healthy" if db_status == "healthy" else "unhealthy",
        timestamp=datetime.utcnow(),
        database_status=db_status,
        environment=os.getenv("ENVIRONMENT", "development")
    )

# Root endpoint
@app.get("/")
async def root():
    """Welcome endpoint"""
    return {
        "message": "Welcome to E-commerce Analytics Platform",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health"
    }

# Sales Analytics Endpoints
@app.get("/api/v1/analytics/sales", response_model=SalesMetricsResponse)
async def get_sales_analytics(
    start_date: Optional[date] = Query(None, description="Start date for analysis"),
    end_date: Optional[date] = Query(None, description="End date for analysis"),
    region: Optional[str] = Query(None, description="Filter by region"),
    channel: Optional[str] = Query(None, description="Filter by channel"),
    db: Session = Depends(get_db)
):
    """Get comprehensive sales analytics"""
    try:
        # Default to last 30 days if no dates provided
        if not end_date:
            end_date = date.today()
        if not start_date:
            start_date = end_date - timedelta(days=30)
        
        # Build query conditions
        conditions = [
            f"transaction_date >= '{start_date}'",
            f"transaction_date <= '{end_date}'"
        ]
        
        if region:
            conditions.append(f"region = '{region}'")
        if channel:
            conditions.append(f"channel = '{channel}'")
        
        where_clause = " AND ".join(conditions)
        
        # Total revenue and transactions
        revenue_query = f"""
        SELECT 
            SUM(total_amount) as total_revenue,
            COUNT(*) as total_transactions,
            AVG(total_amount) as avg_transaction_value
        FROM sales_transactions 
        WHERE {where_clause}
        """
        
        result = db.execute(text(revenue_query)).fetchone()
        total_revenue = float(result.total_revenue or 0)
        total_transactions = int(result.total_transactions or 0)
        avg_transaction_value = float(result.avg_transaction_value or 0)
        
        # Top selling products
        top_products_query = f"""
        SELECT 
            product_name,
            SUM(quantity) as total_quantity,
            SUM(total_amount) as total_revenue
        FROM sales_transactions 
        WHERE {where_clause}
        GROUP BY product_name, product_id
        ORDER BY total_revenue DESC
        LIMIT 10
        """
        
        top_products = []
        for row in db.execute(text(top_products_query)):
            top_products.append({
                "product_name": row.product_name,
                "total_quantity": int(row.total_quantity),
                "total_revenue": float(row.total_revenue)
            })
        
        # Revenue by region
        region_query = f"""
        SELECT region, SUM(total_amount) as revenue
        FROM sales_transactions 
        WHERE {where_clause}
        GROUP BY region
        """
        
        revenue_by_region = {}
        for row in db.execute(text(region_query)):
            revenue_by_region[row.region] = float(row.revenue)
        
        # Revenue by channel
        channel_query = f"""
        SELECT channel, SUM(total_amount) as revenue
        FROM sales_transactions 
        WHERE {where_clause}
        GROUP BY channel
        """
        
        revenue_by_channel = {}
        for row in db.execute(text(channel_query)):
            revenue_by_channel[row.channel] = float(row.revenue)
        
        return SalesMetricsResponse(
            total_revenue=total_revenue,
            total_transactions=total_transactions,
            avg_transaction_value=avg_transaction_value,
            top_selling_products=top_products,
            revenue_by_region=revenue_by_region,
            revenue_by_channel=revenue_by_channel
        )
        
    except Exception as e:
        logger.error(f"Error in sales analytics: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# Customer Analytics Endpoints
@app.get("/api/v1/analytics/customers", response_model=CustomerAnalyticsResponse)
async def get_customer_analytics(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    """Get customer analytics and insights"""
    try:
        # Total and active customers
        total_customers = db.query(CustomerMetrics).count()
        active_customers = db.query(CustomerMetrics).filter(CustomerMetrics.is_active == True).count()
        
        # Average CLV
        avg_clv_result = db.execute(text("SELECT AVG(customer_lifetime_value) FROM customer_metrics")).fetchone()
        avg_clv = float(avg_clv_result[0] or 0)
        
        # Customer retention rate (simplified calculation)
        retention_rate = (active_customers / total_customers * 100) if total_customers > 0 else 0
        
        # Top customers by CLV
        top_customers_query = """
        SELECT customer_id, total_spent, total_orders, customer_lifetime_value
        FROM customer_metrics
        ORDER BY customer_lifetime_value DESC
        LIMIT 10
        """
        
        top_customers = []
        for row in db.execute(text(top_customers_query)):
            top_customers.append({
                "customer_id": row.customer_id,
                "total_spent": float(row.total_spent),
                "total_orders": int(row.total_orders),
                "customer_lifetime_value": float(row.customer_lifetime_value)
            })
        
        return CustomerAnalyticsResponse(
            total_customers=total_customers,
            active_customers=active_customers,
            avg_customer_lifetime_value=avg_clv,
            customer_retention_rate=retention_rate,
            top_customers=top_customers
        )
        
    except Exception as e:
        logger.error(f"Error in customer analytics: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# Product Performance Endpoints
@app.get("/api/v1/analytics/products", response_model=ProductPerformanceResponse)
async def get_product_analytics(
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    """Get product performance analytics"""
    try:
        # Total unique products
        total_products_query = "SELECT COUNT(DISTINCT product_id) FROM sales_transactions"
        if category:
            total_products_query += f" WHERE category = '{category}'"
        
        total_products = db.execute(text(total_products_query)).fetchone()[0]
        
        # Top performing products
        top_products_query = """
        SELECT 
            product_name,
            category,
            SUM(quantity) as total_sold,
            SUM(total_amount) as total_revenue,
            AVG(unit_price) as avg_price
        FROM sales_transactions
        """
        
        if category:
            top_products_query += f" WHERE category = '{category}'"
        
        top_products_query += """
        GROUP BY product_id, product_name, category
        ORDER BY total_revenue DESC
        LIMIT 10
        """
        
        top_products = []
        for row in db.execute(text(top_products_query)):
            top_products.append({
                "product_name": row.product_name,
                "category": row.category,
                "total_sold": int(row.total_sold),
                "total_revenue": float(row.total_revenue),
                "avg_price": float(row.avg_price)
            })
        
        # Category performance
        category_query = """
        SELECT category, SUM(total_amount) as revenue
        FROM sales_transactions
        GROUP BY category
        ORDER BY revenue DESC
        """
        
        category_performance = {}
        for row in db.execute(text(category_query)):
            category_performance[row.category] = float(row.revenue)
        
        # Simple inventory insights
        inventory_insights = {
            "total_categories": len(category_performance),
            "most_profitable_category": max(category_performance, key=category_performance.get) if category_performance else None,
            "least_profitable_category": min(category_performance, key=category_performance.get) if category_performance else None
        }
        
        return ProductPerformanceResponse(
            total_products=int(total_products or 0),
            top_performing_products=top_products,
            category_performance=category_performance,
            inventory_insights=inventory_insights
        )
        
    except Exception as e:
        logger.error(f"Error in product analytics: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# Data Management Endpoints
@app.post("/api/v1/data/seed")
async def seed_sample_data(db: Session = Depends(get_db)):
    """Seed the database with sample e-commerce data for demonstration"""
    try:
        # Check if data already exists
        existing_count = db.query(SalesTransaction).count()
        if existing_count > 0:
            return {"message": f"Database already contains {existing_count} transactions"}
        
        # Sample data generation logic would go here
        # For now, return a success message
        return {"message": "Sample data seeding endpoint - implement based on business requirements"}
        
    except Exception as e:
        logger.error(f"Error seeding data: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=os.getenv("ENVIRONMENT") == "development"
    )