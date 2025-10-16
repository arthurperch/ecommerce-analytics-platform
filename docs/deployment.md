# Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the E-commerce Analytics Platform to AWS. The deployment process includes infrastructure provisioning, application deployment, and validation.

## Prerequisites

### Required Tools

1. **AWS CLI** (v2.0+)
   ```bash
   # Install AWS CLI
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Verify installation
   aws --version
   ```

2. **Terraform** (v1.5.0+)
   ```bash
   # Download and install Terraform
   wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
   unzip terraform_1.5.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Verify installation
   terraform version
   ```

3. **Docker** (v20.0+)
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sh get-docker.sh
   
   # Start Docker service
   sudo systemctl start docker
   sudo systemctl enable docker
   
   # Verify installation
   docker --version
   ```

4. **PowerShell** (v7.0+) - For Windows users
   ```powershell
   # Install PowerShell 7
   winget install Microsoft.PowerShell
   
   # Verify installation
   pwsh --version
   ```

### AWS Account Setup

1. **Create AWS Account** (if not already done)
   - Sign up at https://aws.amazon.com/
   - Complete account verification

2. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter your AWS Access Key ID
   # Enter your AWS Secret Access Key  
   # Enter default region (e.g., us-east-1)
   # Enter default output format (json)
   ```

3. **Verify AWS Configuration**
   ```bash
   aws sts get-caller-identity
   ```

### Required AWS Permissions

Your AWS user/role needs the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "ecs:*",
                "rds:*",
                "elasticloadbalancing:*",
                "apigateway:*",
                "lambda:*",
                "iam:*",
                "logs:*",
                "cloudwatch:*",
                "ecr:*",
                "s3:*",
                "kms:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## Pre-Deployment Setup

### 1. Clone Repository

```bash
git clone https://github.com/your-username/ecommerce-analytics-platform.git
cd ecommerce-analytics-platform
```

### 2. Create S3 Bucket for Terraform State

```bash
# Create bucket for Terraform state
aws s3 mb s3://your-unique-terraform-state-bucket-name

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket your-unique-terraform-state-bucket-name \
    --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
    --bucket your-unique-terraform-state-bucket-name \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
```

### 3. Update Terraform Backend Configuration

Edit `terraform/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-unique-terraform-state-bucket-name"
    key    = "ecommerce-analytics/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### 4. Create ECR Repository

```bash
aws ecr create-repository \
    --repository-name ecommerce-analytics-api \
    --region us-east-1
```

## Deployment Methods

### Method 1: Automated Deployment (Recommended)

#### Using PowerShell Script (Windows)

```powershell
# Deploy to staging
.\scripts\Deploy-Platform.ps1 -Environment "staging" -Region "us-east-1"

# Deploy to production
.\scripts\Deploy-Platform.ps1 -Environment "prod" -Region "us-east-1"

# Monitor deployment
.\scripts\Monitor-Infrastructure.ps1 -Environment "staging" -DetailedReport
```

#### Using Bash Script (Linux/macOS)

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy to staging
./scripts/deploy-platform.sh staging us-east-1

# Deploy to production  
./scripts/deploy-platform.sh prod us-east-1
```

### Method 2: Manual Deployment

#### Step 1: Build and Push Docker Image

```bash
# Navigate to API directory
cd api

# Build Docker image
docker build -t ecommerce-analytics-api:latest .

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Tag image for ECR
docker tag ecommerce-analytics-api:latest \
    ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecommerce-analytics-api:latest

# Push image to ECR
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecommerce-analytics-api:latest
```

#### Step 2: Deploy Infrastructure with Terraform

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars file
cat > terraform.tfvars << EOF
aws_region = "us-east-1"
project_name = "ecommerce-analytics"
environment = "staging"
container_image = "${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/ecommerce-analytics-api:latest"
db_password = "$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
EOF

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply deployment
terraform apply -auto-approve -var-file="terraform.tfvars"

# Get outputs
terraform output
```

## Environment-Specific Configurations

### Development Environment

```hcl
# terraform/environments/dev.tfvars
aws_region = "us-east-1"
environment = "dev"
vpc_cidr = "10.1.0.0/16"
db_instance_class = "db.t3.micro"
ecs_cpu = 256
ecs_memory = 512
ecs_desired_count = 1
```

### Staging Environment

```hcl
# terraform/environments/staging.tfvars
aws_region = "us-east-1"
environment = "staging"
vpc_cidr = "10.2.0.0/16"
db_instance_class = "db.t3.small"
ecs_cpu = 512
ecs_memory = 1024
ecs_desired_count = 2
```

### Production Environment

```hcl
# terraform/environments/prod.tfvars
aws_region = "us-east-1"
environment = "prod"
vpc_cidr = "10.0.0.0/16"
db_instance_class = "db.t3.medium"
ecs_cpu = 1024
ecs_memory = 2048
ecs_desired_count = 3
```

## Post-Deployment Validation

### 1. Infrastructure Health Check

```bash
# Check ECS cluster status
aws ecs describe-clusters --clusters ecommerce-analytics-staging-cluster

