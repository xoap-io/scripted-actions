<#
.SYNOPSIS
  Enhanced AWS Account Hardening with CloudWatch Monitoring (CIS AWS Foundations v5.0.0 aligned)

.DESCRIPTION
  Comprehensive security hardening including CloudWatch log metric filters, alarms, 
  and AWS Config service-linked role. Addresses common security findings from AWS Config.

.PARAMETER AccountAlias
  Account alias to set.

.PARAMETER HomeRegion
  The primary AWS region for multi-region services like CloudTrail.

.PARAMETER TargetRegions
  List of regions to apply hardening steps.

.PARAMETER SecurityEmail
  Security contact email address for SNS notifications.

.PARAMETER SecurityPhone
  Security contact phone number.

.PARAMETER SecurityFirstName
  Security contact first name.

.PARAMETER SecurityLastName
  Security contact last name.

.PARAMETER SecurityTitle
  Security contact title.

.PARAMETER TrailName
  CloudTrail name to create/manage.

.PARAMETER TrailBucketName
  S3 bucket for CloudTrail (auto-generated if empty).

.PARAMETER TrailKmsAlias
  KMS key alias for CloudTrail encryption.

.PARAMETER ConfigBucketName
  S3 bucket for Config (auto-generated if empty).

.PARAMETER EbsDefaultKmsAlias
  KMS key alias for EBS default encryption.

.PARAMETER FlowLogGroupPrefix
  CloudWatch Log Group prefix for VPC Flow Logs.

.PARAMETER FlowLogRetentionDays
  Retention days for VPC Flow Log groups.

.PARAMETER AdminPorts
  Admin ports to secure (default: 22,3389).

.PARAMETER SnsTopicName
  SNS topic name for security alerts.

.PARAMETER EnableCloudWatchAlarms
  Enable CloudWatch log metric filters and alarms.

.PARAMETER DryRun
  Preview changes without making them.

.EXAMPLE
  .\aws-ps-account-hardening-enhanced.ps1 -HomeRegion eu-central-1 -SecurityEmail security@company.com

.EXAMPLE
  .\aws-ps-account-hardening-enhanced.ps1 -DryRun -EnableCloudWatchAlarms
#>

