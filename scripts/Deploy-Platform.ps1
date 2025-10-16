# E-commerce Analytics Platform Deployment Script
# This script deploys the infrastructure and application to AWS

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "ecommerce-analytics",
    
    [Parameter(Mandatory=$false)]
    [switch]$DestroyInfrastructure,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color functions for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    } else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Info($Message) {
    Write-ColorOutput Cyan "INFO: $Message"
}

function Write-Success($Message) {
    Write-ColorOutput Green "SUCCESS: $Message"
}

function Write-Warning($Message) {
    Write-ColorOutput Yellow "WARNING: $Message"
}

function Write-Error($Message) {
    Write-ColorOutput Red "ERROR: $Message"
}

# Function to check if required tools are installed
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $tools = @("aws", "terraform", "docker")
    $missingTools = @()
    
    foreach ($tool in $tools) {
        try {
            $null = Get-Command $tool -ErrorAction Stop
            Write-Success "$tool is installed"
        } catch {
            $missingTools += $tool
            Write-Error "$tool is not installed or not in PATH"
        }
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools: $($missingTools -join ', ')"
        Write-Info "Please install the missing tools and ensure they are in your PATH"
        exit 1
    }
    
    # Check AWS credentials
    try {
        $awsIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-Success "AWS credentials configured for account: $($awsIdentity.Account)"
    } catch {
        Write-Error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    }
}

# Function to run tests
function Invoke-Tests {
    if ($SkipTests) {
        Write-Warning "Skipping tests as requested"
        return
    }
    
    Write-Info "Running application tests..."
    
    try {
        Push-Location "$PSScriptRoot\..\api"
        
        # Check if virtual environment exists, create if not
        if (-not (Test-Path "venv")) {
            Write-Info "Creating Python virtual environment..."
            python -m venv venv
        }
        
        # Activate virtual environment
        if ($IsWindows -or $PSVersionTable.PSEdition -eq "Desktop") {
            & ".\venv\Scripts\Activate.ps1"
        } else {
            & ".\venv\bin\Activate.ps1"
        }
        
        # Install dependencies
        Write-Info "Installing Python dependencies..."
        pip install -r requirements.txt
        
        # Run tests
        Write-Info "Running pytest..."
        pytest test_main.py -v
        
        Write-Success "All tests passed!"
        
    } catch {
        Write-Error "Tests failed: $_"
        exit 1
    } finally {
        Pop-Location
    }
}

# Function to build and push Docker image
function Build-DockerImage {
    param($ImageTag)
    
    Write-Info "Building Docker image..."
    
    try {
        Push-Location "$PSScriptRoot\..\api"
        
        # Build Docker image
        docker build -t "${ProjectName}-api:$ImageTag" .
        
        # Get AWS account ID and region for ECR
        $awsAccountId = (aws sts get-caller-identity --query Account --output text)
        $ecrUri = "${awsAccountId}.dkr.ecr.${Region}.amazonaws.com/${ProjectName}-api"
        
        # Tag image for ECR
        docker tag "${ProjectName}-api:$ImageTag" "${ecrUri}:$ImageTag"
        docker tag "${ProjectName}-api:$ImageTag" "${ecrUri}:latest"
        
        # Login to ECR
        Write-Info "Logging in to Amazon ECR..."
        aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin "${awsAccountId}.dkr.ecr.${Region}.amazonaws.com"
        
        # Create ECR repository if it doesn't exist
        try {
            aws ecr describe-repositories --repository-names "${ProjectName}-api" --region $Region | Out-Null
        } catch {
            Write-Info "Creating ECR repository..."
            aws ecr create-repository --repository-name "${ProjectName}-api" --region $Region | Out-Null
        }
        
        # Push image to ECR
        Write-Info "Pushing image to ECR..."
        docker push "${ecrUri}:$ImageTag"
        docker push "${ecrUri}:latest"
        
        Write-Success "Docker image built and pushed successfully"
        return $ecrUri
        
    } catch {
        Write-Error "Failed to build or push Docker image: $_"
        exit 1
    } finally {
        Pop-Location
    }
}

