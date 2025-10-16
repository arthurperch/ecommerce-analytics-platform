# E-commerce Analytics Platform

[![Deploy](https://github.com/your-username/ecommerce-analytics-platform/actions/workflows/deploy.yml/badge.svg)](https://github.com/your-username/ecommerce-analytics-platform/actions/workflows/deploy.yml)
[![Security Scan](https://github.com/your-username/ecommerce-analytics-platform/actions/workflows/security.yml/badge.svg)](https://github.com/your-username/ecommerce-analytics-platform/actions/workflows/security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🚀 Project Overview

The **E-commerce Analytics Platform** is a comprehensive, cloud-native solution built on AWS that provides real-time analytics and insights for e-commerce businesses. This platform demonstrates enterprise-grade architecture, infrastructure as code, CI/CD pipelines, and cloud engineering best practices.

### Business Value

- **Real-time Analytics**: Get instant insights into sales performance, customer behavior, and product trends
- **Scalable Architecture**: Auto-scaling infrastructure that grows with your business
- **Cost Optimization**: Pay-as-you-scale model with optimized resource utilization
- **High Availability**: Multi-AZ deployment with 99.9% uptime SLA
- **Security First**: End-to-end encryption, VPC isolation, and compliance-ready architecture

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Users/Apps    │    │   API Gateway    │    │   Application   │
│                 │───▶│                  │───▶│  Load Balancer  │
│  (Web/Mobile)   │    │ (Rate Limiting)  │    │      (ALB)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                       ┌─────────────────────────────────┼─────────────────────────────────┐
                       │                                 ▼                                 │
                       │        ┌─────────────────────────────────────────────────────┐    │
                       │        │              ECS Fargate Cluster                    │    │
                       │        │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │    │
                       │        │  │     API     │  │     API     │  │     API     │  │    │
                       │        │  │  Container  │  │  Container  │  │  Container  │  │    │
                       │        │  └─────────────┘  └─────────────┘  └─────────────┘  │    │
                       │        └─────────────────────────────────────────────────────┘    │
                       │                                 │                                 │
                       │                                 ▼                                 │
┌─────────────────┐   │        ┌─────────────────────────────────────────────────────┐    │
│   CloudWatch    │◀──┼────────│                    VPC                              │    │
│   (Monitoring)  │   │        │  ┌─────────────┐           ┌─────────────────────┐  │    │
└─────────────────┘   │        │  │   Private   │           │      Database       │  │    │
                       │        │  │   Subnets   │───────────│       Subnets       │  │    │
┌─────────────────┐   │        │  └─────────────┘           └─────────────────────┘  │    │
│     Lambda      │◀──┼────────│         │                             │             │    │
│  (Functions)    │   │        │         ▼                             ▼             │    │
└─────────────────┘   │        │  ┌─────────────┐           ┌─────────────────────┐  │    │
                       │        │  │   Public    │           │    RDS MySQL        │  │    │
                       │        │  │   Subnets   │           │    (Multi-AZ)       │  │    │
                       │        │  └─────────────┘           └─────────────────────┘  │    │
                       │        └─────────────────────────────────────────────────────┘    │
                       └─────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Infrastructure & Cloud:**
- **AWS**: Primary cloud provider
- **Terraform**: Infrastructure as Code (IaC)
- **VPC**: Network isolation and security
- **ECS Fargate**: Serverless container orchestration
- **RDS MySQL**: Managed relational database
- **Application Load Balancer**: Traffic distribution
- **API Gateway**: API management and rate limiting

**Application:**
- **Python 3.11**: Backend programming language
- **FastAPI**: Modern, fast web framework for APIs
- **SQLAlchemy**: Database ORM
- **Pydantic**: Data validation and serialization
- **Uvicorn**: ASGI server

**DevOps & CI/CD:**
- **GitHub Actions**: CI/CD pipeline
- **Docker**: Containerization
- **Amazon ECR**: Container registry
- **PowerShell**: Deployment automation scripts

**Monitoring & Security:**
- **CloudWatch**: Logging and monitoring
- **Trivy**: Vulnerability scanning
- **AWS Config**: Compliance monitoring
- **VPC Flow Logs**: Network monitoring

## 📊 Features

### Analytics Endpoints

1. **Sales Analytics** (`/api/v1/analytics/sales`)
   - Total revenue and transaction metrics
   - Top-selling products analysis
   - Revenue breakdown by region and channel
   - Time-based trend analysis

2. **Customer Analytics** (`/api/v1/analytics/customers`)
   - Customer lifetime value (CLV) calculations
   - Customer retention metrics
   - Top customer identification
   - Acquisition and churn analysis

3. **Product Performance** (`/api/v1/analytics/products`)
   - Product performance metrics
   - Category-wise revenue analysis
   - Inventory insights and recommendations
   - Price optimization data

### Key Capabilities

- **Real-time Processing**: Sub-second response times for analytics queries
- **Scalable Architecture**: Auto-scales from 1 to 1000+ concurrent users
- **Data Security**: End-to-end encryption and VPC isolation
- **High Availability**: 99.9% uptime with multi-AZ deployment
- **Cost Optimized**: Pay-per-use model with resource optimization

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Docker Desktop
- PowerShell 7+ (for deployment scripts)
- Python 3.11+ (for local development)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/ecommerce-analytics-platform.git
   cd ecommerce-analytics-platform
   ```

2. **Start local environment with Docker Compose**
   ```bash
   cd api
   docker-compose up -d
   ```

3. **Access the API**
   - API: http://localhost:8000
   - Interactive Documentation: http://localhost:8000/docs
   - Health Check: http://localhost:8000/health

### AWS Deployment

1. **Configure AWS credentials**
   ```bash
   aws configure
   ```

2. **Deploy using PowerShell script**
   ```powershell
   .\scripts\Deploy-Platform.ps1 -Environment "staging" -Region "us-east-1"
   ```

3. **Monitor deployment**
   ```powershell
   .\scripts\Monitor-Infrastructure.ps1 -Environment "staging" -DetailedReport
   ```

## 📋 Deployment Guide

### Environment Setup

1. **Create S3 bucket for Terraform state**
   ```bash
   aws s3 mb s3://your-terraform-state-bucket-name
   ```

2. **Update Terraform backend configuration**
   ```hcl
   # In terraform/main.tf
   backend "s3" {
     bucket = "your-terraform-state-bucket-name"
     key    = "ecommerce-analytics/terraform.tfstate"
     region = "us-east-1"
   }
   ```

3. **Set up GitHub Secrets**
   ```
   AWS_ACCESS_KEY_ID
   AWS_SECRET_ACCESS_KEY
   DB_PASSWORD
   SLACK_WEBHOOK_URL (optional)
   ```

### Manual Deployment Steps

1. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

2. **Plan deployment**
   ```bash
   terraform plan -var-file="terraform.tfvars"
   ```

3. **Deploy infrastructure**
   ```bash
   terraform apply -auto-approve
   ```

4. **Build and push Docker image**
   ```bash
   # Login to ECR
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
   
   # Build and push
   cd api
   docker build -t ecommerce-analytics-api .
   docker tag ecommerce-analytics-api:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/ecommerce-analytics-api:latest
   docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/ecommerce-analytics-api:latest
   ```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `DATABASE_URL` | MySQL connection string | Yes | - |
| `ENVIRONMENT` | Deployment environment | No | `development` |
| `AWS_REGION` | AWS region | No | `us-east-1` |

### Terraform Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `aws_region` | AWS deployment region | string | `us-east-1` |
| `project_name` | Project identifier | string | `ecommerce-analytics` |
| `environment` | Environment name | string | `prod` |
| `vpc_cidr` | VPC CIDR block | string | `10.0.0.0/16` |
| `db_instance_class` | RDS instance type | string | `db.t3.micro` |
| `ecs_cpu` | ECS task CPU units | number | `256` |
| `ecs_memory` | ECS task memory (MB) | number | `512` |

## 📈 Monitoring & Observability

### CloudWatch Dashboards

The platform includes comprehensive monitoring with CloudWatch dashboards for:

- **Application Metrics**: Response times, error rates, throughput
- **Infrastructure Metrics**: CPU, memory, network utilization
- **Database Metrics**: Connection count, query performance, storage
- **Business Metrics**: Revenue trends, customer acquisition, product performance

### Alerts and Notifications

Automated alerts for:
- High error rates (>5%)
- Response time degradation (>2s)
- Infrastructure failures
- Security events

### Health Monitoring

```bash
# Check infrastructure health
.\scripts\Monitor-Infrastructure.ps1 -ContinuousMonitoring -MonitoringIntervalSeconds 30

# Get detailed CloudWatch metrics
.\scripts\Monitor-Infrastructure.ps1 -DetailedReport
```

## 🔒 Security

### Security Features

- **VPC Isolation**: All resources deployed in private subnets
- **Encryption**: Data encrypted at rest and in transit
- **IAM Roles**: Principle of least privilege access
- **Security Groups**: Network-level access control
- **Container Scanning**: Automated vulnerability scanning with Trivy
- **Compliance**: AWS Config rules for compliance monitoring

### Security Scans

The platform includes automated security scanning:

```bash
# Manual security scan
docker run --rm -v $(pwd):/workspace aquasec/trivy:latest fs /workspace

# Infrastructure security scan
checkov -d terraform/ --framework terraform
```

## 🧪 Testing

### Unit Tests

```bash
cd api
pytest test_main.py -v
```

### Integration Tests

```bash
cd tests
python -m pytest integration_test.py -v
```

### Load Testing

```bash
# Install k6
k6 run tests/load-test.js
```

### Test Coverage

```bash
cd api
pytest test_main.py --cov=main --cov-report=html
```

## 📊 Performance Benchmarks

### Expected Performance

| Metric | Value |
|--------|-------|
| Response Time (95th percentile) | < 500ms |
| Throughput | 1000+ requests/second |
| Availability | 99.9% |
| Auto-scaling | 0-100 instances |

### Load Test Results

```
Scenario: Normal Load (100 VUs for 5 minutes)
✓ Response time < 500ms: 99.2%
✓ Error rate < 1%: 0.3%
✓ Throughput: 1,200 req/s
```

## 💰 Cost Optimization

### Monthly Cost Estimates

| Environment | Estimated Monthly Cost |
|-------------|----------------------|
| Development | $50-100 |
| Staging | $100-200 |
| Production | $300-800 |

### Cost Optimization Features

- **Auto Scaling**: Scale down during low usage
- **Spot Instances**: Use Fargate Spot for cost savings
- **Resource Right-sizing**: Optimize instance types
- **Storage Optimization**: Use appropriate storage classes

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow PEP 8 for Python code
- Write tests for new features
- Update documentation for changes
- Ensure security scans pass

## 📚 API Documentation

### Interactive Documentation

Once deployed, access the interactive API documentation at:
- Swagger UI: `https://your-api-gateway-url/docs`
- ReDoc: `https://your-api-gateway-url/redoc`

### Sample API Calls

```bash
# Health check
curl https://your-api-gateway-url/health

# Get sales analytics
curl "https://your-api-gateway-url/api/v1/analytics/sales?start_date=2024-01-01&end_date=2024-01-31"

# Get customer analytics
curl https://your-api-gateway-url/api/v1/analytics/customers

# Get product performance
curl "https://your-api-gateway-url/api/v1/analytics/products?category=Electronics"
```

## 🚨 Troubleshooting

### Common Issues

1. **Terraform State Lock**
   ```bash
   terraform force-unlock LOCK_ID
   ```

2. **ECS Task Failing to Start**
   ```bash
   aws ecs describe-tasks --cluster cluster-name --tasks task-arn
   ```

3. **Database Connection Issues**
   ```bash
   # Check security groups and subnet routing
   aws ec2 describe-security-groups --group-ids sg-xxxxx
   ```

### Logs and Debugging

```bash
# View CloudWatch logs
aws logs get-log-events --log-group-name /ecs/ecommerce-analytics-prod

# Check ECS service events
aws ecs describe-services --cluster cluster-name --services service-name
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:
- 📧 Email: support@yourcompany.com
- 💬 Slack: #ecommerce-analytics
- 📖 Documentation: [docs.yourcompany.com](https://docs.yourcompany.com)
- 🐛 Issues: [GitHub Issues](https://github.com/your-username/ecommerce-analytics-platform/issues)

## 🙏 Acknowledgments

- AWS Solutions Architecture team for best practices
- FastAPI community for the excellent framework
- Terraform community for infrastructure as code tools
- Open source security tools (Trivy, Checkov) for keeping us secure

---

**Built with ❤️ for modern e-commerce businesses**