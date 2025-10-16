# Infrastructure Monitoring and Health Check Script
# This script monitors the deployed infrastructure and provides health reports

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "ecommerce-analytics",
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedReport,
    
    [Parameter(Mandatory=$false)]
    [switch]$ContinuousMonitoring,
    
    [Parameter(Mandatory=$false)]
    [int]$MonitoringIntervalSeconds = 60
)

$ErrorActionPreference = "Stop"

# Color output functions
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
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-ColorOutput Cyan "[$timestamp] INFO: $Message"
}

function Write-Success($Message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-ColorOutput Green "[$timestamp] SUCCESS: $Message"
}

function Write-Warning($Message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-ColorOutput Yellow "[$timestamp] WARNING: $Message"
}

function Write-Error($Message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-ColorOutput Red "[$timestamp] ERROR: $Message"
}

# Function to get infrastructure status
function Get-InfrastructureStatus {
    Write-Info "Checking infrastructure status..."
    
    $status = @{
        VPC = @{}
        ECS = @{}
        RDS = @{}
        LoadBalancer = @{}
        API = @{}
        Overall = "Unknown"
    }
    
    try {
        # Get Terraform outputs
        Push-Location "$PSScriptRoot\..\terraform"
        $outputs = terraform output -json | ConvertFrom-Json
        Pop-Location
        
        # Check ECS Cluster
        $clusterName = $outputs.ecs_cluster_name.value
        $ecsCluster = aws ecs describe-clusters --clusters $clusterName --region $Region | ConvertFrom-Json
        
        if ($ecsCluster.clusters.Count -gt 0) {
            $cluster = $ecsCluster.clusters[0]
            $status.ECS = @{
                Name = $cluster.clusterName
                Status = $cluster.status
                ActiveServices = $cluster.activeServicesCount
                RunningTasks = $cluster.runningTasksCount
                PendingTasks = $cluster.pendingTasksCount
            }
        }
        
        # Check ECS Service
        $serviceName = $outputs.ecs_service_name.value
        $ecsService = aws ecs describe-services --cluster $clusterName --services $serviceName --region $Region | ConvertFrom-Json
        
        if ($ecsService.services.Count -gt 0) {
            $service = $ecsService.services[0]
            $status.ECS.ServiceStatus = $service.status
            $status.ECS.DesiredCount = $service.desiredCount
            $status.ECS.RunningCount = $service.runningCount
        }
        
        # Check RDS
        $rdsInstanceId = $outputs.rds_endpoint.value -replace '\..*', ''
        $rdsInstance = aws rds describe-db-instances --db-instance-identifier $rdsInstanceId --region $Region | ConvertFrom-Json
        
        if ($rdsInstance.DBInstances.Count -gt 0) {
            $db = $rdsInstance.DBInstances[0]
            $status.RDS = @{
                InstanceId = $db.DBInstanceIdentifier
                Status = $db.DBInstanceStatus
                Engine = $db.Engine
                EngineVersion = $db.EngineVersion
                MultiAZ = $db.MultiAZ
                StorageEncrypted = $db.StorageEncrypted
            }
        }
        
        # Check Load Balancer
        $lbDns = $outputs.load_balancer_dns_name.value
        $loadBalancers = aws elbv2 describe-load-balancers --region $Region | ConvertFrom-Json
        $targetLB = $loadBalancers.LoadBalancers | Where-Object { $_.DNSName -eq $lbDns }
        
        if ($targetLB) {
            $status.LoadBalancer = @{
                Name = $targetLB.LoadBalancerName
                State = $targetLB.State.Code
                Type = $targetLB.Type
                Scheme = $targetLB.Scheme
                DNSName = $targetLB.DNSName
            }
        }
        
        # Check API Health
        $apiUrl = $outputs.api_gateway_stage_url.value
        if ($apiUrl) {
            try {
                $healthResponse = Invoke-RestMethod -Uri "$apiUrl/health" -Method Get -TimeoutSec 10
                $status.API = @{
                    URL = $apiUrl
                    Status = $healthResponse.status
                    DatabaseStatus = $healthResponse.database_status
                    Environment = $healthResponse.environment
                    LastChecked = $healthResponse.timestamp
                }
            } catch {
                $status.API = @{
                    URL = $apiUrl
                    Status = "Unhealthy"
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Determine overall status
        $healthyComponents = 0
        $totalComponents = 0
        
        if ($status.ECS.Status -eq "ACTIVE" -and $status.ECS.RunningCount -gt 0) { $healthyComponents++ }
        $totalComponents++
        
        if ($status.RDS.Status -eq "available") { $healthyComponents++ }
        $totalComponents++
        
        if ($status.LoadBalancer.State -eq "active") { $healthyComponents++ }
        $totalComponents++
        
        if ($status.API.Status -eq "healthy") { $healthyComponents++ }
        $totalComponents++
        
        if ($healthyComponents -eq $totalComponents) {
            $status.Overall = "Healthy"
        } elseif ($healthyComponents -gt 0) {
            $status.Overall = "Degraded"
        } else {
            $status.Overall = "Unhealthy"
        }
        
    } catch {
        Write-Error "Failed to get infrastructure status: $_"
        $status.Overall = "Error"
    }
    
    return $status
}

# Function to display status report
function Show-StatusReport {
    param($Status)
    
    Write-Info "=== Infrastructure Health Report ==="
    Write-Info "Environment: $Environment | Region: $Region"
    
    # Overall status
    switch ($Status.Overall) {
        "Healthy" { Write-Success "Overall Status: $($Status.Overall)" }
        "Degraded" { Write-Warning "Overall Status: $($Status.Overall)" }
        default { Write-Error "Overall Status: $($Status.Overall)" }
    }
    
    Write-Host ""
    
    # ECS Status
    if ($Status.ECS.Name) {
        Write-Info "ECS Cluster: $($Status.ECS.Name)"
        Write-Host "  Status: $($Status.ECS.Status)"
        Write-Host "  Active Services: $($Status.ECS.ActiveServices)"
        Write-Host "  Running Tasks: $($Status.ECS.RunningTasks)"
        if ($Status.ECS.ServiceStatus) {
            Write-Host "  Service Status: $($Status.ECS.ServiceStatus)"
            Write-Host "  Desired/Running Count: $($Status.ECS.DesiredCount)/$($Status.ECS.RunningCount)"
        }
    }
    
    Write-Host ""
    
    # RDS Status
    if ($Status.RDS.InstanceId) {
        Write-Info "RDS Database: $($Status.RDS.InstanceId)"
        Write-Host "  Status: $($Status.RDS.Status)"
        Write-Host "  Engine: $($Status.RDS.Engine) $($Status.RDS.EngineVersion)"
        Write-Host "  Multi-AZ: $($Status.RDS.MultiAZ)"
        Write-Host "  Encrypted: $($Status.RDS.StorageEncrypted)"
    }
    
    Write-Host ""
    
    # Load Balancer Status
    if ($Status.LoadBalancer.Name) {
        Write-Info "Load Balancer: $($Status.LoadBalancer.Name)"
        Write-Host "  State: $($Status.LoadBalancer.State)"
        Write-Host "  Type: $($Status.LoadBalancer.Type)"
        Write-Host "  DNS: $($Status.LoadBalancer.DNSName)"
    }
    
    Write-Host ""
    
    # API Status
    if ($Status.API.URL) {
        Write-Info "API Service: $($Status.API.URL)"
        if ($Status.API.Status -eq "healthy") {
            Write-Success "  Status: $($Status.API.Status)"
        } else {
            Write-Error "  Status: $($Status.API.Status)"
        }
        
        if ($Status.API.DatabaseStatus) {
            Write-Host "  Database: $($Status.API.DatabaseStatus)"
        }
        if ($Status.API.Error) {
            Write-Host "  Error: $($Status.API.Error)"
        }
    }
    
    Write-Host ""
}

# Function to get CloudWatch metrics
function Get-CloudWatchMetrics {
    Write-Info "Fetching CloudWatch metrics..."
    
    try {
        $endTime = Get-Date
        $startTime = $endTime.AddHours(-1)
        
        # ECS CPU and Memory utilization
        $ecsMetrics = aws cloudwatch get-metric-statistics `
            --namespace "AWS/ECS" `
            --metric-name "CPUUtilization" `
            --dimensions Name=ServiceName,Value="$ProjectName-$Environment-api-service" Name=ClusterName,Value="$ProjectName-$Environment-cluster" `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --period 300 `
            --statistics Average `
            --region $Region | ConvertFrom-Json
        
        # RDS metrics
        $rdsMetrics = aws cloudwatch get-metric-statistics `
            --namespace "AWS/RDS" `
            --metric-name "CPUUtilization" `
            --dimensions Name=DBInstanceIdentifier,Value="$ProjectName-$Environment-db" `
            --start-time $startTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --period 300 `
            --statistics Average `
            --region $Region | ConvertFrom-Json
        
        if ($ecsMetrics.Datapoints.Count -gt 0) {
            $avgCPU = ($ecsMetrics.Datapoints | Measure-Object -Property Average -Average).Average
            Write-Info "ECS Average CPU Utilization (last hour): $([math]::Round($avgCPU, 2))%"
        }
        
        if ($rdsMetrics.Datapoints.Count -gt 0) {
            $avgRDSCPU = ($rdsMetrics.Datapoints | Measure-Object -Property Average -Average).Average
            Write-Info "RDS Average CPU Utilization (last hour): $([math]::Round($avgRDSCPU, 2))%"
        }
        
    } catch {
        Write-Warning "Could not retrieve CloudWatch metrics: $_"
    }
}

# Main monitoring loop
function Start-Monitoring {
    do {
        Clear-Host
        Write-Info "E-commerce Analytics Platform - Infrastructure Monitor"
        Write-Info "Press Ctrl+C to stop monitoring"
        Write-Host ""
        
        $status = Get-InfrastructureStatus
        Show-StatusReport -Status $status
        
        if ($DetailedReport) {
            Get-CloudWatchMetrics
        }
        
        if ($ContinuousMonitoring) {
            Write-Info "Next check in $MonitoringIntervalSeconds seconds..."
            Start-Sleep -Seconds $MonitoringIntervalSeconds
        }
        
    } while ($ContinuousMonitoring)
}

# Main execution
try {
    if ($ContinuousMonitoring) {
        Write-Info "Starting continuous monitoring (interval: $MonitoringIntervalSeconds seconds)"
        Start-Monitoring
    } else {
        $status = Get-InfrastructureStatus
        Show-StatusReport -Status $status
        
        if ($DetailedReport) {
            Get-CloudWatchMetrics
        }
    }
    
} catch {
    Write-Error "Monitoring failed: $_"
    exit 1
}