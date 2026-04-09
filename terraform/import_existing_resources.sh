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

import_if_found() {
  local address="$1"
  local import_id="$2"

  if [ -z "$import_id" ] || [ "$import_id" = "None" ] || [ "$import_id" = "null" ]; then
    return
  fi

  if state_has "$address"; then
    echo "State already has $address"
    return
  fi

  echo "Importing $address <- $import_id"
  terraform import "$address" "$import_id" || true
}

# Core networking
VPC_ID="$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=local-services-vpc --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)"
import_if_found "aws_vpc.main" "$VPC_ID"

PUBLIC_1_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-public-1 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
PUBLIC_2_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-public-2 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
PRIVATE_1_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-private-1 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
PRIVATE_2_ID="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=local-services-private-2 --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"

import_if_found "aws_subnet.public[0]" "$PUBLIC_1_ID"
import_if_found "aws_subnet.public[1]" "$PUBLIC_2_ID"
import_if_found "aws_subnet.private[0]" "$PRIVATE_1_ID"
import_if_found "aws_subnet.private[1]" "$PRIVATE_2_ID"

IGW_ID="$(aws ec2 describe-internet-gateways --filters Name=tag:Name,Values=local-services-igw --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || true)"
import_if_found "aws_internet_gateway.main" "$IGW_ID"

RT_ID="$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=local-services-public-rt --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || true)"
import_if_found "aws_route_table.public" "$RT_ID"

if [ -n "$RT_ID" ] && [ "$RT_ID" != "None" ]; then
  ASSOC_1_ID="$(aws ec2 describe-route-tables --route-table-ids "$RT_ID" --query "RouteTables[0].Associations[?SubnetId=='$PUBLIC_1_ID'].RouteTableAssociationId | [0]" --output text 2>/dev/null || true)"
  ASSOC_2_ID="$(aws ec2 describe-route-tables --route-table-ids "$RT_ID" --query "RouteTables[0].Associations[?SubnetId=='$PUBLIC_2_ID'].RouteTableAssociationId | [0]" --output text 2>/dev/null || true)"

  import_if_found "aws_route_table_association.public[0]" "$ASSOC_1_ID"
  import_if_found "aws_route_table_association.public[1]" "$ASSOC_2_ID"
fi

# Security groups
EC2_SG_ID="$(aws ec2 describe-security-groups --filters Name=group-name,Values=local-services-ec2-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
RDS_SG_ID="$(aws ec2 describe-security-groups --filters Name=group-name,Values=local-services-rds-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"

import_if_found "aws_security_group.ec2" "$EC2_SG_ID"
import_if_found "aws_security_group.rds" "$RDS_SG_ID"

# Compute and IP
KEY_NAME="$(aws ec2 describe-key-pairs --filters Name=key-name,Values=local-services-deployer-${ENVIRONMENT}-* --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || true)"
import_if_found "aws_key_pair.deployer" "$KEY_NAME"

INSTANCE_ID="$(aws ec2 describe-instances --filters Name=tag:Name,Values=local-services-api-server Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || true)"
import_if_found "aws_instance.api" "$INSTANCE_ID"

EIP_ALLOC_ID="$(aws ec2 describe-addresses --filters Name=tag:Name,Values=local-services-api-eip --query 'Addresses[0].AllocationId' --output text 2>/dev/null || true)"
import_if_found "aws_eip.api" "$EIP_ALLOC_ID"

# Database and secrets
DB_SUBNET_GROUP="$(aws rds describe-db-subnet-groups --query 'DBSubnetGroups[].DBSubnetGroupName' --output text 2>/dev/null | tr '\t' '\n' | grep "^local-services-db-subnet-${ENVIRONMENT}-" | head -n1 || true)"
import_if_found "aws_db_subnet_group.main" "$DB_SUBNET_GROUP"

SECRET_ARN="$(aws secretsmanager list-secrets --query "SecretList[?starts_with(Name, 'local-services-db-password-${ENVIRONMENT}-')].ARN | [0]" --output text 2>/dev/null || true)"
import_if_found "aws_secretsmanager_secret.db_password" "$SECRET_ARN"

DB_ID="local-services-postgres-${ENVIRONMENT}"
if aws rds describe-db-instances --db-instance-identifier "$DB_ID" >/dev/null 2>&1; then
  import_if_found "aws_db_instance.postgres" "$DB_ID"
fi

# IAM
EC2_ROLE_NAME="$(aws iam list-roles --query "Roles[?starts_with(RoleName, 'local-services-ec2-role-${ENVIRONMENT}-')].RoleName | [0]" --output text 2>/dev/null || true)"
import_if_found "aws_iam_role.ec2_role" "$EC2_ROLE_NAME"

PROFILE_NAME="$(aws iam list-instance-profiles --query "InstanceProfiles[?starts_with(InstanceProfileName, 'local-services-ec2-profile-${ENVIRONMENT}-')].InstanceProfileName | [0]" --output text 2>/dev/null || true)"
import_if_found "aws_iam_instance_profile.ec2_profile" "$PROFILE_NAME"

if [ -n "$EC2_ROLE_NAME" ] && [ "$EC2_ROLE_NAME" != "None" ]; then
  POLICY_NAME="$(aws iam list-role-policies --role-name "$EC2_ROLE_NAME" --query "PolicyNames[?starts_with(@, 'local-services-ec2-policy-${ENVIRONMENT}-')] | [0]" --output text 2>/dev/null || true)"
  if [ -n "$POLICY_NAME" ] && [ "$POLICY_NAME" != "None" ]; then
    import_if_found "aws_iam_role_policy.ec2_policy" "${EC2_ROLE_NAME}:${POLICY_NAME}"
  fi
fi

RDS_MONITOR_ROLE="$(aws iam list-roles --query "Roles[?starts_with(RoleName, 'ls-rds-monitor-${ENVIRONMENT}-')].RoleName | [0]" --output text 2>/dev/null || true)"
import_if_found "aws_iam_role.rds_monitoring" "$RDS_MONITOR_ROLE"

if [ -n "$RDS_MONITOR_ROLE" ] && [ "$RDS_MONITOR_ROLE" != "None" ]; then
  import_if_found "aws_iam_role_policy_attachment.rds_monitoring" "${RDS_MONITOR_ROLE}/arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
fi

# CloudWatch alarms
import_if_found "aws_cloudwatch_metric_alarm.ec2_cpu" "local-services-ec2-high-cpu"
import_if_found "aws_cloudwatch_metric_alarm.db_cpu" "local-services-rds-high-cpu"

echo "Existing-resource import step completed for environment: $ENVIRONMENT"
