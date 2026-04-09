#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-}"
if [ -z "$ENVIRONMENT" ]; then
  echo "Usage: $0 <development|production>"
  exit 1
fi

vpc_from_state() {
  terraform state show aws_vpc.main 2>/dev/null | awk '/^id[[:space:]]*=/{print $3; exit}' || true
}

is_valid() {
  local value="${1:-}"
  [ -n "$value" ] && [ "$value" != "None" ] && [ "$value" != "null" ]
}

VPC_ID="$(vpc_from_state)"
if ! is_valid "$VPC_ID"; then
  VPC_ID="$(aws ec2 describe-vpcs --filters Name=cidr-block,Values=10.0.0.0/16 --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)"
fi

if ! is_valid "$VPC_ID"; then
  echo "No VPC found for cleanup"
  exit 0
fi

echo "Cleaning orphaned dependencies in VPC: $VPC_ID"

DB_ID="local-services-postgres-${ENVIRONMENT}"
if aws rds describe-db-instances --db-instance-identifier "$DB_ID" >/dev/null 2>&1; then
  echo "Deleting RDS instance: $DB_ID"
  aws rds delete-db-instance \
    --db-instance-identifier "$DB_ID" \
    --skip-final-snapshot \
    --delete-automated-backups >/dev/null || true
  aws rds wait db-instance-deleted --db-instance-identifier "$DB_ID" || true
fi

INSTANCE_IDS="$(aws ec2 describe-instances \
  --filters Name=vpc-id,Values="$VPC_ID" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)"
if [ -n "$INSTANCE_IDS" ]; then
  echo "Terminating instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS >/dev/null || true
  aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS || true
fi

EIP_ALLOCS="$(aws ec2 describe-addresses --query "Addresses[?AssociationId!=null || NetworkInterfaceId!=null].AllocationId" --output text 2>/dev/null || true)"
for alloc in $EIP_ALLOCS; do
  if [ -n "$alloc" ]; then
    echo "Releasing EIP allocation: $alloc"
    aws ec2 release-address --allocation-id "$alloc" >/dev/null 2>&1 || true
  fi
done

ENI_IDS="$(aws ec2 describe-network-interfaces --filters Name=vpc-id,Values="$VPC_ID" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text 2>/dev/null || true)"
for eni in $ENI_IDS; do
  echo "Deleting available ENI: $eni"
  aws ec2 delete-network-interface --network-interface-id "$eni" >/dev/null 2>&1 || true
done

IGW_IDS="$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || true)"
for igw in $IGW_IDS; do
  echo "Detaching and deleting IGW: $igw"
  aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$VPC_ID" >/dev/null 2>&1 || true
  aws ec2 delete-internet-gateway --internet-gateway-id "$igw" >/dev/null 2>&1 || true
done

ROUTE_TABLES="$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC_ID" --query 'RouteTables[?Associations[?Main!=`true`]].RouteTableId' --output text 2>/dev/null || true)"
for rt in $ROUTE_TABLES; do
  ASSOCS="$(aws ec2 describe-route-tables --route-table-ids "$rt" --query 'RouteTables[0].Associations[?Main!=`true`].RouteTableAssociationId' --output text 2>/dev/null || true)"
  for assoc in $ASSOCS; do
    echo "Disassociating route table association: $assoc"
    aws ec2 disassociate-route-table --association-id "$assoc" >/dev/null 2>&1 || true
  done
  echo "Deleting route table: $rt"
  aws ec2 delete-route-table --route-table-id "$rt" >/dev/null 2>&1 || true
done

SUBNETS="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" --query 'Subnets[].SubnetId' --output text 2>/dev/null || true)"
for subnet in $SUBNETS; do
  echo "Deleting subnet: $subnet"
  aws ec2 delete-subnet --subnet-id "$subnet" >/dev/null 2>&1 || true
done

SGS="$(aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || true)"
for sg in $SGS; do
  echo "Deleting security group: $sg"
  aws ec2 delete-security-group --group-id "$sg" >/dev/null 2>&1 || true
done

DB_SUBNET_GROUPS="$(aws rds describe-db-subnet-groups --query 'DBSubnetGroups[].DBSubnetGroupName' --output text 2>/dev/null | tr '\t' '\n' | grep "^local-services-db-subnet-${ENVIRONMENT}-" || true)"
for group in $DB_SUBNET_GROUPS; do
  echo "Deleting DB subnet group: $group"
  aws rds delete-db-subnet-group --db-subnet-group-name "$group" >/dev/null 2>&1 || true
done

echo "Cleanup pass completed for VPC: $VPC_ID"
