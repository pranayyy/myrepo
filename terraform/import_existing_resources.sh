#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: $0 <development|production>"
  exit 1
fi

state_has() {
  terraform state show "$1" >/dev/null 2>&1
}

is_valid_id() {
  local value="${1:-}"
  [ -n "$value" ] && [ "$value" != "None" ] && [ "$value" != "null" ]
}

state_id() {
  local address="$1"
  if ! state_has "$address"; then
    return
  fi

  terraform state show "$address" 2>/dev/null | awk '/^id[[:space:]]*=/{print $3; exit}' || true
}

ensure_import() {
  local address="$1"
  local import_id="$2"

  if ! is_valid_id "$import_id"; then
    return
  fi

  local existing_state_id
  existing_state_id="$(state_id "$address")"

  if is_valid_id "$existing_state_id" && [ "$existing_state_id" = "$import_id" ]; then
    echo "State already aligned: $address -> $import_id"
    return
  fi

  if is_valid_id "$existing_state_id" && [ "$existing_state_id" != "$import_id" ]; then
    echo "State drift detected for $address: $existing_state_id -> $import_id"
    terraform state rm "$address" || true
  fi

  echo "Importing $address <- $import_id"
  terraform import "$address" "$import_id" || true
}

# Core networking
VPC_ID=""

# Prefer the VPC already tracked in state when valid in AWS.
STATE_VPC_ID="$(state_id aws_vpc.main || true)"
if is_valid_id "$STATE_VPC_ID"; then
  if aws ec2 describe-vpcs --vpc-ids "$STATE_VPC_ID" >/dev/null 2>&1; then
    VPC_ID="$STATE_VPC_ID"
  fi
fi

# Fallback 1: VPC by Name tag.
if ! is_valid_id "$VPC_ID"; then
  VPC_ID="$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=local-services-vpc --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)"
fi

# Fallback 2: VPC by expected CIDR.
if ! is_valid_id "$VPC_ID"; then
  VPC_ID="$(aws ec2 describe-vpcs --filters Name=cidr-block,Values=10.0.0.0/16 --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)"
fi

ensure_import "aws_vpc.main" "$VPC_ID"

PUBLIC_1_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-public-1 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
PUBLIC_2_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-public-2 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
PRIVATE_1_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-private-1 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
PRIVATE_2_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-private-2 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"

if ! is_valid_id "$PUBLIC_1_ID" && is_valid_id "$VPC_ID"; then
  PUBLIC_1_ID="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=10.0.1.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$PUBLIC_1_ID"; then
  PUBLIC_1_ID="$(aws ec2 describe-subnets --filters Name=cidr-block,Values=10.0.1.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$PUBLIC_2_ID" && is_valid_id "$VPC_ID"; then
  PUBLIC_2_ID="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=10.0.2.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$PUBLIC_2_ID"; then
  PUBLIC_2_ID="$(aws ec2 describe-subnets --filters Name=cidr-block,Values=10.0.2.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$PRIVATE_1_ID" && is_valid_id "$VPC_ID"; then
  PRIVATE_1_ID="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=10.0.10.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$PRIVATE_1_ID"; then
  PRIVATE_1_ID="$(aws ec2 describe-subnets --filters Name=cidr-block,Values=10.0.10.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$PRIVATE_2_ID" && is_valid_id "$VPC_ID"; then
  PRIVATE_2_ID="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=cidr-block,Values=10.0.11.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$PRIVATE_2_ID"; then
  PRIVATE_2_ID="$(aws ec2 describe-subnets --filters Name=cidr-block,Values=10.0.11.0/24 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
fi

ensure_import "aws_subnet.public[0]" "$PUBLIC_1_ID"
ensure_import "aws_subnet.public[1]" "$PUBLIC_2_ID"
ensure_import "aws_subnet.private[0]" "$PRIVATE_1_ID"
ensure_import "aws_subnet.private[1]" "$PRIVATE_2_ID"

# Always prefer the IGW already attached to the target VPC.
IGW_ID=""
if is_valid_id "$VPC_ID"; then
  IGW_ID="$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || true)"
fi
if ! is_valid_id "$IGW_ID"; then
  IGW_ID="$(aws ec2 describe-internet-gateways --filters Name=tag:Name,Values=local-services-igw --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || true)"
fi
ensure_import "aws_internet_gateway.main" "$IGW_ID"

RT_ID="$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=local-services-public-rt --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || true)"
if ! is_valid_id "$RT_ID" && is_valid_id "$VPC_ID" && is_valid_id "$IGW_ID"; then
  RT_ID="$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC_ID" Name=route.gateway-id,Values="$IGW_ID" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || true)"
fi
ensure_import "aws_route_table.public" "$RT_ID"