# Function to deploy infrastructure with Terraform
function Deploy-Infrastructure {
    param($ImageUri)
    
    Write-Info "Deploying infrastructure with Terraform..."
    
    try {
        Push-Location "$PSScriptRoot\..\terraform"
        
        # Initialize Terraform
        Write-Info "Initializing Terraform..."
        terraform init
        
        # Create terraform.tfvars file
        $tfvarsContent = @"
aws_region = "$Region"
project_name = "$ProjectName"
environment = "$Environment"
container_image = "$ImageUri:latest"
db_password = "$(New-Guid | Select-Object -ExpandProperty Guid | ForEach-Object { $_.Replace('-', '').Substring(0, 16) })"
"@
        $tfvarsContent | Out-File -FilePath "terraform.tfvars" -Encoding UTF8
        
        if ($DestroyInfrastructure) {
            # Destroy infrastructure
            Write-Warning "Destroying infrastructure..."
            terraform destroy -auto-approve -var-file="terraform.tfvars"
            Write-Success "Infrastructure destroyed successfully"
        } else {
            # Plan deployment
            Write-Info "Planning Terraform deployment..."
            terraform plan -var-file="terraform.tfvars"
            
            # Apply deployment
            Write-Info "Applying Terraform configuration..."
            terraform apply -auto-approve -var-file="terraform.tfvars"
            
            # Get outputs
            $outputs = terraform output -json | ConvertFrom-Json
            
            Write-Success "Infrastructure deployed successfully!"
            Write-Info "API Gateway URL: $($outputs.api_gateway_stage_url.value)"
            Write-Info "Load Balancer DNS: $($outputs.load_balancer_dns_name.value)"
        }
        
    } catch {
        Write-Error "Terraform deployment failed: $_"
        exit 1
    } finally {
        Pop-Location
    }
}

# Function to wait for service to be healthy
function Wait-ForServiceHealth {
    param($HealthUrl)
    
    Write-Info "Waiting for service to become healthy..."
    $maxAttempts = 30
    $attempt = 0
    
    do {
        $attempt++
        try {
            $response = Invoke-RestMethod -Uri $HealthUrl -Method Get -TimeoutSec 10
            if ($response.status -eq "healthy") {
                Write-Success "Service is healthy!"
                return
            }
        } catch {
            Write-Info "Attempt $attempt/$maxAttempts - Service not ready yet..."
        }
        
        Start-Sleep -Seconds 10
    } while ($attempt -lt $maxAttempts)
    
    Write-Warning "Service health check timed out after $maxAttempts attempts"
}

# Function to run deployment validation
function Test-Deployment {
    Write-Info "Running deployment validation..."
    
    try {
        Push-Location "$PSScriptRoot\..\terraform"
        
        # Get API Gateway URL from Terraform outputs
        $outputs = terraform output -json | ConvertFrom-Json
        $apiUrl = $outputs.api_gateway_stage_url.value
        
        if ($apiUrl) {
            $healthUrl = "$apiUrl/health"
            Wait-ForServiceHealth -HealthUrl $healthUrl
            
            # Test main endpoints
            Write-Info "Testing API endpoints..."
            
            $endpoints = @(
                "/",
                "/api/v1/analytics/sales",
                "/api/v1/analytics/customers",
                "/api/v1/analytics/products"
            )
            
            foreach ($endpoint in $endpoints) {
                try {
                    $response = Invoke-RestMethod -Uri "$apiUrl$endpoint" -Method Get -TimeoutSec 15
                    Write-Success "✓ $endpoint endpoint is working"
                } catch {
                    Write-Warning "✗ $endpoint endpoint failed: $_"
                }
            }
        }
        
    } catch {
        Write-Error "Deployment validation failed: $_"
    } finally {
        Pop-Location
    }
}

# Main execution
try {
    Write-Info "Starting deployment for environment: $Environment"
    Write-Info "Region: $Region"
    Write-Info "Project: $ProjectName"
    
    # Check prerequisites
    Test-Prerequisites
    
    if (-not $DestroyInfrastructure) {
        # Run tests
        Invoke-Tests
        
        # Build and push Docker image
        $imageTag = Get-Date -Format "yyyyMMdd-HHmmss"
        $imageUri = Build-DockerImage -ImageTag $imageTag
        
        # Deploy infrastructure
        Deploy-Infrastructure -ImageUri $imageUri
        
        # Validate deployment
        Test-Deployment
        
        Write-Success "Deployment completed successfully!"
        Write-Info "You can access the API documentation at: [API_GATEWAY_URL]/docs"
        
    } else {
        # Destroy infrastructure
        Deploy-Infrastructure
    }
    
} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}