# Check ECS service status
aws ecs describe-services \
    --cluster ecommerce-analytics-staging-cluster \
    --services ecommerce-analytics-staging-api-service

# Check RDS instance status
aws rds describe-db-instances \
    --db-instance-identifier ecommerce-analytics-staging-db

# Check load balancer status
aws elbv2 describe-load-balancers \
    --names ecommerce-analytics-staging-alb
```

### 2. Application Health Check

```bash
# Get API Gateway URL from Terraform output
API_URL=$(cd terraform && terraform output -raw api_gateway_stage_url)

# Test health endpoint
curl -f "$API_URL/health"

# Test main endpoints
curl "$API_URL/"
curl "$API_URL/api/v1/analytics/sales"
curl "$API_URL/api/v1/analytics/customers"
curl "$API_URL/api/v1/analytics/products"
```

### 3. Performance Validation

```bash
# Run load test (requires k6)
k6 run tests/load-test.js

# Monitor CloudWatch metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ServiceName,Value=ecommerce-analytics-staging-api-service \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average
```

## Troubleshooting

### Common Issues

#### 1. Terraform State Lock

**Issue**: Terraform state is locked
```
Error: Error locking state: Error acquiring the state lock
```

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID

# Or wait for the lock to expire (usually 10-15 minutes)
```

#### 2. ECS Task Launch Failures

**Issue**: ECS tasks fail to start

**Diagnosis**:
```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster ecommerce-analytics-staging-cluster \
    --service-name ecommerce-analytics-staging-api-service \
    --query 'taskArns[0]' --output text)

# Describe task to see failure reason
aws ecs describe-tasks \
    --cluster ecommerce-analytics-staging-cluster \
    --tasks $TASK_ARN
```

**Common Solutions**:
- Check security group configurations
- Verify container image exists in ECR
- Check IAM role permissions
- Review CloudWatch logs

#### 3. Database Connection Issues

**Issue**: Application cannot connect to database

**Diagnosis**:
```bash
# Check RDS instance status
aws rds describe-db-instances \
    --db-instance-identifier ecommerce-analytics-staging-db

# Check security group rules
aws ec2 describe-security-groups \
    --group-ids sg-xxxxxxxxx
```

**Solutions**:
- Verify security group rules allow port 3306
- Check database subnet group configuration
- Ensure database is in available state
- Verify database credentials

#### 4. Load Balancer Health Check Failures

**Issue**: Targets failing health checks

**Diagnosis**:
```bash
# Check target group health
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:...
```

**Solutions**:
- Verify health check path (/health)
- Check application is responding on correct port
- Review security group configurations
- Check application logs

### Logging and Debugging

#### View Application Logs

```bash
# Get log group name
LOG_GROUP="/ecs/ecommerce-analytics-staging"

# Get recent logs
aws logs tail $LOG_GROUP --follow

# Get logs from specific time
aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name $(aws logs describe-log-streams \
        --log-group-name $LOG_GROUP \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --query 'logStreams[0].logStreamName' \
        --output text) \
    --start-time $(date -d '1 hour ago' +%s)000
```

#### Monitor Infrastructure

```bash
# Use monitoring script
.\scripts\Monitor-Infrastructure.ps1 \
    -Environment "staging" \
    -ContinuousMonitoring \
    -MonitoringIntervalSeconds 30
```

## Cleanup and Destruction

### Destroy Infrastructure

```bash
# Using PowerShell script
.\scripts\Deploy-Platform.ps1 \
    -Environment "staging" \
    -DestroyInfrastructure

# Using Terraform directly
cd terraform
terraform destroy -auto-approve -var-file="terraform.tfvars"
```

### Clean Up Resources

```bash
# Delete ECR repository
aws ecr delete-repository \
    --repository-name ecommerce-analytics-api \
    --force

# Delete S3 bucket (if no longer needed)
aws s3 rb s3://your-terraform-state-bucket-name --force
```

## Security Considerations

### 1. Secrets Management

- Store database passwords in AWS Secrets Manager
- Use IAM roles instead of access keys where possible
- Rotate credentials regularly
- Enable MFA for AWS console access

### 2. Network Security

- Review security group rules regularly
- Enable VPC Flow Logs
- Use WAF for additional protection
- Implement network monitoring

### 3. Compliance

- Enable CloudTrail for audit logging
- Use AWS Config for compliance monitoring
- Implement backup and disaster recovery
- Regular security assessments

## Cost Optimization

### 1. Right-Sizing

```bash
# Monitor resource utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 3600 \
    --statistics Average,Maximum
```

### 2. Scheduled Scaling

- Scale down non-production environments after hours
- Use Spot instances for development workloads
- Implement predictive scaling for known patterns

### 3. Cost Monitoring

- Set up billing alerts
- Use cost allocation tags
- Regular cost reviews and optimization

This deployment guide provides comprehensive instructions for deploying the E-commerce Analytics Platform. Follow the steps carefully and refer to the troubleshooting section if you encounter any issues.