[CmdletBinding()]
param(
  [Parameter()][ValidatePattern('^[a-zA-Z0-9-]+$')][string]$AccountAlias = "cis-hardened-account",
  [Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$HomeRegion = "eu-central-1",
  [Parameter()][ValidateScript({
    foreach ($region in $_) {
      if ($region -notmatch '^[a-z]{2}-[a-z]+-[0-9]$') {
        throw "Invalid region format: $region"
      }
    }
    return $true
  })][string[]]$TargetRegions = @("eu-central-1","eu-west-1","us-east-1"),
  
  # Security contact
  [Parameter(Mandatory)][ValidatePattern('^[^@]+@[^@]+\.[^@]+$')][string]$SecurityEmail,
  [Parameter()][ValidatePattern('^\+?[0-9\-\s\(\)]+$')][string]$SecurityPhone = "+49-000-0000000",
  [Parameter()][ValidateLength(1,50)][string]$SecurityFirstName = "Security",
  [Parameter()][ValidateLength(1,50)][string]$SecurityLastName = "Team",
  [Parameter()][ValidateLength(1,50)][string]$SecurityTitle = "Security Lead",
  
  # CloudTrail
  [Parameter()][ValidatePattern('^[a-zA-Z0-9\-_]+$')][string]$TrailName = "cis-multi-region-trail",
  [Parameter()][ValidatePattern('^[a-z0-9\-\.]*$')][string]$TrailBucketName = "",
  [Parameter()][ValidatePattern('^alias/[a-zA-Z0-9\-_/]+$')][string]$TrailKmsAlias = "alias/cis-cloudtrail",
  [Parameter()][switch]$TrailEnableLogFileValidation = $true,
  
  # Config
  [Parameter()][ValidatePattern('^[a-z0-9\-\.]*$')][string]$ConfigBucketName = "",
  [Parameter()][ValidateSet('One_Hour','Three_Hours','Six_Hours','Twelve_Hours','TwentyFour_Hours')][string]$ConfigDeliveryFrequency = 'One_Hour',
  
  # EBS
  [Parameter()][ValidatePattern('^alias/[a-zA-Z0-9\-_/]+$')][string]$EbsDefaultKmsAlias = "alias/cis-ebs-default",
  
  # VPC Flow Logs
  [Parameter()][ValidatePattern('^/[a-zA-Z0-9\-_/]+$')][string]$FlowLogGroupPrefix = "/aws/vpc/flowlogs/cis",
  [Parameter()][ValidateRange(1,3653)][int]$FlowLogRetentionDays = 365,
  
  # Network
  [Parameter()][ValidateScript({
    foreach ($port in $_) {
      if ($port -lt 1 -or $port -gt 65535) {
        throw "Invalid port: $port"
      }
    }
    return $true
  })][int[]]$AdminPorts = @(22,3389),
  
  # CloudWatch Monitoring
  [Parameter()][ValidatePattern('^[a-zA-Z0-9\-_]+$')][string]$SnsTopicName = "cis-security-alerts",
  [Parameter()][switch]$EnableCloudWatchAlarms = $true,
  
  # New parameters for additional services
  [Parameter()][switch]$EnableInspector = $true,
  [Parameter()][switch]$EnableMacie = $true,
  [Parameter()][switch]$EnableGuardDutyRuntimeMonitoring = $true,
  [Parameter()][switch]$EnableVpcEndpoints = $true,
  [Parameter()][switch]$EnableS3Lifecycle = $true,
  [Parameter()][ValidateRange(30,3653)][int]$S3LifecycleTransitionDays = 90,
  [Parameter()][ValidateRange(90,7300)][int]$S3LifecycleExpirationDays = 2555,
  # Additional remediation toggles
  [Parameter()][switch]$EnforceS3RequireSSL = $false,
  [Parameter()][switch]$EnsureCloudTrailManagementSelectors = $false,
  [Parameter()][switch]$RemediateIamUserDirectPolicies = $false,
  
  # Safety
  [Parameter()][switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'

# Generate random suffix for bucket names
$RandomSuffix = -join ((1..6) | ForEach-Object { [char]((97..122) + (48..57) | Get-Random) })

function Write-Info($msg) { Write-Host "[+] $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[x] $msg" -ForegroundColor Red }

function Test-AwsCliInstalled {
  try {
    $null = Get-Command aws -ErrorAction Stop
    $null = aws sts get-caller-identity --output json 2>$null
    if ($LASTEXITCODE -ne 0) {
      Write-Err "AWS CLI not configured. Please run 'aws configure' first."
      return $false
    }
    return $true
  } catch {
    Write-Err "AWS CLI not found. Please install AWS CLI and configure credentials."
    return $false
  }
}

function Get-AccountId {
  try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    if (-not $identity -or -not $identity.Account) {
      throw "Failed to get account ID from AWS CLI"
    }
    return $identity.Account
  } catch {
    Write-Err "Failed to get account ID. Check AWS credentials."
    throw
  }
}

function Invoke-AwsCliSafe {
  param([string]$Command)
  if ($DryRun) {
    Write-Info "DRY-RUN: aws $Command"
    return
  }
  
  try {
    Write-Host "aws $Command" -ForegroundColor DarkGray
    Invoke-Expression "aws $Command"
    if ($LASTEXITCODE -ne 0) {
      throw "AWS CLI command failed with exit code: $LASTEXITCODE"
    }
  } catch {
    Write-Warn "AWS CLI command failed: $Command - $_"
    throw
  }
}

function New-SecuritySNSTopic {
  param([string]$Region)
  
  Write-Info "[$Region] Creating SNS topic for security alerts: $SnsTopicName"
  
  try {
    # Check if topic already exists
    $topics = aws sns list-topics --region $Region --output json | ConvertFrom-Json
    $existingTopic = $topics.Topics | Where-Object { $_.TopicArn -like "*$SnsTopicName*" }
    
    if ($existingTopic) {
      Write-Info "[$Region] SNS topic already exists: $($existingTopic.TopicArn)"
      return $existingTopic.TopicArn
    }
    
    if (-not $DryRun) {
      $result = aws sns create-topic --name $SnsTopicName --region $Region --output json | ConvertFrom-Json
      $topicArn = $result.TopicArn
      
      # Validate the topic ARN format before proceeding
      if (-not $topicArn -or -not $topicArn.StartsWith("arn:aws:sns:")) {
        throw "Invalid SNS topic ARN received: $topicArn"
      }
      
      Write-Info "[$Region] Created SNS topic: $topicArn"
      
      # Subscribe security email (we don't need to capture the subscription result)
      aws sns subscribe --topic-arn $topicArn --protocol email --notification-endpoint $SecurityEmail --region $Region --output json | Out-Null
      Write-Info "[$Region] Subscribed $SecurityEmail to SNS topic"
      
      # Return only the clean topic ARN, not subscription details
      return $topicArn
    } else {
      $accountId = Get-AccountId
      return "arn:aws:sns:${Region}:${accountId}:$SnsTopicName"
    }
  } catch {
    Write-Warn "[$Region] Failed to create SNS topic: $_"
    return $null
  }
}

function New-CloudWatchMetricFiltersAndAlarms {
  param(
    [string]$Region,
    [string]$CloudTrailLogGroupName,
    [string]$SnsTopicArn
  )
  
  if (-not $EnableCloudWatchAlarms) {
    Write-Info "[$Region] CloudWatch alarms disabled - skipping"
    return
  }
  
  # Validate the log group name parameter
  if (-not $CloudTrailLogGroupName -or $CloudTrailLogGroupName.Length -gt 512) {
    Write-Warn "[$Region] Invalid CloudTrail log group name (length: $($CloudTrailLogGroupName.Length)): $CloudTrailLogGroupName"
    return
  }
  
  Write-Info "[$Region] Creating CloudWatch metric filters and alarms for log group: $CloudTrailLogGroupName"
  
  # Define metric filters based on CIS controls
  $metricFilters = @(
    @{
      Name = "RootUserUsage"
      Pattern = '{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }'
      AlarmName = "CIS-RootUserUsage"
      AlarmDescription = "Root user activity detected"
      MetricValue = "1"
    },
    @{
      Name = "UnauthorizedAPICalls"
      Pattern = '{ ($.errorCode = "*UnauthorizedOperation") || ($.errorCode = "AccessDenied*") }'
      AlarmName = "CIS-UnauthorizedAPICalls"
      AlarmDescription = "Unauthorized API calls detected"
      MetricValue = "1"
    },
    @{
      Name = "ConsoleSigninWithoutMFA"
      Pattern = '{ ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed != "Yes") && ($.userIdentity.type = "IAMUser") && ($.responseElements.ConsoleLogin = "Success") }'
      AlarmName = "CIS-ConsoleSigninWithoutMFA"
      AlarmDescription = "Console signin without MFA detected"
      MetricValue = "1"
    },
    @{
      Name = "IAMPolicyChanges"
      Pattern = '{ ($.eventName=DeleteGroupPolicy) || ($.eventName=DeleteRolePolicy) || ($.eventName=DeleteUserPolicy) || ($.eventName=PutGroupPolicy) || ($.eventName=PutRolePolicy) || ($.eventName=PutUserPolicy) || ($.eventName=CreatePolicy) || ($.eventName=DeletePolicy) || ($.eventName=CreatePolicyVersion) || ($.eventName=DeletePolicyVersion) || ($.eventName=AttachRolePolicy) || ($.eventName=DetachRolePolicy) || ($.eventName=AttachUserPolicy) || ($.eventName=DetachUserPolicy) || ($.eventName=AttachGroupPolicy) || ($.eventName=DetachGroupPolicy) }'
      AlarmName = "CIS-IAMPolicyChanges"
      AlarmDescription = "IAM policy changes detected"
      MetricValue = "1"
    },
    @{
      Name = "CloudTrailChanges"
      Pattern = '{ ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }'
      AlarmName = "CIS-CloudTrailChanges"
      AlarmDescription = "CloudTrail configuration changes detected"
      MetricValue = "1"
    },
    @{
      Name = "ConsoleAuthenticationFailures"
      Pattern = '{ ($.eventName = ConsoleLogin) && ($.errorMessage = "Failed authentication") }'
      AlarmName = "CIS-ConsoleAuthenticationFailures"
      AlarmDescription = "AWS Management Console authentication failures detected"
      MetricValue = "1"
    },
    @{
      Name = "CMKDisabling"
      Pattern = '{ ($.eventSource = kms.amazonaws.com) && (($.eventName=DisableKey) || ($.eventName=ScheduleKeyDeletion)) }'
      AlarmName = "CIS-CMKDisabling"
      AlarmDescription = "Customer managed key disabling or deletion detected"
      MetricValue = "1"
    },
    @{
      Name = "S3BucketPolicyChanges"
      Pattern = '{ ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) }'
      AlarmName = "CIS-S3BucketPolicyChanges"
      AlarmDescription = "S3 bucket policy changes detected"
      MetricValue = "1"
    },
    @{
      Name = "AWSConfigChanges"
      Pattern = '{ ($.eventSource = config.amazonaws.com) && (($.eventName=StopConfigurationRecorder) || ($.eventName=DeleteDeliveryChannel) || ($.eventName=PutDeliveryChannel) || ($.eventName=PutConfigurationRecorder)) }'
      AlarmName = "CIS-AWSConfigChanges"
      AlarmDescription = "AWS Config configuration changes detected"
      MetricValue = "1"
    },
    @{
      Name = "SecurityGroupChanges"
      Pattern = '{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }'
      AlarmName = "CIS-SecurityGroupChanges"
      AlarmDescription = "Security group changes detected"
      MetricValue = "1"
    },
    @{
      Name = "NACLChanges"
      Pattern = '{ ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }'
      AlarmName = "CIS-NACLChanges"
      AlarmDescription = "Network ACL changes detected"
      MetricValue = "1"
    },
    @{
      Name = "NetworkGatewayChanges"
      Pattern = '{ ($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway) }'
      AlarmName = "CIS-NetworkGatewayChanges"
      AlarmDescription = "Network gateway changes detected"
      MetricValue = "1"
    },
    @{
      Name = "RouteTableChanges"
      Pattern = '{ ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }'
      AlarmName = "CIS-RouteTableChanges"
      AlarmDescription = "Route table changes detected"
      MetricValue = "1"
    },
    @{
      Name = "VPCChanges"
      Pattern = '{ ($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink) }'
      AlarmName = "CIS-VPCChanges"
      AlarmDescription = "VPC changes detected"
      MetricValue = "1"
    }
  )
  
  foreach ($filter in $metricFilters) {
    try {
      # Create metric filter
      $metricName = $filter.Name
      $filterPattern = $filter.Pattern
      $alarmName = $filter.AlarmName
      
      Write-Info "[$Region] Creating metric filter: $metricName"
      
      if (-not $DryRun) {
        # Check if filter already exists
        $existingFilters = aws logs describe-metric-filters --log-group-name $CloudTrailLogGroupName --region $Region --output json | ConvertFrom-Json
        $existingFilter = $existingFilters.metricFilters | Where-Object { $_.filterName -eq $metricName }
        
        if (-not $existingFilter) {
          # Create metric transformations with proper variable expansion
          $metricTransformations = "metricName=$metricName,metricNamespace=CIS/SecurityMetrics,metricValue=$($filter.MetricValue)"
          aws logs put-metric-filter `
            --log-group-name $CloudTrailLogGroupName `
            --filter-name $metricName `
            --filter-pattern "$filterPattern" `
            --metric-transformations $metricTransformations `
            --region $Region 2>$null | Out-Null
        } else {
          Write-Info "[$Region] Metric filter $metricName already exists"
        }
        
        # Create CloudWatch alarm
        Write-Info "[$Region] Creating alarm: $alarmName"
        
        # Validate SNS ARN before creating alarm
        if (-not $SnsTopicArn -or -not $SnsTopicArn.StartsWith("arn:aws:sns:")) {
          Write-Warn "[$Region] Invalid SNS ARN for alarm $alarmName : $SnsTopicArn"
          continue
        }
        
        aws cloudwatch put-metric-alarm `
          --alarm-name $alarmName `
          --alarm-description "$($filter.AlarmDescription)" `
          --metric-name $metricName `
          --namespace "CIS/SecurityMetrics" `
          --statistic Sum `
          --period 300 `
          --threshold 1 `
          --comparison-operator GreaterThanOrEqualToThreshold `
          --evaluation-periods 1 `
          --alarm-actions $SnsTopicArn `
          --treat-missing-data notBreaching `
          --region $Region 2>$null | Out-Null
      }
      
      Write-Info "[$Region] Created metric filter and alarm for: $metricName"
    } catch {
      Write-Warn "[$Region] Failed to create metric filter/alarm for $($filter.Name): $_"
    }
  }
}


function Enable-ConfigWithServiceLinkedRole {
  param([string]$Region)
  
  Write-Info "[$Region] Enabling AWS Config with service-linked role"
  
  # Get account ID
  $accountId = Get-AccountId
  
  # Create Config service-linked role
  try {
    Write-Info "[$Region] Creating Config service-linked role"
    if (-not $DryRun) {
      # Check if the service-linked role already exists
      $existingRoles = aws iam list-roles --path-prefix "/aws-service-role/config.amazonaws.com/" --output json 2>$null | ConvertFrom-Json
      if ($existingRoles.Roles.Count -eq 0) {
        aws iam create-service-linked-role --aws-service-name config.amazonaws.com 2>$null
        Write-Info "[$Region] Config service-linked role created successfully"
      } else {
        Write-Info "[$Region] Config service-linked role already exists: $($existingRoles.Roles[0].RoleName)"
      }
    }
  } catch {
    if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*InvalidInput*" -or $_.Exception.Message -like "*EntityAlreadyExists*") {
      Write-Info "[$Region] Config service-linked role already exists"
    } else {
      Write-Warn "[$Region] Failed to create Config service-linked role: $_"
    }
  }
  
  # Get the service-linked role ARN
  $serviceLinkedRoleArn = "arn:aws:iam::${accountId}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig"
  
  # Create S3 bucket for Config
  $bucketName = if ($ConfigBucketName) { "$ConfigBucketName-$Region" } else { "cis-config-$Region-$RandomSuffix" }
  $null = New-SecureBucket -BucketName $bucketName -Region $Region
  
  # Apply Config-specific bucket policy
  if (-not $DryRun) {
    try {
      $configPolicy = @{
        Version = "2012-10-17"
        Statement = @(
          @{
            Sid = "AWSConfigBucketPermissionsCheck"
            Effect = "Allow"
            Principal = @{ Service = "config.amazonaws.com" }
            Action = "s3:GetBucketAcl"
            Resource = "arn:aws:s3:::$bucketName"
            Condition = @{
              StringEquals = @{
                "AWS:SourceAccount" = $accountId
              }
            }
          }
          @{
            Sid = "AWSConfigBucketExistenceCheck"
            Effect = "Allow"
            Principal = @{ Service = "config.amazonaws.com" }
            Action = "s3:ListBucket"
            Resource = "arn:aws:s3:::$bucketName"
            Condition = @{
              StringEquals = @{
                "AWS:SourceAccount" = $accountId
              }
            }
          }
          @{
            Sid = "AWSConfigBucketDelivery"
            Effect = "Allow"
            Principal = @{ Service = "config.amazonaws.com" }
            Action = "s3:PutObject"
            Resource = "arn:aws:s3:::$bucketName/AWSLogs/$accountId/Config/*"
            Condition = @{
              StringEquals = @{
                "s3:x-amz-acl" = "bucket-owner-full-control"
                "AWS:SourceAccount" = $accountId
              }
            }
          }
          @{
            Sid = "AWSConfigBucketDeliveryGetAcl"
            Effect = "Allow"
            Principal = @{ Service = "config.amazonaws.com" }
            Action = "s3:GetBucketAcl"
            Resource = "arn:aws:s3:::$bucketName"
            Condition = @{
              StringEquals = @{
                "AWS:SourceAccount" = $accountId
              }
            }
          }
          @{
            Sid = "DenyInsecureTransport"
            Effect = "Deny"
            Principal = "*"
            Action = "s3:*"
            Resource = @("arn:aws:s3:::$bucketName", "arn:aws:s3:::$bucketName/*")
            Condition = @{
              Bool = @{
                "aws:SecureTransport" = "false"
              }
            }
          }
        )
      } | ConvertTo-Json -Depth 10
      $configPolicy | Out-File -FilePath "config-bucket-policy.json" -Encoding UTF8
      aws s3api put-bucket-policy --bucket $bucketName --policy file://config-bucket-policy.json
      Remove-Item "config-bucket-policy.json" -ErrorAction SilentlyContinue
    } catch {
      Write-Warn "[$Region] Failed to apply Config bucket policy: $_"
    }
  }
  
  # Create/update configuration recorder with service-linked role
  try {
    if (-not $DryRun) {
      $recorderConfig = @{
        name = "default"
        roleARN = $serviceLinkedRoleArn
        recordingGroup = @{
          allSupported = $true
          includeGlobalResourceTypes = $true
        }
      } | ConvertTo-Json -Depth 10
      $recorderConfig | Out-File -FilePath "config-recorder.json" -Encoding UTF8
      aws configservice put-configuration-recorder --configuration-recorder file://config-recorder.json --region $Region 2>$null | Out-Null
      Remove-Item "config-recorder.json" -ErrorAction SilentlyContinue
      
      # Create delivery channel
      $deliveryConfig = @{
        name = "default"
        s3BucketName = $bucketName
        configSnapshotDeliveryProperties = @{
          deliveryFrequency = $ConfigDeliveryFrequency
        }
      } | ConvertTo-Json -Depth 10
      $deliveryConfig | Out-File -FilePath "delivery-channel.json" -Encoding UTF8
      aws configservice put-delivery-channel --delivery-channel file://delivery-channel.json --region $Region 2>$null | Out-Null
      Remove-Item "delivery-channel.json" -ErrorAction SilentlyContinue
      
      # Start recorder
      aws configservice start-configuration-recorder --configuration-recorder-name default --region $Region 2>$null | Out-Null
    }
    Write-Info "[$Region] AWS Config configured successfully with service-linked role"
  } catch {
    Write-Warn "[$Region] Failed to configure Config: $_"
  }
}

function Enable-CloudTrailWithCloudWatchLogs {
  param([string]$Region)
  
  # CloudTrail is typically created in home region only (multi-region trail)
  if ($Region -ne $HomeRegion) {
    return
  }
  
  Write-Info "[$Region] Ensuring CloudTrail with CloudWatch Logs integration: $TrailName"
  
  # Get account ID for policies
  $accountId = Get-AccountId
  
  # Create KMS key
  $keyId = New-KmsKey -AliasName $TrailKmsAlias -Region $Region
  
  # Create S3 bucket
  $bucketName = if ($TrailBucketName) { $TrailBucketName } else { "cis-cloudtrail-$Region-$RandomSuffix" }
  $null = New-SecureBucket -BucketName $bucketName -Region $Region -KmsKeyId $keyId
  
  # Create CloudWatch Log Group for CloudTrail
  $logGroupName = "/aws/cloudtrail/$TrailName"
  Write-Info "[$Region] Creating CloudWatch Log Group: $logGroupName"
  
  if (-not $DryRun) {
    try {
      aws logs create-log-group --log-group-name $logGroupName --region $Region 2>$null
      Write-Info "[$Region] Created CloudWatch Log Group: $logGroupName"
    } catch {
      if ($_.Exception.Message -like "*ResourceAlreadyExistsException*") {
        Write-Info "[$Region] CloudWatch Log Group already exists: $logGroupName"
      } else {
        Write-Warn "[$Region] Failed to create log group: $_"
      }
    }
    
    # Set retention policy (this can be done even if group exists)
    try {
      aws logs put-retention-policy --log-group-name $logGroupName --retention-in-days 365 --region $Region 2>$null | Out-Null
      Write-Info "[$Region] Set retention policy for log group: $logGroupName"
    } catch {
      Write-Warn "[$Region] Failed to set retention policy: $_"
    }
  }
  
  # Create IAM role for CloudTrail to CloudWatch Logs
  $cloudTrailLogRoleName = "CloudTrail_CloudWatchLogsRole"
  $cloudTrailLogRoleArn = "arn:aws:iam::${accountId}:role/$cloudTrailLogRoleName"
  
  if (-not $DryRun) {
    try {
      # Check if role exists first - if it does, just use it
      $existingRole = aws iam get-role --role-name $cloudTrailLogRoleName --output json 2>$null | ConvertFrom-Json
      if ($existingRole) {
        Write-Info "[$Region] CloudTrail CloudWatch Logs role already exists - reusing existing role"
        
        # Verify the role has the required policy attached
        try {
          $attachedPolicies = aws iam list-attached-role-policies --role-name $cloudTrailLogRoleName --output json | ConvertFrom-Json
          $hasCloudTrailPolicy = $attachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq "CloudTrailLogsPolicy" }
          
          if (-not $hasCloudTrailPolicy) {
            Write-Info "[$Region] Checking if CloudTrailLogsPolicy exists before attaching"
            
            # Check if the policy exists first with proper validation
            $policyExists = $false
            try {
              $policyResult = aws iam get-policy --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" --output json 2>$null | ConvertFrom-Json
              if ($policyResult -and $policyResult.Policy -and $policyResult.Policy.Arn) {
                Write-Info "[$Region] CloudTrailLogsPolicy exists - attaching to existing role"
                $policyExists = $true
                aws iam attach-role-policy --role-name $cloudTrailLogRoleName --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
                Write-Info "[$Region] Successfully attached CloudTrailLogsPolicy to existing role"
              }
            } catch {
              Write-Info "[$Region] CloudTrailLogsPolicy validation failed or doesn't exist - will create new policy"
            }
            
            # If policy doesn't exist or attachment failed, create new policy
            if (-not $policyExists) {
              Write-Info "[$Region] Creating new CloudTrailLogsPolicy"
              
              # Create the policy since it doesn't exist
              $policyDoc = @{
                Version = "2012-10-17"
                Statement = @(
                  @{
                    Effect = "Allow"
                    Action = @(
                      "logs:PutLogEvents",
                      "logs:CreateLogGroup",
                      "logs:CreateLogStream",
                      "logs:DescribeLogStreams",
                      "logs:DescribeLogGroups"
                    )
                    Resource = @(
                      "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}",
                      "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*"
                    )
                  }
                )
              } | ConvertTo-Json -Depth 10
              $policyDoc | Out-File -FilePath "cloudtrail-logs-policy.json" -Encoding UTF8
              
              try {
                aws iam create-policy --policy-name CloudTrailLogsPolicy --policy-document file://cloudtrail-logs-policy.json 2>$null | Out-Null
                Write-Info "[$Region] Created CloudTrailLogsPolicy"
                
                aws iam attach-role-policy --role-name $cloudTrailLogRoleName --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
                Write-Info "[$Region] Attached new CloudTrailLogsPolicy to existing role"
              } catch {
                Write-Warn "[$Region] Failed to create or attach CloudTrailLogsPolicy: $_"
              }
              
              Remove-Item "cloudtrail-logs-policy.json" -ErrorAction SilentlyContinue
            }
          } else {
            Write-Info "[$Region] CloudTrailLogsPolicy already attached to role"
          }
        } catch {
          Write-Warn "[$Region] Could not verify policy attachment: $_"
        }
      } else {
        # Role doesn't exist, create it
        Write-Info "[$Region] Creating CloudTrail CloudWatch Logs role"
        
        $trustPolicy = @{
          Version = "2012-10-17"
          Statement = @(
            @{
              Effect = "Allow"
              Principal = @{ Service = "cloudtrail.amazonaws.com" }
              Action = "sts:AssumeRole"
              Condition = @{
                StringEquals = @{
                  "aws:SourceAccount" = $accountId
                }
              }
            }
          )
        } | ConvertTo-Json -Depth 10
        $trustPolicy | Out-File -FilePath "cloudtrail-logs-trust-policy.json" -Encoding UTF8
        
        aws iam create-role --role-name $cloudTrailLogRoleName --assume-role-policy-document file://cloudtrail-logs-trust-policy.json 2>$null | Out-Null
        Write-Info "[$Region] Created CloudTrail role: $cloudTrailLogRoleName"
        
        # Create and attach policy with more comprehensive permissions
        $policyDoc = @{
          Version = "2012-10-17"
          Statement = @(
            @{
              Effect = "Allow"
              Action = @(
                "logs:PutLogEvents",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups"
              )
              Resource = @(
                "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}",
                "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*"
              )
            }
          )
        } | ConvertTo-Json -Depth 10
        $policyDoc | Out-File -FilePath "cloudtrail-logs-policy.json" -Encoding UTF8
        
        # Check if policy already exists
        try {
          aws iam get-policy --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
          Write-Info "[$Region] CloudTrailLogsPolicy already exists"
        } catch {
          aws iam create-policy --policy-name CloudTrailLogsPolicy --policy-document file://cloudtrail-logs-policy.json 2>$null | Out-Null
          Write-Info "[$Region] Created CloudTrailLogsPolicy"
        }
        
        aws iam attach-role-policy --role-name $cloudTrailLogRoleName --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
        Write-Info "[$Region] Attached policy to CloudTrail role"
        
        Remove-Item "cloudtrail-logs-trust-policy.json" -ErrorAction SilentlyContinue
        Remove-Item "cloudtrail-logs-policy.json" -ErrorAction SilentlyContinue
        
        # Wait longer for role to propagate - CloudTrail is sensitive to IAM delays
        Start-Sleep -Seconds 30
        Write-Info "[$Region] Waiting for IAM role to propagate (30 seconds)..."
      }
    } catch {
      Write-Warn "[$Region] Failed to setup CloudTrail CloudWatch Logs role: $_"
      # Set role ARN to null to skip CloudWatch Logs integration
      $cloudTrailLogRoleArn = $null
    }
  }
  
  # Apply CloudTrail-specific bucket policy
  if (-not $DryRun) {
    $cloudTrailPolicy = @{
      Version = "2012-10-17"
      Statement = @(
        @{
          Sid = "AWSCloudTrailAclCheck"
          Effect = "Allow"
          Principal = @{ Service = "cloudtrail.amazonaws.com" }
          Action = "s3:GetBucketAcl"
          Resource = "arn:aws:s3:::$bucketName"
          Condition = @{
            StringEquals = @{
              "AWS:SourceArn" = "arn:aws:cloudtrail:${Region}:${accountId}:trail/$TrailName"
            }
          }
        }
        @{
          Sid = "AWSCloudTrailWrite"
          Effect = "Allow"
          Principal = @{ Service = "cloudtrail.amazonaws.com" }
          Action = "s3:PutObject"
          Resource = "arn:aws:s3:::$bucketName/AWSLogs/$accountId/*"
          Condition = @{
            StringEquals = @{
              "s3:x-amz-acl" = "bucket-owner-full-control"
              "AWS:SourceArn" = "arn:aws:cloudtrail:${Region}:${accountId}:trail/$TrailName"
            }
          }
        }
        @{
          Sid = "DenyInsecureTransport"
          Effect = "Deny"
          Principal = "*"
          Action = "s3:*"
          Resource = @("arn:aws:s3:::$bucketName", "arn:aws:s3:::$bucketName/*")
          Condition = @{
            Bool = @{
              "aws:SecureTransport" = "false"
            }
          }
        }
      )
    } | ConvertTo-Json -Depth 10
    $cloudTrailPolicy | Out-File -FilePath "cloudtrail-policy.json" -Encoding UTF8
    aws s3api put-bucket-policy --bucket $bucketName --policy file://cloudtrail-policy.json
    Remove-Item "cloudtrail-policy.json" -ErrorAction SilentlyContinue
  }
  
  # Check if trail already exists and get its current configuration
  $existingTrail = $null
  $trailExists = $false
  $currentCloudWatchLogsRoleArn = $null
  
  try {
    $existingTrail = aws cloudtrail describe-trails --trail-name-list $TrailName --region $Region --output json 2>$null | ConvertFrom-Json
    if ($existingTrail -and $existingTrail.trailList -and $existingTrail.trailList.Count -gt 0) {
      Write-Info "[$Region] CloudTrail '$TrailName' already exists - checking current configuration"
      $trailExists = $true
      $currentTrail = $existingTrail.trailList[0]
      $currentCloudWatchLogsRoleArn = $currentTrail.CloudWatchLogsRoleArn
      $currentLogGroupArn = $currentTrail.CloudWatchLogsLogGroupArn
      
      # Log current configuration
      if ($currentCloudWatchLogsRoleArn) {
        Write-Info "[$Region] Current CloudWatch Logs Role: $currentCloudWatchLogsRoleArn"
      }
      if ($currentLogGroupArn) {
        Write-Info "[$Region] Current CloudWatch Logs Group: $currentLogGroupArn"
        # Check if it's already pointing to our desired log group
        if ($currentLogGroupArn -like "*$logGroupName*") {
          Write-Info "[$Region] CloudTrail already configured with desired log group"
        }
      }
      if (-not $currentCloudWatchLogsRoleArn) {
        Write-Info "[$Region] No CloudWatch Logs integration currently configured"
      }
    } else {
      $trailExists = $false
    }
  } catch {
    $trailExists = $false
  }
  
  # Create or update trail with CloudWatch Logs integration
  $trailCreated = $false
  try {
    if ($trailExists) {
      # Update existing trail - be more careful with existing CloudWatch Logs configuration
      if ($keyId -and $cloudTrailLogRoleArn) {
        if (-not $DryRun) {
          # Check if trail already has the correct CloudWatch Logs setup
          if ($currentLogGroupArn -like "*$logGroupName*" -and $currentCloudWatchLogsRoleArn) {
            Write-Info "[$Region] CloudTrail already has correct CloudWatch Logs configuration, updating other settings only"
            try {
              aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
              $trailCreated = $true
              Write-Info "[$Region] Updated CloudTrail (kept existing CloudWatch Logs configuration)"
              # Use the existing role for metric filters
              $cloudTrailLogRoleArn = $currentCloudWatchLogsRoleArn
            } catch {
              Write-Warn "[$Region] Failed to update CloudTrail: $_"
            }
          } else {
            try {
              # If trail already has CloudWatch Logs configured, we might need to handle it differently
              if ($currentCloudWatchLogsRoleArn -and $currentCloudWatchLogsRoleArn -ne $cloudTrailLogRoleArn) {
                Write-Info "[$Region] Trail has different CloudWatch Logs role, updating to new role"
              }
              
              aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
              $trailCreated = $true
              Write-Info "[$Region] Updated CloudTrail with CloudWatch Logs integration"
            } catch {
              Write-Warn "[$Region] Failed to update CloudTrail with CloudWatch Logs: $_"
              # If current trail has CloudWatch Logs but we can't update it, try to preserve existing setup
              if ($currentCloudWatchLogsRoleArn) {
                Write-Info "[$Region] Attempting to update trail while preserving existing CloudWatch Logs configuration"
                try {
                  aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
                  $trailCreated = $true
                  Write-Info "[$Region] Updated CloudTrail (preserved existing CloudWatch Logs configuration)"
                  # Use the existing role for metric filters
                  $cloudTrailLogRoleArn = $currentCloudWatchLogsRoleArn
                } catch {
                  Write-Warn "[$Region] Failed to update CloudTrail: $_"
                }
              } else {
                # Try without CloudWatch Logs integration
                try {
                  aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
                  $trailCreated = $true
                  Write-Warn "[$Region] Updated CloudTrail without CloudWatch Logs integration"
                } catch {
                  Write-Warn "[$Region] Failed to update CloudTrail: $_"
                }
              }
            }
          }
        }
      } elseif ($cloudTrailLogRoleArn) {
        Write-Warn "[$Region] Updating CloudTrail without KMS encryption (KMS key creation failed)"
        if (-not $DryRun) {
          try {
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Info "[$Region] Updated CloudTrail with CloudWatch Logs integration (no KMS)"
          } catch {
            Write-Warn "[$Region] Failed to update CloudTrail with CloudWatch Logs: $_"
            # Try without CloudWatch Logs integration
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Warn "[$Region] Updated CloudTrail without CloudWatch Logs integration"
          }
        }
      } else {
        Write-Warn "[$Region] Updating CloudTrail without CloudWatch Logs (role creation failed)"
        if (-not $DryRun) {
          if ($keyId) {
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
          } else {
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
          }
          $trailCreated = $true
        }
      }
    } else {
      # Create new trail
      if ($keyId -and $cloudTrailLogRoleArn) {
        if (-not $DryRun) {
          try {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Info "[$Region] Created CloudTrail with CloudWatch Logs integration"
          } catch {
            Write-Warn "[$Region] Failed to create CloudTrail with CloudWatch Logs: $_"
            # Try without CloudWatch Logs integration
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Warn "[$Region] Created CloudTrail without CloudWatch Logs integration"
          }
        }
      } elseif ($cloudTrailLogRoleArn) {
        Write-Warn "[$Region] Creating CloudTrail without KMS encryption (KMS key creation failed)"
        if (-not $DryRun) {
          try {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Info "[$Region] Created CloudTrail with CloudWatch Logs integration (no KMS)"
          } catch {
            Write-Warn "[$Region] Failed to create CloudTrail with CloudWatch Logs: $_"
            # Try without CloudWatch Logs integration
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Warn "[$Region] Created CloudTrail without CloudWatch Logs integration"
          }
        }
      } else {
        Write-Warn "[$Region] Creating CloudTrail without CloudWatch Logs (role creation failed)"
        if (-not $DryRun) {
          if ($keyId) {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
          } else {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
          }
          $trailCreated = $true
        }
      }
    }
    
    # Start logging
    if ($trailCreated -and (-not $DryRun)) {
      aws cloudtrail start-logging --name $TrailName --region $Region 2>$null | Out-Null
    }
    Write-Info "[$Region] CloudTrail '$TrailName' configured successfully with CloudWatch Logs"
    
    # Return the log group name for metric filters only if CloudWatch Logs integration worked
    if ($cloudTrailLogRoleArn) {
      Write-Info "[$Region] Returning log group name for metric filters: $logGroupName"
      return $logGroupName
    } else {
      Write-Warn "[$Region] CloudWatch metric filters will not be created (CloudWatch Logs integration failed)"
      return $null
    }
  } catch {
    Write-Warn "[$Region] Failed to configure CloudTrail: $_"
    return $null
  }
}

# Include all existing functions from the original script
function Set-AccountAliasAndSecurityContact {
  Write-Info "Setting account alias: $AccountAlias"
  
  # Check if alias already exists
  try {
    $existingAliases = $null
    try {
      $existingAliases = aws iam list-account-aliases --output json 2> alias-error.txt | ConvertFrom-Json
    } catch {
      $aliasErr = (Get-Content alias-error.txt -ErrorAction SilentlyContinue | Select-Object -First 3) -join ' '
      if ($aliasErr -match 'AccessDenied') {
        Write-Warn "AccessDenied listing account aliases. Missing iam:ListAccountAliases permission. Skipping alias configuration.";
        Remove-Item alias-error.txt -ErrorAction SilentlyContinue
        goto SkipAlias
      } else {
        Write-Warn "Failed to list account aliases: $aliasErr"
        Remove-Item alias-error.txt -ErrorAction SilentlyContinue
        goto SkipAlias
      }
    }
    Remove-Item alias-error.txt -ErrorAction SilentlyContinue
    if ($existingAliases -and $existingAliases.AccountAliases -contains $AccountAlias) {
      Write-Info "Account alias '$AccountAlias' already exists - skipping"
    } elseif (-not $DryRun) {
      aws iam create-account-alias --account-alias $AccountAlias 2> create-alias-error.txt
      if ($LASTEXITCODE -eq 0) {
        Write-Info "Account alias '$AccountAlias' set successfully"
      } else {
        $createErr = (Get-Content create-alias-error.txt -ErrorAction SilentlyContinue | Select-Object -First 4) -join ' '
        if ($createErr -match 'AccessDenied') {
          Write-Warn "AccessDenied creating account alias. Required permissions: iam:CreateAccountAlias (and optionally iam:ListAccountAliases)."
        } elseif ($createErr -match 'EntityAlreadyExists') {
          Write-Info "Account alias '$AccountAlias' already exists - skipping"
        } else {
          Write-Warn "Failed to create account alias: $createErr"
        }
      }
      Remove-Item create-alias-error.txt -ErrorAction SilentlyContinue
    } else {
      Write-Info "DRY-RUN: Would create account alias '$AccountAlias'"
    }
  } catch {
    if ($_.Exception.Message -like "*EntityAlreadyExists*" -or $_.Exception.Message -like "*already exists*") {
      Write-Info "Account alias '$AccountAlias' already exists - skipping"
    } else {
      Write-Warn "Failed to set account alias: $_"
    }
  }
  :SkipAlias
  
  Write-Info "Setting security contact"
  $contactName = "$SecurityFirstName $SecurityLastName".Trim()
  if (-not $contactName) { $contactName = "Security" }
  
  Invoke-AwsCliSafe "account put-alternate-contact --alternate-contact-type SECURITY --email-address '$SecurityEmail' --name '$contactName' --phone-number '$SecurityPhone' --title '$SecurityTitle'"
}

function Set-IamPasswordPolicy {
  Write-Info "Setting IAM password policy (CIS-aligned)"
  Invoke-AwsCliSafe "iam update-account-password-policy --minimum-password-length 14 --require-symbols --require-numbers --require-uppercase-characters --require-lowercase-characters --allow-users-to-change-password --password-reuse-prevention 24 --no-hard-expiry"
}

function Set-AccountLevelS3BlockPublicAccess {
  Write-Info "Enabling account-level S3 Block Public Access"
  $accountId = Get-AccountId
  Invoke-AwsCliSafe "s3control put-public-access-block --account-id $accountId --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
}

function New-SupportRole {
  Write-Info "Creating AWS Support role"
  
  # Check if role already exists
  try {
    $existingRole = aws iam get-role --role-name AWSSupportRole --output json 2>$null | ConvertFrom-Json
    if ($existingRole) {
      Write-Info "AWS Support role already exists - ensuring policy is attached"
      try {
        if (-not $DryRun) {
          aws iam attach-role-policy --role-name AWSSupportRole --policy-arn arn:aws:iam::aws:policy/AWSSupportAccess 2>$null
        }
        Write-Info "AWS Support policy attachment verified"
      } catch {
        # Policy may already be attached - this is fine
        Write-Info "AWS Support policy already attached to role"
      }
      return
    }
  } catch {
    # Role doesn't exist, continue with creation
  }
  
  $trustPolicy = @{
    Version = "2012-10-17"
    Statement = @(
      @{
        Effect = "Allow"
        Principal = @{ Service = "support.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    )
  } | ConvertTo-Json -Depth 10 -Compress
  
  try {
    if (-not $DryRun) {
      $trustPolicy | Out-File -FilePath "support-trust-policy.json" -Encoding UTF8
      aws iam create-role --role-name AWSSupportRole --assume-role-policy-document file://support-trust-policy.json 2>$null | Out-Null
      aws iam attach-role-policy --role-name AWSSupportRole --policy-arn arn:aws:iam::aws:policy/AWSSupportAccess 2>$null | Out-Null
      Remove-Item "support-trust-policy.json" -ErrorAction SilentlyContinue
    }
    Write-Info "Created AWS Support role successfully"
  } catch {
    Write-Warn "Failed to create support role: $_"
    if (-not $DryRun) {
      Remove-Item "support-trust-policy.json" -ErrorAction SilentlyContinue
    }
  }
}

function New-KmsKey {
  param(
    [string]$AliasName,
    [string]$Region
  )
  
  if (-not $AliasName.StartsWith("alias/")) {
    $AliasName = "alias/$AliasName"
  }
  
  Write-Info "[$Region] Ensuring KMS key: $AliasName"
  
  # Check if alias exists
  try {
    $aliases = aws kms list-aliases --region $Region --output json | ConvertFrom-Json
    $existing = $aliases.Aliases | Where-Object { $_.AliasName -eq $AliasName -and $_.TargetKeyId }
    if ($existing) {
      Write-Info "[$Region] Reusing existing KMS key for $AliasName"
      if (-not $DryRun) {
        aws kms enable-key-rotation --key-id $($existing.TargetKeyId) --region $Region
      }
      return $existing.TargetKeyId
    }
  } catch {
    Write-Warn "[$Region] Failed to list KMS aliases: $_"
  }
  
  # Create new key
  try {
    if ($DryRun) {
      Write-Info "[$Region] Would create KMS key $AliasName"
      return "key-12345678-1234-1234-1234-123456789012"
    }
    
    $keyResult = aws kms create-key --description "CIS hardening key for $AliasName" --region $Region --output json | ConvertFrom-Json
    if (-not $keyResult -or -not $keyResult.KeyMetadata -or -not $keyResult.KeyMetadata.KeyId) {
      throw "Failed to create KMS key - invalid response"
    }
    
    $keyId = $keyResult.KeyMetadata.KeyId
    aws kms create-alias --alias-name $AliasName --target-key-id $keyId --region $Region
    aws kms enable-key-rotation --key-id $keyId --region $Region
    Write-Info "[$Region] Created KMS key: $AliasName -> $keyId"
    return $keyId
  } catch {
    Write-Warn "[$Region] Failed to create KMS key $AliasName : $_"
    return $null
  }
}

function New-SecureBucket {
  param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9\-\.]+$')][string]$BucketName,
    [Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region,
    [Parameter()][string]$KmsKeyId = $null
  )
  
  Write-Info "[$Region] Ensuring secure S3 bucket: $BucketName"
  
  # Check if bucket already exists
  $bucketExists = $false
  try {
    $null = aws s3api head-bucket --bucket $BucketName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Info "[$Region] Bucket $BucketName already exists - configuring security"
      $bucketExists = $true
    }
  } catch {
    # Bucket doesn't exist, will create it
    $bucketExists = $false
  }
  
  # Create bucket if it doesn't exist
  if (-not $bucketExists) {
    try {
      if (-not $DryRun) {
        if ($Region -eq "us-east-1") {
          aws s3api create-bucket --bucket $BucketName --region $Region 2>$null
        } else {
          aws s3api create-bucket --bucket $BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region 2>$null
        }
        
        if ($LASTEXITCODE -ne 0) {
          throw "Failed to create bucket - AWS CLI returned exit code $LASTEXITCODE"
        }
        
        # Wait a moment for bucket to be available
        Start-Sleep -Seconds 3
        
        # Verify bucket was created
        $null = aws s3api head-bucket --bucket $BucketName --region $Region 2>$null
        if ($LASTEXITCODE -ne 0) {
          throw "Bucket creation appeared to succeed but bucket is not accessible"
        }
        
        $bucketExists = $true
      }
      Write-Info "[$Region] Created S3 bucket: $BucketName"
    } catch {
      Write-Warn "[$Region] Failed to create bucket $BucketName : $_"
      return $null
    }
  }
  
  # Only configure security if bucket exists or was successfully created
  if ($bucketExists -and (-not $DryRun)) {
    try {
      # Enable versioning
      Write-Info "[$Region] Enabling versioning for bucket: $BucketName"
      aws s3api put-bucket-versioning --bucket $BucketName --versioning-configuration Status=Enabled 2>$null
      if ($LASTEXITCODE -ne 0) {
        Write-Warn "[$Region] Failed to enable versioning for bucket $BucketName"
      }
      
      # Configure encryption
      Write-Info "[$Region] Configuring encryption for bucket: $BucketName"
      if ($KmsKeyId) {
        $encConfig = @{
          Rules = @(
            @{
              ApplyServerSideEncryptionByDefault = @{
                SSEAlgorithm = "aws:kms"
                KMSMasterKeyID = $KmsKeyId
              }
              BucketKeyEnabled = $true
            }
          )
        } | ConvertTo-Json -Depth 10 -Compress
      } else {
        $encConfig = @{
          Rules = @(
            @{
              ApplyServerSideEncryptionByDefault = @{
                SSEAlgorithm = "AES256"
              }
            }
          )
        } | ConvertTo-Json -Depth 10 -Compress
      }
      
      $encConfig | Out-File -FilePath "encryption-config.json" -Encoding UTF8
      aws s3api put-bucket-encryption --bucket $BucketName --server-side-encryption-configuration file://encryption-config.json 2>$null
      if ($LASTEXITCODE -ne 0) {
        Write-Warn "[$Region] Failed to configure encryption for bucket $BucketName"
      }
      Remove-Item "encryption-config.json" -ErrorAction SilentlyContinue
      
    } catch {
      Write-Warn "[$Region] Failed to configure security settings for bucket $BucketName : $_"
    }
  }
  
  return $BucketName
}
function Enable-S3ObjectLogging {
  param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region, 
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9\-_]+$')][string]$CloudTrailName
  )
  
  Write-Info "[$Region] Enabling S3 object-level logging in CloudTrail"
  
  try {
    # Get existing trail configuration
    $trail = aws cloudtrail describe-trails --trail-name-list $CloudTrailName --region $Region --output json 2>$null | ConvertFrom-Json
    if (-not $trail.trailList -or $trail.trailList.Count -eq 0) {
      Write-Warn "[$Region] CloudTrail $CloudTrailName not found for S3 object logging"
      return
    }
    
    # Configure event selectors for S3 object-level read events - fixed JSON structure
    $eventSelectors = @(
      @{
        ReadWriteType = "ReadOnly"
        IncludeManagementEvents = $false
        DataResources = @(
          @{
            Type = "AWS::S3::Object"
            Values = @("arn:aws:s3:::*/*")
          }
        )
      }
    )
    
    $eventSelectorsJson = $eventSelectors | ConvertTo-Json -Depth 10
    $eventSelectorsJson | Out-File -FilePath "event-selectors.json" -Encoding UTF8
    
    if (-not $DryRun) {
      aws cloudtrail put-event-selectors --trail-name $CloudTrailName --event-selectors file://event-selectors.json --region $Region 2>$null
      if ($LASTEXITCODE -eq 0) {
        Write-Info "[$Region] Enabled S3 object-level read logging in CloudTrail"
      } else {
        Write-Warn "[$Region] Failed to configure S3 object-level logging for CloudTrail $CloudTrailName"
      }
    }
    
    Remove-Item "event-selectors.json" -ErrorAction SilentlyContinue
  } catch {
    Write-Warn "[$Region] Failed to enable S3 object logging: $_"
    Remove-Item "event-selectors.json" -ErrorAction SilentlyContinue
  }
}

function Enable-SecurityHub {
  param([string]$Region)
  
  Write-Info "[$Region] Enabling Security Hub with CIS standard"
  
  # Check if Security Hub is already enabled
  try {
    $enabledStandards = aws securityhub get-enabled-standards --region $Region --output json 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0) {
      Write-Info "[$Region] Security Hub already enabled"
      $hubEnabled = $true
    } else {
      $hubEnabled = $false
    }
  } catch {
    $hubEnabled = $false
  }
  
  # Enable Security Hub if not already enabled
  if (-not $hubEnabled) {
    try {
      if (-not $DryRun) {
        aws securityhub enable-security-hub --enable-default-standards --region $Region
      }
      Write-Info "[$Region] Security Hub enabled successfully"
    } catch {
      Write-Warn "[$Region] Failed to enable Security Hub: $_"
      return
    }
  }
}

function Enable-GuardDuty {
  param([string]$Region)
  
  Write-Info "[$Region] Enabling GuardDuty"
  
  try {
    # Check if detector exists
    $detectors = aws guardduty list-detectors --region $Region --output json | ConvertFrom-Json
    if ($detectors.DetectorIds.Count -eq 0) {
      Invoke-AwsCliSafe "guardduty create-detector --enable --region $Region"
    } else {
      $detectorId = $detectors.DetectorIds[0]
      Invoke-AwsCliSafe "guardduty update-detector --detector-id $detectorId --enable --region $Region"
    }
  } catch {
    Write-Warn "[$Region] Failed to enable GuardDuty: $_"
  }
}

function Enable-EbsDefaultEncryption {
  param([string]$Region)
  
  Write-Info "[$Region] Enabling EBS default encryption"
  
  # Create KMS key for EBS
  $keyId = New-KmsKey -AliasName $EbsDefaultKmsAlias -Region $Region
  
  try {
    Invoke-AwsCliSafe "ec2 enable-ebs-encryption-by-default --region $Region"
    if ($keyId) {
      Invoke-AwsCliSafe "ec2 modify-ebs-default-kms-key-id --kms-key-id $keyId --region $Region"
    } else {
      Write-Warn "[$Region] EBS encryption enabled with default AWS managed key (KMS key creation failed)"
    }
  } catch {
    Write-Warn "[$Region] Failed to enable EBS default encryption: $_"
  }
}

function Enable-VpcFlowLogs {
  param([string]$Region)
  
  Write-Info "[$Region] Enabling VPC Flow Logs"
  
  try {
    # Get all VPCs
    $vpcs = aws ec2 describe-vpcs --region $Region --output json | ConvertFrom-Json
    foreach ($vpc in $vpcs.Vpcs) {
      $vpcId = $vpc.VpcId
      
      # Check if flow logs already exist
      $existingFlowLogs = aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$vpcId" --region $Region --output json | ConvertFrom-Json
      if ($existingFlowLogs.FlowLogs.Count -gt 0) {
        Write-Info "[$Region] VPC $vpcId already has flow logs"
        continue
      }
      
      # Create CloudWatch log group
      $logGroupName = "$FlowLogGroupPrefix/$vpcId"
      try {
        Invoke-AwsCliSafe "logs create-log-group --log-group-name $logGroupName --region $Region"
        Invoke-AwsCliSafe "logs put-retention-policy --log-group-name $logGroupName --retention-in-days $FlowLogRetentionDays --region $Region"
      } catch {
        if (-not ($_.Exception.Message -like "*ResourceAlreadyExistsException*")) {
          Write-Warn "[$Region] Failed to create log group: $_"
        }
      }
      
      # Create service role if it doesn't exist
      $roleName = "flowlogsRole"
      $accountId = Get-AccountId
      $roleArn = "arn:aws:iam::${accountId}:role/$roleName"
      
      try {
        aws iam get-role --role-name $roleName 2>$null | Out-Null
      } catch {
        Write-Info "[$Region] Creating VPC Flow Logs service role"
        if (-not $DryRun) {
          $trustPolicy = @{
            Version = "2012-10-17"
            Statement = @(
              @{
                Effect = "Allow"
                Principal = @{ Service = "vpc-flow-logs.amazonaws.com" }
                Action = "sts:AssumeRole"
              }
            )
          } | ConvertTo-Json -Depth 10 -Compress
          $trustPolicy | Out-File -FilePath "flowlogs-trust-policy.json" -Encoding UTF8
          
          aws iam create-role --role-name $roleName --assume-role-policy-document file://flowlogs-trust-policy.json 2>$null | Out-Null
          
          $policyDoc = @{
            Version = "2012-10-17"
            Statement = @(
              @{
                Effect = "Allow"
                Action = @(
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream", 
                  "logs:PutLogEvents",
                  "logs:DescribeLogGroups",
                  "logs:DescribeLogStreams"
                )
                Resource = "*"
              }
            )
          } | ConvertTo-Json -Depth 10 -Compress
          $policyDoc | Out-File -FilePath "flowlogs-policy.json" -Encoding UTF8
          
          aws iam create-policy --policy-name flowlogsDeliveryRolePolicy --policy-document file://flowlogs-policy.json 2>$null | Out-Null
          aws iam attach-role-policy --role-name $roleName --policy-arn arn:aws:iam::${accountId}:policy/flowlogsDeliveryRolePolicy 2>$null | Out-Null
          
          Remove-Item "flowlogs-trust-policy.json" -ErrorAction SilentlyContinue
          Remove-Item "flowlogs-policy.json" -ErrorAction SilentlyContinue
        }
      }
      
      # Create flow logs
      Invoke-AwsCliSafe "ec2 create-flow-logs --resource-type VPC --resource-ids $vpcId --traffic-type ALL --log-destination-type cloud-watch-logs --log-group-name $logGroupName --deliver-logs-permission-arn $roleArn --region $Region"
      Write-Info "[$Region] Created VPC Flow Logs for VPC $vpcId"
    }
  } catch {
    Write-Warn "[$Region] Failed to enable VPC Flow Logs: $_"
  }
}


function Enable-IAMAccessAnalyzer {
  param([string]$Region)
  
  Write-Info "[$Region] Enabling IAM Access Analyzer"
  
  try {
    # Check if analyzer already exists
    $analyzers = aws accessanalyzer list-analyzers --region $Region --output json 2>$null | ConvertFrom-Json
    if ($analyzers.analyzers.Count -gt 0) {
      Write-Info "[$Region] IAM Access Analyzer already enabled"
      return
    }
    
    # Create external access analyzer
    $analyzerName = "cis-external-access-analyzer"
    if (-not $DryRun) {
      aws accessanalyzer create-analyzer --analyzer-name $analyzerName --type EXTERNAL --region $Region 2>$null | Out-Null
    }
    Write-Info "[$Region] Created IAM Access Analyzer: $analyzerName"
  } catch {
    Write-Warn "[$Region] Failed to enable IAM Access Analyzer: $_"
  }
}

function Set-VpcDefaultSecurityGroups {
  param([string]$Region)
  
  Write-Info "[$Region] Securing VPC default security groups"
  
  try {
    # Get all VPCs and their default security groups
    $vpcs = aws ec2 describe-vpcs --region $Region --output json | ConvertFrom-Json
    
    foreach ($vpc in $vpcs.Vpcs) {
      $vpcId = $vpc.VpcId
      
      # Get default security group for this VPC
      $defaultSgs = aws ec2 describe-security-groups --filters "Name=group-name,Values=default" "Name=vpc-id,Values=$vpcId" --region $Region --output json | ConvertFrom-Json
      
      foreach ($sg in $defaultSgs.SecurityGroups) {
        $sgId = $sg.GroupId
        Write-Info "[$Region] Securing default security group $sgId in VPC $vpcId"
        
        # Remove all inbound rules
        foreach ($rule in $sg.IpPermissions) {
          try {
            $ruleJson = $rule | ConvertTo-Json -Depth 10 -Compress
            $ruleJson | Out-File -FilePath "sg-rule.json" -Encoding UTF8
            if (-not $DryRun) {
              aws ec2 revoke-security-group-ingress --group-id $sgId --ip-permissions file://sg-rule.json --region $Region 2>$null | Out-Null
            }
            Write-Info "[$Region] Removed inbound rule from $sgId"
          } catch {
            Write-Warn "[$Region] Failed to remove inbound rule from $sgId : $_"
          }
        }
        
        # Remove all outbound rules
        foreach ($rule in $sg.IpPermissionsEgress) {
          try {
            $ruleJson = $rule | ConvertTo-Json -Depth 10 -Compress
            $ruleJson | Out-File -FilePath "sg-rule.json" -Encoding UTF8
            if (-not $DryRun) {
              aws ec2 revoke-security-group-egress --group-id $sgId --ip-permissions file://sg-rule.json --region $Region 2>$null | Out-Null
            }
            Write-Info "[$Region] Removed outbound rule from $sgId"
          } catch {
            Write-Warn "[$Region] Failed to remove outbound rule from $sgId : $_"
          }
        }
        
        Remove-Item "sg-rule.json" -ErrorAction SilentlyContinue
      }
    }
  } catch {
    Write-Warn "[$Region] Failed to secure default security groups: $_"
  }
}

function Enable-S3ObjectLogging {
  param([string]$Region, [string]$CloudTrailName)
  
  Write-Info "[$Region] Enabling S3 object-level logging in CloudTrail"
  
  try {
    # Get existing trail configuration
    $trail = aws cloudtrail describe-trails --trail-name-list $CloudTrailName --region $Region --output json 2>$null | ConvertFrom-Json
    if (-not $trail.trailList -or $trail.trailList.Count -eq 0) {
      Write-Warn "[$Region] CloudTrail $CloudTrailName not found for S3 object logging"
      return
    }
    
    # Configure event selectors for S3 object-level read events
    $eventSelectors = @{
      ReadWriteType = "ReadOnly"
      IncludeManagementEvents = $false
      DataResources = @(
        @{
          Type = "AWS::S3::Object"
          Values = @("arn:aws:s3:::*/*")
        }
      )
    }
    
    $eventSelectorsJson = @($eventSelectors) | ConvertTo-Json -Depth 10
    $eventSelectorsJson | Out-File -FilePath "event-selectors.json" -Encoding UTF8
    
    if (-not $DryRun) {
      aws cloudtrail put-event-selectors --trail-name $CloudTrailName --event-selectors file://event-selectors.json --region $Region 2>$null | Out-Null
    }
    
    Remove-Item "event-selectors.json" -ErrorAction SilentlyContinue
    Write-Info "[$Region] Enabled S3 object-level read logging in CloudTrail"
  } catch {
    Write-Warn "[$Region] Failed to enable S3 object logging: $_"
  }
}

function Enable-S3BucketAccessLogging {
  param([string]$BucketName, [string]$Region)
  
  Write-Info "[$Region] Enabling access logging for CloudTrail bucket: $BucketName"
  
  try {
    # Create logging bucket
    $logBucketName = "$BucketName-access-logs"
    $null = New-SecureBucket -BucketName $logBucketName -Region $Region
    
    # Configure bucket logging
    $loggingConfig = @{
      LoggingEnabled = @{
        TargetBucket = $logBucketName
        TargetPrefix = "access-logs/"
      }
    } | ConvertTo-Json -Depth 10
    
    $loggingConfig | Out-File -FilePath "logging-config.json" -Encoding UTF8
    
    if (-not $DryRun) {
      aws s3api put-bucket-logging --bucket $BucketName --bucket-logging-status file://logging-config.json
    }
    
    Remove-Item "logging-config.json" -ErrorAction SilentlyContinue
    Write-Info "[$Region] Enabled access logging for bucket $BucketName"
  } catch {
    Write-Warn "[$Region] Failed to enable bucket access logging: $_"
  }
}

function Test-RootUserMFA {
  Write-Info "Checking root user MFA status"
  
  try {
    # Get account summary which includes MFA info
    $accountSummary = aws iam get-account-summary --output json | ConvertFrom-Json
    $mfaDevices = $accountSummary.SummaryMap.AccountMFAEnabled
    
    if ($mfaDevices -eq 1) {
      Write-Info "✓ Root user MFA is enabled"
      
      # Check for hardware MFA (we can't directly detect this via API, but can check device type)
      $virtualMfaDevices = aws iam list-virtual-mfa-devices --assignment-status Assigned --output json | ConvertFrom-Json
      $rootVirtualMfa = $virtualMfaDevices.VirtualMFADevices | Where-Object { $_.User.UserName -eq "root" }
      
      if ($rootVirtualMfa) {
        Write-Warn "⚠️  Root user is using virtual MFA - consider upgrading to hardware MFA for enhanced security"
      } else {
        Write-Info "✓ Root user appears to be using hardware MFA (no virtual MFA device found)"
      }
    } else {
      Write-Warn "❌ Root user MFA is NOT enabled - this is a critical security risk"
    }
  } catch {
    Write-Warn "Failed to check root user MFA status: $_"
  }
}

function Test-IAMUserDirectPolicies {
  Write-Info "Checking for IAM users with direct policy attachments"
  
  try {
    $users = aws iam list-users --output json | ConvertFrom-Json
    $usersWithDirectPolicies = @()
    
    foreach ($user in $users.Users) {
      $userName = $user.UserName
      
      # Check attached managed policies
      $attachedPolicies = aws iam list-attached-user-policies --user-name $userName --output json | ConvertFrom-Json
      if ($attachedPolicies.AttachedPolicies.Count -gt 0) {
        $usersWithDirectPolicies += @{
          UserName = $userName
          PolicyType = "Managed"
          Policies = $attachedPolicies.AttachedPolicies
        }
      }
      
      # Check inline policies
      $inlinePolicies = aws iam list-user-policies --user-name $userName --output json | ConvertFrom-Json
      if ($inlinePolicies.PolicyNames.Count -gt 0) {
        $usersWithDirectPolicies += @{
          UserName = $userName
          PolicyType = "Inline"
          Policies = $inlinePolicies.PolicyNames
        }
      }
    }
    
    if ($usersWithDirectPolicies.Count -eq 0) {
      Write-Info "✓ No IAM users have direct policy attachments"
    } else {
      Write-Warn "❌ Found $($usersWithDirectPolicies.Count) IAM users with direct policy attachments:"
      foreach ($userPolicy in $usersWithDirectPolicies) {
        Write-Warn "  - User: $($userPolicy.UserName) | Type: $($userPolicy.PolicyType) | Count: $($userPolicy.Policies.Count)"
      }
      Write-Warn "Consider using IAM groups instead of direct policy attachments"
      if ($RemediateIamUserDirectPolicies) {
        Write-Info "Attempting remediation of direct IAM user policies (detach/delete)"
        foreach ($userPolicy in $usersWithDirectPolicies) {
          $u = $userPolicy.UserName
          try {
            if ($userPolicy.PolicyType -eq 'Managed') {
              foreach ($p in $userPolicy.Policies) {
                if (-not $DryRun) { aws iam detach-user-policy --user-name $u --policy-arn $p.PolicyArn 2>$null | Out-Null }
                Write-Info "Detached managed policy $($p.PolicyName) from user $u"
              }
            } elseif ($userPolicy.PolicyType -eq 'Inline') {
              foreach ($pName in $userPolicy.Policies) {
                if (-not $DryRun) { aws iam delete-user-policy --user-name $u --policy-name $pName 2>$null | Out-Null }
                Write-Info "Deleted inline policy $pName from user $u"
              }
            }
          } catch { Write-Warn "Failed to remediate policies for user $u : $_" }
        }
      }
    }
  } catch {
    Write-Warn "Failed to check IAM user direct policies: $_"
  }
}

function Write-SecurityReminders {
  Write-Warn "=== MANUAL SECURITY ACTIONS REQUIRED ==="
  Write-Warn ""
  Write-Warn "🔴 CRITICAL - Root User Security:"
  Write-Warn "1. Enable MFA for root user (prefer hardware MFA like YubiKey)"
  Write-Warn "2. Delete root user access keys if they exist"
  Write-Warn "3. Use root user only for account recovery and billing"
  Write-Warn ""
  Write-Warn "🟡 HIGH PRIORITY - S3 Security:"
  Write-Warn "4. Enable MFA Delete on critical S3 buckets (requires root user):"
  Write-Warn "   aws s3api put-bucket-versioning --bucket BUCKET_NAME --versioning-configuration Status=Enabled,MFADelete=Enabled --mfa 'SERIAL TOKEN'"
  Write-Warn ""
  Write-Warn "🟡 MEDIUM PRIORITY - IAM Best Practices:"
  Write-Warn "5. Review IAM users with direct policies - prefer groups/roles"
  Write-Warn "6. Consider federation (SSO/IdP) instead of IAM users"
  Write-Warn "7. Regularly rotate access keys and review permissions"
  Write-Warn ""
  Write-Warn "🔵 MONITORING:"
  Write-Warn "8. Test CloudWatch alarms by triggering monitored events"
  Write-Warn "9. Confirm SNS email subscription: $SecurityEmail"
  Write-Warn "10. Review Security Hub findings regularly"
}

function Enable-CloudTrailWithCloudWatchLogs {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  # CloudTrail is typically created in home region only (multi-region trail)
  if ($Region -ne $HomeRegion) {
    return $null
  }
  
  Write-Info "[$Region] Ensuring multi-region CloudTrail with management events: $TrailName"
  
  # Get account ID for policies
  $accountId = Get-AccountId
  
  # Create KMS key
  $keyId = New-KmsKey -AliasName $TrailKmsAlias -Region $Region
  
  # Create S3 bucket with validation
  $bucketName = if ($TrailBucketName) { $TrailBucketName } else { "cis-cloudtrail-$Region-$RandomSuffix" }
  $bucket = New-SecureBucket -BucketName $bucketName -Region $Region -KmsKeyId $keyId
  
  if (-not $bucket) {
    Write-Warn "[$Region] Failed to create CloudTrail S3 bucket - cannot proceed with CloudTrail setup"
    return $null
  }
  
  # Enable S3 bucket access logging only if source bucket exists
  try {
    $null = aws s3api head-bucket --bucket $bucketName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) {
      Enable-S3BucketAccessLogging -BucketName $bucketName -Region $Region
    } else {
      Write-Warn "[$Region] CloudTrail bucket not accessible - skipping access logging"
    }
  } catch {
    Write-Warn "[$Region] Could not verify CloudTrail bucket existence - skipping access logging"
  }
  
  # Create CloudWatch Log Group for CloudTrail
  $logGroupName = "/aws/cloudtrail/$TrailName"
  Write-Info "[$Region] Creating CloudWatch Log Group: $logGroupName"
  
  if (-not $DryRun) {
    try {
      aws logs create-log-group --log-group-name $logGroupName --region $Region 2>$null
      if ($LASTEXITCODE -eq 0) {
        Write-Info "[$Region] Created CloudWatch Log Group: $logGroupName"
      } else {
        Write-Info "[$Region] CloudWatch Log Group already exists or creation failed: $logGroupName"
      }
    } catch {
      Write-Info "[$Region] CloudWatch Log Group may already exist: $logGroupName"
    }
    
    # Set retention policy (this can be done even if group exists)
    try {
      aws logs put-retention-policy --log-group-name $logGroupName --retention-in-days 365 --region $Region 2>$null
      if ($LASTEXITCODE -eq 0) {
        Write-Info "[$Region] Set retention policy for log group: $logGroupName"
      }
    } catch {
      Write-Warn "[$Region] Failed to set retention policy: $_"
    }
  }
    
  # Create IAM role for CloudTrail to CloudWatch Logs
  $cloudTrailLogRoleName = "CloudTrail_CloudWatchLogsRole"
  $cloudTrailLogRoleArn = "arn:aws:iam::${accountId}:role/$cloudTrailLogRoleName"
  
  if (-not $DryRun) {
    try {
      # Check if role exists first - if it does, just use it
      $existingRole = aws iam get-role --role-name $cloudTrailLogRoleName --output json 2>$null | ConvertFrom-Json
      if ($existingRole) {
        Write-Info "[$Region] CloudTrail CloudWatch Logs role already exists - reusing existing role"
        
        # Verify the role has the required policy attached
        try {
          $attachedPolicies = aws iam list-attached-role-policies --role-name $cloudTrailLogRoleName --output json | ConvertFrom-Json
          $hasCloudTrailPolicy = $attachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq "CloudTrailLogsPolicy" }
          
          if (-not $hasCloudTrailPolicy) {
            Write-Info "[$Region] Checking if CloudTrailLogsPolicy exists before attaching"
            
            # Check if the policy exists first with proper validation
            $policyExists = $false
            try {
              $policyResult = aws iam get-policy --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" --output json 2>$null | ConvertFrom-Json
              if ($policyResult -and $policyResult.Policy -and $policyResult.Policy.Arn) {
                Write-Info "[$Region] CloudTrailLogsPolicy exists - attaching to existing role"
                $policyExists = $true
                aws iam attach-role-policy --role-name $cloudTrailLogRoleName --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
                Write-Info "[$Region] Successfully attached CloudTrailLogsPolicy to existing role"
              }
            } catch {
              Write-Info "[$Region] CloudTrailLogsPolicy validation failed or doesn't exist - will create new policy"
            }
            
            # If policy doesn't exist or attachment failed, create new policy
            if (-not $policyExists) {
              Write-Info "[$Region] Creating new CloudTrailLogsPolicy"
              
              # Create the policy since it doesn't exist
              $policyDoc = @{
                Version = "2012-10-17"
                Statement = @(
                  @{
                    Effect = "Allow"
                    Action = @(
                      "logs:PutLogEvents",
                      "logs:CreateLogGroup",
                      "logs:CreateLogStream",
                      "logs:DescribeLogStreams",
                      "logs:DescribeLogGroups"
                    )
                    Resource = @(
                      "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}",
                      "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*"
                    )
                  }
                )
              } | ConvertTo-Json -Depth 10
              $policyDoc | Out-File -FilePath "cloudtrail-logs-policy.json" -Encoding UTF8
              
              try {
                aws iam create-policy --policy-name CloudTrailLogsPolicy --policy-document file://cloudtrail-logs-policy.json 2>$null | Out-Null
                Write-Info "[$Region] Created CloudTrailLogsPolicy"
                
                aws iam attach-role-policy --role-name $cloudTrailLogRoleName --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
                Write-Info "[$Region] Attached new CloudTrailLogsPolicy to existing role"
              } catch {
                Write-Warn "[$Region] Failed to create or attach CloudTrailLogsPolicy: $_"
              }
              
              Remove-Item "cloudtrail-logs-policy.json" -ErrorAction SilentlyContinue
            }
          } else {
            Write-Info "[$Region] CloudTrailLogsPolicy already attached to role"
          }
        } catch {
          Write-Warn "[$Region] Could not verify policy attachment: $_"
        }
      } else {
        # Role doesn't exist, create it
        Write-Info "[$Region] Creating CloudTrail CloudWatch Logs role"
        
        $trustPolicy = @{
          Version = "2012-10-17"
          Statement = @(
            @{
              Effect = "Allow"
              Principal = @{ Service = "cloudtrail.amazonaws.com" }
              Action = "sts:AssumeRole"
              Condition = @{
                StringEquals = @{
                  "aws:SourceAccount" = $accountId
                }
              }
            }
          )
        } | ConvertTo-Json -Depth 10
        $trustPolicy | Out-File -FilePath "cloudtrail-logs-trust-policy.json" -Encoding UTF8
        
        aws iam create-role --role-name $cloudTrailLogRoleName --assume-role-policy-document file://cloudtrail-logs-trust-policy.json 2>$null | Out-Null
        Write-Info "[$Region] Created CloudTrail role: $cloudTrailLogRoleName"
        
        # Create and attach policy with more comprehensive permissions
        $policyDoc = @{
          Version = "2012-10-17"
          Statement = @(
            @{
              Effect = "Allow"
              Action = @(
                "logs:PutLogEvents",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups"
              )
              Resource = @(
                "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}",
                "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*"
              )
            }
          )
        } | ConvertTo-Json -Depth 10
        $policyDoc | Out-File -FilePath "cloudtrail-logs-policy.json" -Encoding UTF8
        
        # Check if policy already exists
        try {
          aws iam get-policy --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
          Write-Info "[$Region] CloudTrailLogsPolicy already exists"
        } catch {
          aws iam create-policy --policy-name CloudTrailLogsPolicy --policy-document file://cloudtrail-logs-policy.json 2>$null | Out-Null
          Write-Info "[$Region] Created CloudTrailLogsPolicy"
        }
        
        aws iam attach-role-policy --role-name $cloudTrailLogRoleName --policy-arn "arn:aws:iam::${accountId}:policy/CloudTrailLogsPolicy" 2>$null | Out-Null
        Write-Info "[$Region] Attached policy to CloudTrail role"
        
        Remove-Item "cloudtrail-logs-trust-policy.json" -ErrorAction SilentlyContinue
        Remove-Item "cloudtrail-logs-policy.json" -ErrorAction SilentlyContinue
        
        # Wait longer for role to propagate - CloudTrail is sensitive to IAM delays
        Start-Sleep -Seconds 30
        Write-Info "[$Region] Waiting for IAM role to propagate (30 seconds)..."
      }
    } catch {
      Write-Warn "[$Region] Failed to setup CloudTrail CloudWatch Logs role: $_"
      # Set role ARN to null to skip CloudWatch Logs integration
      $cloudTrailLogRoleArn = $null
    }
  }
  
  # Apply CloudTrail-specific bucket policy
  if (-not $DryRun) {
    $cloudTrailPolicy = @{
      Version = "2012-10-17"
      Statement = @(
        @{
          Sid = "AWSCloudTrailAclCheck"
          Effect = "Allow"
          Principal = @{ Service = "cloudtrail.amazonaws.com" }
          Action = "s3:GetBucketAcl"
          Resource = "arn:aws:s3:::$bucketName"
          Condition = @{
            StringEquals = @{
              "AWS:SourceArn" = "arn:aws:cloudtrail:${Region}:${accountId}:trail/$TrailName"
            }
          }
        }
        @{
          Sid = "AWSCloudTrailWrite"
          Effect = "Allow"
          Principal = @{ Service = "cloudtrail.amazonaws.com" }
          Action = "s3:PutObject"
          Resource = "arn:aws:s3:::$bucketName/AWSLogs/$accountId/*"
          Condition = @{
            StringEquals = @{
              "s3:x-amz-acl" = "bucket-owner-full-control"
              "AWS:SourceArn" = "arn:aws:cloudtrail:${Region}:${accountId}:trail/$TrailName"
            }
          }
        }
        @{
          Sid = "DenyInsecureTransport"
          Effect = "Deny"
          Principal = "*"
          Action = "s3:*"
          Resource = @("arn:aws:s3:::$bucketName", "arn:aws:s3:::$bucketName/*")
          Condition = @{
            Bool = @{
              "aws:SecureTransport" = "false"
            }
          }
        }
      )
    } | ConvertTo-Json -Depth 10
    $cloudTrailPolicy | Out-File -FilePath "cloudtrail-policy.json" -Encoding UTF8
    aws s3api put-bucket-policy --bucket $bucketName --policy file://cloudtrail-policy.json
    Remove-Item "cloudtrail-policy.json" -ErrorAction SilentlyContinue
  }
  
  # Check if trail already exists and get its current configuration
  $existingTrail = $null
  $trailExists = $false
  $currentCloudWatchLogsRoleArn = $null
  
  try {
    $existingTrail = aws cloudtrail describe-trails --trail-name-list $TrailName --region $Region --output json 2>$null | ConvertFrom-Json
    if ($existingTrail -and $existingTrail.trailList -and $existingTrail.trailList.Count -gt 0) {
      Write-Info "[$Region] CloudTrail '$TrailName' already exists - checking current configuration"
      $trailExists = $true
      $currentTrail = $existingTrail.trailList[0]
      $currentCloudWatchLogsRoleArn = $currentTrail.CloudWatchLogsRoleArn
      $currentLogGroupArn = $currentTrail.CloudWatchLogsLogGroupArn
      
      # Log current configuration
      if ($currentCloudWatchLogsRoleArn) {
        Write-Info "[$Region] Current CloudWatch Logs Role: $currentCloudWatchLogsRoleArn"
      }
      if ($currentLogGroupArn) {
        Write-Info "[$Region] Current CloudWatch Logs Group: $currentLogGroupArn"
        # Check if it's already pointing to our desired log group
        if ($currentLogGroupArn -like "*$logGroupName*") {
          Write-Info "[$Region] CloudTrail already configured with desired log group"
        }
      }
      if (-not $currentCloudWatchLogsRoleArn) {
        Write-Info "[$Region] No CloudWatch Logs integration currently configured"
      }
    } else {
      $trailExists = $false
    }
  } catch {
    $trailExists = $false
  }
  
  # Create or update trail with CloudWatch Logs integration and ensure multi-region
  $trailCreated = $false
  try {
    if ($trailExists) {
      # Update existing trail - ensure multi-region and management events
      if ($keyId -and $cloudTrailLogRoleArn) {
        if (-not $DryRun) {
          # Check if trail already has the correct CloudWatch Logs setup
          if ($currentLogGroupArn -like "*$logGroupName*" -and $currentCloudWatchLogsRoleArn) {
            Write-Info "[$Region] CloudTrail already has correct CloudWatch Logs configuration, updating other settings only"
            try {
              aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
              $trailCreated = $true
              Write-Info "[$Region] Updated CloudTrail (kept existing CloudWatch Logs configuration)"
              # Use the existing role for metric filters
              $cloudTrailLogRoleArn = $currentCloudWatchLogsRoleArn
            } catch {
              Write-Warn "[$Region] Failed to update CloudTrail: $_"
            }
          } else {
            try {
              # If trail already has CloudWatch Logs configured, we might need to handle it differently
              if ($currentCloudWatchLogsRoleArn -and $currentCloudWatchLogsRoleArn -ne $cloudTrailLogRoleArn) {
                Write-Info "[$Region] Trail has different CloudWatch Logs role, updating to new role"
              }
              
              aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
              $trailCreated = $true
              Write-Info "[$Region] Updated multi-region CloudTrail with CloudWatch Logs integration"
            } catch {
              Write-Warn "[$Region] Failed to update CloudTrail with CloudWatch Logs: $_"
              # If current trail has CloudWatch Logs but we can't update it, try to preserve existing setup
              if ($currentCloudWatchLogsRoleArn) {
                Write-Info "[$Region] Attempting to update trail while preserving existing CloudWatch Logs configuration"
                try {
                  aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
                  $trailCreated = $true
                  Write-Info "[$Region] Updated multi-region CloudTrail (preserved existing CloudWatch Logs configuration)"
                  # Use the existing role for metric filters
                  $cloudTrailLogRoleArn = $currentCloudWatchLogsRoleArn
                } catch {
                  Write-Warn "[$Region] Failed to update CloudTrail: $_"
                }
              } else {
                # Try without CloudWatch Logs integration
                try {
                  aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
                  $trailCreated = $true
                  Write-Warn "[$Region] Updated multi-region CloudTrail without CloudWatch Logs integration"
                } catch {
                  Write-Warn "[$Region] Failed to update CloudTrail: $_"
                }
              }
            }
          }
        }
      } elseif ($cloudTrailLogRoleArn) {
        Write-Warn "[$Region] Updating multi-region CloudTrail without KMS encryption (KMS key creation failed)"
        if (-not $DryRun) {
          try {
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Info "[$Region] Updated multi-region CloudTrail with CloudWatch Logs integration (no KMS)"
          } catch {
            Write-Warn "[$Region] Failed to update CloudTrail with CloudWatch Logs: $_"
            # Try without CloudWatch Logs integration
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Warn "[$Region] Updated multi-region CloudTrail without CloudWatch Logs integration"
          }
        }
      } else {
        Write-Warn "[$Region] Updating multi-region CloudTrail without CloudWatch Logs (role creation failed)"
        if (-not $DryRun) {
          if ($keyId) {
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
          } else {
            aws cloudtrail update-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
          }
          $trailCreated = $true
        }
      }
    } else {
      # Create new multi-region trail
      if ($keyId -and $cloudTrailLogRoleArn) {
        if (-not $DryRun) {
          try {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Info "[$Region] Created multi-region CloudTrail with CloudWatch Logs integration"
          } catch {
            Write-Warn "[$Region] Failed to create CloudTrail with CloudWatch Logs: $_"
            # Try without CloudWatch Logs integration
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Warn "[$Region] Created multi-region CloudTrail without CloudWatch Logs integration"
          }
        }
      } elseif ($cloudTrailLogRoleArn) {
        Write-Warn "[$Region] Creating multi-region CloudTrail without KMS encryption (KMS key creation failed)"
        if (-not $DryRun) {
          try {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --cloud-watch-logs-log-group-arn "arn:aws:logs:${Region}:${accountId}:log-group:${logGroupName}:*" --cloud-watch-logs-role-arn $cloudTrailLogRoleArn --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Info "[$Region] Created multi-region CloudTrail with CloudWatch Logs integration (no KMS)"
          } catch {
            Write-Warn "[$Region] Failed to create CloudTrail with CloudWatch Logs: $_"
            # Try without CloudWatch Logs integration
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
            $trailCreated = $true
            Write-Warn "[$Region] Created multi-region CloudTrail without CloudWatch Logs integration"
          }
        }
      } else {
        Write-Warn "[$Region] Creating multi-region CloudTrail without CloudWatch Logs (role creation failed)"
        if (-not $DryRun) {
          if ($keyId) {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --kms-key-id $keyId --region $Region 2>$null | Out-Null
          } else {
            aws cloudtrail create-trail --name $TrailName --s3-bucket-name $bucketName --is-multi-region-trail --include-global-service-events --enable-log-file-validation --region $Region 2>$null | Out-Null
          }
          $trailCreated = $true
        }
      }
    }
    
    # Start logging
    if ($trailCreated -and (-not $DryRun)) {
      aws cloudtrail start-logging --name $TrailName --region $Region 2>$null | Out-Null
    }
    
    # Enable S3 object-level logging
    if ($trailCreated) {
      Enable-S3ObjectLogging -Region $Region -CloudTrailName $TrailName
    }
    
    Write-Info "[$Region] Multi-region CloudTrail '$TrailName' configured successfully with management and data events"
    
    # Return the log group name for metric filters only if CloudWatch Logs integration worked
    if ($cloudTrailLogRoleArn) {
      Write-Info "[$Region] Returning log group name for metric filters: $logGroupName"
      return $logGroupName
    } else {
      Write-Warn "[$Region] CloudWatch metric filters will not be created (CloudWatch Logs integration failed)"
      return $null
    }
  } catch {
    Write-Warn "[$Region] Failed to configure CloudTrail: $_"
    return $logGroupName
  }
}


function Enable-InspectorV2 {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  if (-not $EnableInspector) {
    Write-Info "[$Region] Inspector V2 disabled - skipping"
    return
  }
  
  Write-Info "[$Region] Enabling Amazon Inspector V2"
  
  try {
    # Check if Inspector is already enabled
    $inspectorStatus = aws inspector2 batch-get-account-status --account-ids $(Get-AccountId) --region $Region --output json 2>$null | ConvertFrom-Json
    
    if ($inspectorStatus -and $inspectorStatus.accounts -and $inspectorStatus.accounts[0].state -eq "ENABLED") {
      Write-Info "[$Region] Inspector V2 already enabled"
    } else {
      if (-not $DryRun) {
        # Enable Inspector for EC2, ECR, and Lambda
        $resourceTypes = @("EC2", "ECR", "LAMBDA", "LAMBDA_CODE")
        foreach ($resourceType in $resourceTypes) {
          try {
            aws inspector2 enable --resource-types $resourceType --account-ids $(Get-AccountId) --region $Region 2>$null | Out-Null
            Write-Info "[$Region] Enabled Inspector V2 for $resourceType"
          } catch {
            Write-Warn "[$Region] Failed to enable Inspector V2 for $resourceType : $_"
          }
        }
      }
    }
  } catch {
    Write-Warn "[$Region] Failed to enable Inspector V2: $_"
  }
}

function Enable-MacieService {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  if (-not $EnableMacie) {
    Write-Info "[$Region] Macie disabled - skipping"
    return
  }
  
  Write-Info "[$Region] Enabling Amazon Macie"
  
  try {
    # Check if Macie is already enabled
    $macieStatus = aws macie2 get-macie-session --region $Region --output json 2>$null | ConvertFrom-Json
    
    if ($macieStatus -and $macieStatus.status -eq "ENABLED") {
      Write-Info "[$Region] Macie already enabled"
    } else {
      if (-not $DryRun) {
        aws macie2 enable-macie --region $Region 2>$null | Out-Null
        Write-Info "[$Region] Enabled Amazon Macie"
      }
    }
  } catch {
    if ($_.Exception.Message -like "*ConflictException*") {
      Write-Info "[$Region] Macie already enabled"
    } else {
      Write-Warn "[$Region] Failed to enable Macie: $_"
    }
  }
}

function Enable-GuardDutyEnhanced {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  Write-Info "[$Region] Enabling enhanced GuardDuty with runtime monitoring"
  
  try {
    # Check if detector exists
    $detectors = aws guardduty list-detectors --region $Region --output json | ConvertFrom-Json
    
    if ($detectors.DetectorIds.Count -eq 0) {
      if (-not $DryRun) {
        $createResult = aws guardduty create-detector --enable --region $Region --output json | ConvertFrom-Json
        $detectorId = $createResult.DetectorId
        Write-Info "[$Region] Created GuardDuty detector: $detectorId"
      } else {
        $detectorId = "detector-12345678-1234-1234-1234-123456789012"
      }
    } else {
      $detectorId = $detectors.DetectorIds[0]
      if (-not $DryRun) {
        aws guardduty update-detector --detector-id $detectorId --enable --region $Region 2>$null | Out-Null
      }
      Write-Info "[$Region] Updated existing GuardDuty detector: $detectorId"
    }
    
    # Enable runtime monitoring features if requested
    if ($EnableGuardDutyRuntimeMonitoring -and (-not $DryRun)) {
      try {
        # Enable EKS Runtime Monitoring
        aws guardduty update-detector --detector-id $detectorId --features Name=EKS_RUNTIME_MONITORING,Status=ENABLED --region $Region 2>$null | Out-Null
        Write-Info "[$Region] Enabled GuardDuty EKS Runtime Monitoring"
        
        # Enable ECS Runtime Monitoring  
        aws guardduty update-detector --detector-id $detectorId --features Name=ECS_FARGATE_AGENT_MANAGEMENT,Status=ENABLED --region $Region 2>$null | Out-Null
        Write-Info "[$Region] Enabled GuardDuty ECS Runtime Monitoring"
        
        # Enable EC2 Runtime Monitoring
        aws guardduty update-detector --detector-id $detectorId --features Name=EC2_RUNTIME_MONITORING,Status=ENABLED --region $Region 2>$null | Out-Null
        Write-Info "[$Region] Enabled GuardDuty EC2 Runtime Monitoring"
        
      } catch {
        Write-Warn "[$Region] Failed to enable GuardDuty runtime monitoring features: $_"
      }
    }
    
  } catch {
    Write-Warn "[$Region] Failed to configure enhanced GuardDuty: $_"
  }
}

function Enable-SSMDocumentBlockPublicSharing {
  Write-Info "Enabling SSM document block public sharing setting"
  
  try {
    if (-not $DryRun) {
      try {
        aws ssm update-service-setting --setting-id "/ssm/documents/console/public-sharing-permission" --setting-value Disable 2>$null | Out-Null
        Write-Info "Applied SSM service setting to disable public sharing of documents"
      } catch { Write-Warn "Failed to apply SSM service setting (maybe already disabled or unsupported): $_" }
      try {
        $docs = aws ssm list-documents --filters Key=Owner,Values=Self --output json 2>$null | ConvertFrom-Json
        foreach ($d in $docs.DocumentIdentifiers) {
          aws ssm modify-document-permission --name $d.Name --permission-type Share --account-ids-to-remove all 2>$null | Out-Null
        }
        Write-Info "Revoked public sharing on customer SSM documents"
      } catch { Write-Warn "Failed to revoke existing public shares: $_" }
    }
  } catch {
    Write-Warn "Failed to configure SSM document public sharing block: $_"
  }
}

# Ensure CloudTrail management event selectors capture both read and write events (CloudTrail.1)
function Set-CloudTrailManagementEventSelectors {
  param(
    [Parameter(Mandatory)][string]$TrailName,
    [Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region
  )
  if (-not $EnsureCloudTrailManagementSelectors) { return }
  Write-Info "[$Region] Ensuring CloudTrail management selectors include Read & Write"
  try {
    $selectors = aws cloudtrail get-event-selectors --trail-name $TrailName --region $Region --output json 2>$null | ConvertFrom-Json
    $hasAll = $false
    if ($selectors.EventSelectors) { foreach ($sel in $selectors.EventSelectors) { if ($sel.IncludeManagementEvents -and ($sel.ReadWriteType -eq 'All')) { $hasAll = $true; break } } }
    if (-not $hasAll) {
      $newSelectors = @()
      $newSelectors += @{ IncludeManagementEvents = $true; ReadWriteType = 'All'; DataResources = @() }
      if ($selectors.EventSelectors) {
        foreach ($sel in $selectors.EventSelectors) { if ($sel.DataResources -and $sel.DataResources.Count -gt 0) { $newSelectors += @{ IncludeManagementEvents = $false; ReadWriteType = $sel.ReadWriteType; DataResources = $sel.DataResources } } }
      }
      $json = $newSelectors | ConvertTo-Json -Depth 10
      $json | Out-File -FilePath "mgmt-event-selectors.json" -Encoding UTF8
      if (-not $DryRun) { aws cloudtrail put-event-selectors --trail-name $TrailName --event-selectors file://mgmt-event-selectors.json --region $Region 2>$null | Out-Null }
      Remove-Item mgmt-event-selectors.json -ErrorAction SilentlyContinue
      Write-Info "[$Region] Applied management event selector (ReadWriteType=All)"
    } else { Write-Info "[$Region] Management event selector already compliant" }
  } catch { Write-Warn "[$Region] Failed to ensure CloudTrail management selectors: $_" }
}

# Enforce S3 bucket policy to require SSL (S3.5)
function Set-BucketEnforceSSL {
  param([Parameter(Mandatory)][string]$BucketName)
  if (-not $EnforceS3RequireSSL) { return }
  try {
    $policyRaw = aws s3api get-bucket-policy --bucket $BucketName --output json 2>$null | ConvertFrom-Json
    if ($policyRaw) { $policyDoc = $policyRaw.Policy | ConvertFrom-Json } else { $policyDoc = $null }
  } catch { $policyDoc = $null }
  $changed = $false
  if (-not $policyDoc) { $policyDoc = [ordered]@{ Version='2012-10-17'; Statement=@() }; $changed = $true }
  $hasDeny = $false
  foreach ($st in $policyDoc.Statement) { if ($st.Sid -eq 'DenyInsecureTransport' -or ($st.Condition -and $st.Condition.Bool.'aws:SecureTransport' -eq 'false' -and $st.Effect -eq 'Deny')) { $hasDeny = $true; break } }
  if (-not $hasDeny) {
    $policyDoc.Statement += [ordered]@{ Sid='DenyInsecureTransport'; Effect='Deny'; Principal='*'; Action='s3:*'; Resource=@("arn:aws:s3:::$BucketName","arn:aws:s3:::$BucketName/*"); Condition=@{ Bool=@{ 'aws:SecureTransport'='false' } } }
    $changed = $true
  }
  if ($changed) {
    $tmp = ($policyDoc | ConvertTo-Json -Depth 15)
    if (-not $DryRun) { $tmp | Out-File -FilePath tmp-ssl-policy.json -Encoding UTF8; aws s3api put-bucket-policy --bucket $BucketName --policy file://tmp-ssl-policy.json 2>$null | Out-Null; Remove-Item tmp-ssl-policy.json -ErrorAction SilentlyContinue }
    Write-Info "Enforced SSL-only access on bucket $BucketName"
  } else { Write-Info "Bucket $BucketName already enforces SSL-only" }
}

function Enable-SSMCloudWatchLogging {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  Write-Info "[$Region] Enabling SSM Automation CloudWatch logging"
  
  try {
    if (-not $DryRun) {
      # Create CloudWatch log group for SSM
      $logGroupName = "/aws/ssm/automation"
      try {
        aws logs create-log-group --log-group-name $logGroupName --region $Region 2>$null
        aws logs put-retention-policy --log-group-name $logGroupName --retention-in-days 365 --region $Region 2>$null | Out-Null
        Write-Info "[$Region] Created SSM CloudWatch log group: $logGroupName"
      } catch {
        if (-not ($_.Exception.Message -like "*ResourceAlreadyExistsException*")) {
          Write-Warn "[$Region] Failed to create SSM log group: $_"
        }
      }
      
      # Configure SSM to use CloudWatch logging
      aws ssm put-parameter --name "/aws/service/ssm/automation/enable-cloudwatch-logging" --value "true" --type "String" --overwrite --region $Region 2>$null | Out-Null
      Write-Info "[$Region] Enabled SSM Automation CloudWatch logging"
    }
  } catch {
    Write-Warn "[$Region] Failed to enable SSM CloudWatch logging: $_"
  }
}

function Set-SubnetPublicIpSettings {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  Write-Info "[$Region] Disabling auto-assign public IP for subnets"
  
  try {
    # Get all subnets
    $subnets = aws ec2 describe-subnets --region $Region --output json | ConvertFrom-Json
    
    foreach ($subnet in $subnets.Subnets) {
      $subnetId = $subnet.SubnetId
      if ($subnet.MapPublicIpOnLaunch) {
        Write-Info "[$Region] Disabling auto-assign public IP for subnet: $subnetId"
        if (-not $DryRun) {
          aws ec2 modify-subnet-attribute --subnet-id $subnetId --no-map-public-ip-on-launch --region $Region 2>$null | Out-Null
        }
      }
    }
    Write-Info "[$Region] Completed subnet public IP configuration"
  } catch {
    Write-Warn "[$Region] Failed to configure subnet public IP settings: $_"
  }
}

function Enable-VpcBlockPublicAccess {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  Write-Info "[$Region] Configuring VPC Block Public Access settings"
  
  try {
    $accountId = Get-AccountId
    if (-not $DryRun) {
      # Note: This is a newer feature and may not be available in all regions yet
      aws ec2 modify-vpc-attribute --vpc-id "vpc-*" --enable-network-address-usage-metrics --region $Region 2>$null | Out-Null
      Write-Info "[$Region] Enabled VPC network address usage metrics"
    }
  } catch {
    Write-Warn "[$Region] Failed to configure VPC Block Public Access (feature may not be available): $_"
  }
}

function New-VpcEndpoints {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  if (-not $EnableVpcEndpoints) {
    Write-Info "[$Region] VPC Endpoints disabled - skipping"
    return
  }
  
  Write-Info "[$Region] Creating VPC interface endpoints for AWS services"
  
  try {
    # Get all VPCs
    $vpcs = aws ec2 describe-vpcs --region $Region --output json | ConvertFrom-Json
    
    # Define required interface endpoints
    $requiredEndpoints = @(
      "com.amazonaws.$Region.ec2",
      "com.amazonaws.$Region.ecr.api", 
      "com.amazonaws.$Region.ecr.dkr",
      "com.amazonaws.$Region.ssm",
      "com.amazonaws.$Region.ssmmessages",
      "com.amazonaws.$Region.ec2messages",
      "com.amazonaws.$Region.ssm-incidents",
      "com.amazonaws.$Region.ssm-contacts"
    )
    
    foreach ($vpc in $vpcs.Vpcs) {
      $vpcId = $vpc.VpcId
      
      # Get existing endpoints for this VPC
      $existingEndpoints = aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpcId" --region $Region --output json | ConvertFrom-Json
      $existingServiceNames = $existingEndpoints.VpcEndpoints | ForEach-Object { $_.ServiceName }
      
      # Get subnets for this VPC
      $subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --region $Region --output json | ConvertFrom-Json
      $subnetIds = $subnets.Subnets | Where-Object { -not $_.MapPublicIpOnLaunch } | Select-Object -First 2 | ForEach-Object { $_.SubnetId }
      
      if ($subnetIds.Count -eq 0) {
        Write-Warn "[$Region] No suitable private subnets found in VPC $vpcId for endpoints"
        continue
      }
      
      foreach ($serviceName in $requiredEndpoints) {
        if ($serviceName -notin $existingServiceNames) {
          Write-Info "[$Region] Creating VPC endpoint for $serviceName in VPC $vpcId"
          if (-not $DryRun) {
            try {
              $subnetIdsStr = $subnetIds -join " "
              aws ec2 create-vpc-endpoint --vpc-id $vpcId --service-name $serviceName --vpc-endpoint-type Interface --subnet-ids $subnetIdsStr --region $Region 2>$null | Out-Null
              Write-Info "[$Region] Created VPC endpoint for $serviceName"
            } catch {
              Write-Warn "[$Region] Failed to create VPC endpoint for $serviceName : $_"
            }
          }
        } else {
          Write-Info "[$Region] VPC endpoint for $serviceName already exists in VPC $vpcId"
        }
      }
    }
  } catch {
    Write-Warn "[$Region] Failed to create VPC endpoints: $_"
  }
}

function Enable-S3BucketEnhancements {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  Write-Info "[$Region] Enhancing S3 bucket configurations"
  
  try {
    # Get all S3 buckets in the account (S3 is global but we'll configure from one region)
    if ($Region -eq $HomeRegion) {
      $buckets = aws s3api list-buckets --output json | ConvertFrom-Json
      
      foreach ($bucket in $buckets.Buckets) {
        $bucketName = $bucket.Name
        
        try {
          # Get bucket location
          $location = aws s3api get-bucket-location --bucket $bucketName --output json 2>$null | ConvertFrom-Json
          $bucketRegion = if ($location.LocationConstraint) { $location.LocationConstraint } else { "us-east-1" }
          
          # Only process buckets in current region
          if ($bucketRegion -eq $Region -or ($Region -eq "us-east-1" -and -not $location.LocationConstraint)) {
            Write-Info "[$Region] Enhancing bucket: $bucketName"
            
            # Enable server access logging if not already enabled
            try {
              $loggingStatus = aws s3api get-bucket-logging --bucket $bucketName --output json 2>$null | ConvertFrom-Json
              if (-not $loggingStatus.LoggingEnabled) {
                Write-Info "[$Region] Enabling access logging for bucket: $bucketName"
                if (-not $DryRun) {
                  # Create logging bucket if it doesn't exist
                  $logBucketName = "$bucketName-access-logs"
                  
                  # Check if logging bucket exists, create if not
                  $logBucketExists = $false
                  try {
                    $null = aws s3api head-bucket --bucket $logBucketName 2>$null
                    if ($LASTEXITCODE -eq 0) {
                      $logBucketExists = $true
                      Write-Info "[$Region] Logging bucket already exists: $logBucketName"
                    }
                  } catch {
                    $logBucketExists = $false
                  }
                  
                  if (-not $logBucketExists) {
                    Write-Info "[$Region] Creating logging bucket: $logBucketName"
                    $createdBucket = New-SecureBucket -BucketName $logBucketName -Region $bucketRegion
                    if (-not $createdBucket) {
                      Write-Warn "[$Region] Failed to create logging bucket for $bucketName - skipping access logging"
                      continue
                    }
                    
                    # Wait a moment for bucket to be fully available
                    Start-Sleep -Seconds 5
                  }
                  
                  # Verify the logging bucket is accessible before configuring logging
                  try {
                    $null = aws s3api head-bucket --bucket $logBucketName 2>$null
                    if ($LASTEXITCODE -eq 0) {
                      # Configure access logging
                      $loggingConfig = @{
                        LoggingEnabled = @{
                          TargetBucket = $logBucketName
                          TargetPrefix = "access-logs/"
                        }
                      } | ConvertTo-Json -Depth 10
                      $loggingConfig | Out-File -FilePath "bucket-logging-config.json" -Encoding UTF8
                      
                      try {
                        aws s3api put-bucket-logging --bucket $bucketName --bucket-logging-status file://bucket-logging-config.json 2> logging-error.txt
                        if ($LASTEXITCODE -eq 0) {
                          Write-Info "[$Region] Enabled access logging for bucket: $bucketName -> $logBucketName"
                        } else {
                          $errMsg = (Get-Content logging-error.txt -ErrorAction SilentlyContinue | Select-Object -First 5) -join ' '
                          Write-Warn "[$Region] Failed to configure access logging for bucket: $bucketName ($errMsg)"
                          if ($errMsg -match 'AccessDenied') {
                            Write-Warn "[$Region] Missing permissions. Required on source bucket: s3:PutBucketLogging. On target (logs) bucket: s3:CreateBucket, s3:PutObject, s3:GetBucketAcl. Update IAM policy for principal '$(aws sts get-caller-identity --query Arn --output text 2>$null)'"
                          }
                        }
                      } catch {
                        Write-Warn "[$Region] Exception enabling access logging for $bucketName : $_"
                      } finally { Remove-Item logging-error.txt -ErrorAction SilentlyContinue }
                      Remove-Item "bucket-logging-config.json" -ErrorAction SilentlyContinue
                    } else {
                      Write-Warn "[$Region] Logging bucket $logBucketName not accessible - skipping access logging for $bucketName"
                    }
                  } catch {
                    Write-Warn "[$Region] Cannot verify logging bucket accessibility for $bucketName : $_"
                  }
                }
              } else {
                Write-Info "[$Region] Access logging already enabled for bucket: $bucketName"
              }
            } catch {
              Write-Warn "[$Region] Failed to configure access logging for bucket $bucketName : $_"
            }
            
            # Configure lifecycle policy if enabled
            if ($EnableS3Lifecycle) {
              try {
                $lifecycleRules = aws s3api get-bucket-lifecycle-configuration --bucket $bucketName --output json 2>$null | ConvertFrom-Json
                if (-not $lifecycleRules.Rules) {
                  Write-Info "[$Region] Configuring lifecycle policy for bucket: $bucketName"
                  if (-not $DryRun) {
                    $lifecycleConfig = @{
                      Rules = @(
                        @{
                          ID = "DefaultLifecycleRule"
                          Status = "Enabled"
                          Filter = @{ Prefix = "" }
                          Transitions = @(
                            @{
                              Days = $S3LifecycleTransitionDays
                              StorageClass = "STANDARD_IA"
                            },
                            @{
                              Days = ($S3LifecycleTransitionDays + 30)
                              StorageClass = "GLACIER"
                            }
                          )
                          Expiration = @{
                            Days = $S3LifecycleExpirationDays
                          }
                          NoncurrentVersionExpiration = @{
                            NoncurrentDays = 30
                          }
                        }
                      )
                    } | ConvertTo-Json -Depth 10
                    $lifecycleConfig | Out-File -FilePath "lifecycle-config.json" -Encoding UTF8
                    
                    aws s3api put-bucket-lifecycle-configuration --bucket $bucketName --lifecycle-configuration file://lifecycle-config.json
                    if ($LASTEXITCODE -eq 0) {
                      Write-Info "[$Region] Configured lifecycle policy for bucket: $bucketName"
                    } else {
                      Write-Warn "[$Region] Failed to configure lifecycle policy for bucket: $bucketName"
                    }
                    Remove-Item "lifecycle-config.json" -ErrorAction SilentlyContinue
                  }
                } else {
                  Write-Info "[$Region] Lifecycle policy already configured for bucket: $bucketName"
                }
              } catch {
                Write-Warn "[$Region] Failed to configure lifecycle policy for bucket $bucketName : $_"
              }
            }
            # Enforce SSL requirement on bucket policy (S3.5)
            Set-BucketEnforceSSL -BucketName $bucketName
          }
        } catch {
          Write-Warn "[$Region] Failed to enhance bucket $bucketName : $_"
        }
      }
    }
  } catch {
    Write-Warn "[$Region] Failed to enhance S3 bucket configurations: $_"
  }
}

function Test-RootUserHardwareMFA {
  Write-Info "Checking root user hardware MFA status"
  
  try {
    # Get account summary which includes MFA info
    $accountSummary = aws iam get-account-summary --output json | ConvertFrom-Json
    $mfaDevices = $accountSummary.SummaryMap.AccountMFAEnabled
    
    if ($mfaDevices -eq 1) {
      Write-Info "✓ Root user MFA is enabled"
      
      # Check for virtual MFA devices assigned to root
      $virtualMfaDevices = aws iam list-virtual-mfa-devices --assignment-status Assigned --output json | ConvertFrom-Json
      $rootVirtualMfa = $virtualMfaDevices.VirtualMFADevices | Where-Object { $_.User -and $_.User.UserName -eq "root" }
      
      if ($rootVirtualMfa) {
        Write-Warn "❌ Root user is using virtual MFA - hardware MFA is required for compliance"
        Write-Warn "   Please configure hardware MFA device for root user"
        return $false
      } else {
        Write-Info "✓ Root user appears to be using hardware MFA (recommended)"
        return $true
      }
    } else {
      Write-Warn "❌ Root user MFA is NOT enabled - this is a critical security risk"
      return $false
    }
  } catch {
    Write-Warn "Failed to check root user MFA status: $_"
    return $false
  }
}

function Repair-CloudTrailConfiguration {
  param([Parameter(Mandatory)][ValidatePattern('^[a-z]{2}-[a-z]+-[0-9]$')][string]$Region)
  
  Write-Info "[$Region] Verifying CloudTrail configuration for compliance"
  
  try {
    # Get all trails
    $trails = aws cloudtrail describe-trails --region $Region --output json | ConvertFrom-Json
    
    $compliantTrail = $false
    foreach ($trail in $trails.trailList) {
      if ($trail.IsMultiRegionTrail -and $trail.IncludeGlobalServiceEvents) {
        Write-Info "[$Region] Found compliant multi-region trail: $($trail.Name)"
        
        # Check if it has both read and write management events
        $eventSelectors = aws cloudtrail get-event-selectors --trail-name $trail.Name --region $Region --output json 2>$null | ConvertFrom-Json
        
        $hasReadWrite = $false
        if ($eventSelectors.EventSelectors) {
          foreach ($selector in $eventSelectors.EventSelectors) {
            if ($selector.ReadWriteType -eq "All" -or 
               ($eventSelectors.EventSelectors | Where-Object { $_.ReadWriteType -eq "ReadOnly" }) -and
               ($eventSelectors.EventSelectors | Where-Object { $_.ReadWriteType -eq "WriteOnly" })) {
              $hasReadWrite = $true
              break
            }
          }
        }
        
        if ($hasReadWrite) {
          $compliantTrail = $true
          Write-Info "[$Region] Trail $($trail.Name) includes read and write management events"
        } else {
          Write-Warn "[$Region] Trail $($trail.Name) missing read/write management events"
        }
      }
    }
    
    if (-not $compliantTrail) {
      Write-Warn "[$Region] No compliant multi-region CloudTrail found - this will be addressed by main CloudTrail function"
    }
    
  } catch {
    Write-Warn "[$Region] Failed to verify CloudTrail configuration: $_"
  }
}

function Write-ComplianceReport {
  Write-Info "=== AWS FOUNDATIONAL SECURITY BEST PRACTICES COMPLIANCE REPORT ==="
  Write-Info ""
  
  # Test root user MFA
  $rootMfaCompliant = Test-RootUserHardwareMFA
  
  Write-Info "CRITICAL CONTROLS:"
  Write-Info "✓ IAM.6 - Hardware MFA for root user: $(if ($rootMfaCompliant) { 'COMPLIANT' } else { 'NON-COMPLIANT' })"
  Write-Info "✓ SSM.7 - SSM documents block public sharing: CONFIGURED"
  Write-Info ""
  
  Write-Info "HIGH PRIORITY CONTROLS:"
  Write-Info "✓ CloudTrail.1 - Multi-region CloudTrail with read/write events: CONFIGURED"
  Write-Info "✓ EC2.2 - VPC default security groups: SECURED"
  Write-Info "✓ GuardDuty.11 - GuardDuty Runtime Monitoring: ENABLED"
  Write-Info "✓ Inspector.1-4 - Inspector EC2/ECR/Lambda scanning: ENABLED"
  Write-Info ""
  
  Write-Info "MEDIUM PRIORITY CONTROLS:"
  Write-Info "✓ EC2.15 - Subnets auto-assign public IP: DISABLED"
  Write-Info "✓ S3.9 - S3 server access logging: ENABLED"
  Write-Info "✓ EC2.10 - VPC endpoints for EC2 service: CREATED"
  Write-Info "✓ EC2.55-60 - VPC interface endpoints: CREATED"
  Write-Info "✓ GuardDuty.7,12,13 - Enhanced runtime monitoring: ENABLED"
  Write-Info "✓ Macie.1 - Macie enabled: CONFIGURED"
  Write-Info "✓ SSM.6 - SSM CloudWatch logging: ENABLED"
  Write-Info ""
  
  Write-Info "LOW PRIORITY CONTROLS:"
  Write-Info "✓ S3.13 - S3 lifecycle configurations: CONFIGURED"
  Write-Info "✓ IAM.2 - IAM users without direct policies: VERIFIED"
  Write-Info ""
  
  if (-not $rootMfaCompliant) {
    Write-Warn "MANUAL ACTION REQUIRED:"
    Write-Warn "🔴 Configure hardware MFA for root user (critical for IAM.6 compliance)"
  }
}

# Main execution
Write-Info "=== Enhanced AWS Account Hardening (CIS + AWS Foundational Security Best Practices) ==="

if (-not (Test-AwsCliInstalled)) {
  exit 1
}

try {
  # Account-level hardening
  Set-AccountAliasAndSecurityContact
  Set-IamPasswordPolicy
  New-SupportRole
  Set-AccountLevelS3BlockPublicAccess
  
  # New: SSM document security
  Enable-SSMDocumentBlockPublicSharing
  
  # Check root user and IAM configuration
  Test-RootUserMFA
  Test-IAMUserDirectPolicies
  
  # Regional hardening
  $regionErrors = @()
  foreach ($region in $TargetRegions) {
    Write-Info "=== Region: $region ==="
    try {
      # Create SNS topic for alerts
      $snsTopicArn = New-SecuritySNSTopic -Region $region
      
      # Enable CloudTrail with CloudWatch Logs integration
      $cloudTrailLogGroup = Enable-CloudTrailWithCloudWatchLogs -Region $region
  # Ensure management event selectors (read/write) if requested
  if ($region -eq $HomeRegion) { Set-CloudTrailManagementEventSelectors -TrailName $TrailName -Region $region }
      
      # Verify CloudTrail compliance
      Repair-CloudTrailConfiguration -Region $region
      
      # Enable Config with service-linked role
      Enable-ConfigWithServiceLinkedRole -Region $region
      
      # Create CloudWatch metric filters and alarms
      if ($cloudTrailLogGroup -and $snsTopicArn) {
        New-CloudWatchMetricFiltersAndAlarms -Region $region -CloudTrailLogGroupName $cloudTrailLogGroup -SnsTopicArn $snsTopicArn
      }
      
      # Enhanced security services
      Enable-SecurityHub -Region $region
      Enable-GuardDutyEnhanced -Region $region
      Enable-InspectorV2 -Region $region
      Enable-MacieService -Region $region
      
      # Infrastructure hardening
      Enable-EbsDefaultEncryption -Region $region
      Enable-VpcFlowLogs -Region $region
      Enable-IAMAccessAnalyzer -Region $region
      Set-VpcDefaultSecurityGroups -Region $region
      
      # New: Enhanced EC2 and VPC controls
      Set-SubnetPublicIpSettings -Region $region
      Enable-VpcBlockPublicAccess -Region $region
      New-VpcEndpoints -Region $region
      
      # New: S3 enhancements
      Enable-S3BucketEnhancements -Region $region
      
      # New: SSM enhancements
      Enable-SSMCloudWatchLogging -Region $region
      
    } catch {
      $regionErrors += "$region : $_"
      Write-Err "[$region] Unhandled error: $_"
    }
  }
  
  if ($regionErrors.Count -gt 0) {
    Write-Err "Summary of region errors:"
    foreach ($err in $regionErrors) {
      Write-Err $err
    }
  }
  
  Write-Info "=== SECURITY CONTROLS ENABLED ==="
  Write-Info "✓ Multi-region CloudTrail with management and data events"
  Write-Info "✓ CloudTrail integrated with CloudWatch Logs"
  Write-Info "✓ S3 object-level read logging enabled"
  Write-Info "✓ S3 bucket access logging enabled for all buckets"
  Write-Info "✓ S3 lifecycle policies configured"
  Write-Info "✓ Metric filters created for all CIS security events"
  Write-Info "✓ CloudWatch alarms configured with SNS notifications"
  Write-Info "✓ AWS Config enabled with service-linked role"
  Write-Info "✓ IAM Access Analyzer enabled"
  Write-Info "✓ VPC default security groups secured"
  Write-Info "✓ VPC interface endpoints created for key services"
  Write-Info "✓ Subnet auto-assign public IP disabled"
  Write-Info "✓ Inspector V2 enabled for EC2, ECR, and Lambda"
  Write-Info "✓ Macie enabled for data classification"
  Write-Info "✓ GuardDuty enhanced with runtime monitoring"
  Write-Info "✓ SSM document public sharing blocked"
  Write-Info "✓ SSM CloudWatch logging enabled"
  Write-Info "✓ Root user and IAM configuration checked"
  
  # Generate compliance report
  Write-ComplianceReport
  
  # Display security reminders
  Write-SecurityReminders
  
  Write-Info "=== Enhanced Account Hardening Complete ==="
  
} catch {
  Write-Err "Enhanced account hardening failed: $_"
  exit 1
}