if is_valid_id "$RT_ID"; then
  if is_valid_id "$PUBLIC_1_ID"; then
    ensure_import "aws_route_table_association.public[0]" "${PUBLIC_1_ID}/${RT_ID}"
  fi
  if is_valid_id "$PUBLIC_2_ID"; then
    ensure_import "aws_route_table_association.public[1]" "${PUBLIC_2_ID}/${RT_ID}"
  fi
fi

# Security groups
EC2_SG_ID="$(aws ec2 describe-security-groups --filters Name=group-name,Values=local-services-ec2-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
RDS_SG_ID="$(aws ec2 describe-security-groups --filters Name=group-name,Values=local-services-rds-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"

if is_valid_id "$VPC_ID"; then
  EC2_SG_ID="$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=local-services-ec2-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "$EC2_SG_ID")"
  RDS_SG_ID="$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=local-services-rds-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "$RDS_SG_ID")"
fi

ensure_import "aws_security_group.ec2" "$EC2_SG_ID"
ensure_import "aws_security_group.rds" "$RDS_SG_ID"

# Compute and IP
KEY_NAME="$(aws ec2 describe-key-pairs --filters Name=key-name,Values=local-services-deployer-${ENVIRONMENT}-* --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || true)"
ensure_import "aws_key_pair.deployer" "$KEY_NAME"

INSTANCE_ID="$(aws ec2 describe-instances --filters Name=tag:Name,Values=local-services-api-server Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || true)"
ensure_import "aws_instance.api" "$INSTANCE_ID"

EIP_ALLOC_ID="$(aws ec2 describe-addresses --filters Name=tag:Name,Values=local-services-api-eip --query 'Addresses[0].AllocationId' --output text 2>/dev/null || true)"
ensure_import "aws_eip.api" "$EIP_ALLOC_ID"

# Database and secrets
DB_SUBNET_GROUP="$(aws rds describe-db-subnet-groups --query 'DBSubnetGroups[].DBSubnetGroupName' --output text 2>/dev/null | tr '\t' '\n' | grep "^local-services-db-subnet-${ENVIRONMENT}-" | head -n1 || true)"
ensure_import "aws_db_subnet_group.main" "$DB_SUBNET_GROUP"

SECRET_ARN="$(aws secretsmanager list-secrets --query "SecretList[?starts_with(Name, 'local-services-db-password-${ENVIRONMENT}-')].ARN | [0]" --output text 2>/dev/null || true)"
ensure_import "aws_secretsmanager_secret.db_password" "$SECRET_ARN"

DB_ID="local-services-postgres-${ENVIRONMENT}"
if aws rds describe-db-instances --db-instance-identifier "$DB_ID" >/dev/null 2>&1; then
  ensure_import "aws_db_instance.postgres" "$DB_ID"
fi

# IAM
EC2_ROLE_NAME="$(aws iam list-roles --query "Roles[?starts_with(RoleName, 'local-services-ec2-role-${ENVIRONMENT}-')].RoleName | [0]" --output text 2>/dev/null || true)"
ensure_import "aws_iam_role.ec2_role" "$EC2_ROLE_NAME"

PROFILE_NAME="$(aws iam list-instance-profiles --query "InstanceProfiles[?starts_with(InstanceProfileName, 'local-services-ec2-profile-${ENVIRONMENT}-')].InstanceProfileName | [0]" --output text 2>/dev/null || true)"
ensure_import "aws_iam_instance_profile.ec2_profile" "$PROFILE_NAME"

if is_valid_id "$EC2_ROLE_NAME"; then
  POLICY_NAME="$(aws iam list-role-policies --role-name "$EC2_ROLE_NAME" --query "PolicyNames[?starts_with(@, 'local-services-ec2-policy-${ENVIRONMENT}-')] | [0]" --output text 2>/dev/null || true)"
  if is_valid_id "$POLICY_NAME"; then
    ensure_import "aws_iam_role_policy.ec2_policy" "${EC2_ROLE_NAME}:${POLICY_NAME}"
  fi
fi

RDS_MONITOR_ROLE="$(aws iam list-roles --query "Roles[?starts_with(RoleName, 'ls-rds-monitor-${ENVIRONMENT}-')].RoleName | [0]" --output text 2>/dev/null || true)"
ensure_import "aws_iam_role.rds_monitoring" "$RDS_MONITOR_ROLE"

if is_valid_id "$RDS_MONITOR_ROLE"; then
  ensure_import "aws_iam_role_policy_attachment.rds_monitoring" "${RDS_MONITOR_ROLE}/arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
fi

# CloudWatch alarms
ensure_import "aws_cloudwatch_metric_alarm.ec2_cpu" "local-services-ec2-high-cpu"
ensure_import "aws_cloudwatch_metric_alarm.db_cpu" "local-services-rds-high-cpu"

echo "Existing-resource import step completed for environment: $ENVIRONMENT"
