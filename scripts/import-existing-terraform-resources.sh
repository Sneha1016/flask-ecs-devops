#!/usr/bin/env bash
set -u

TF_ROOT="${1:-my-flask-project/terraform}"
AWS_REGION="${AWS_REGION:-ap-south-1}"
PROJECT_NAME="${PROJECT_NAME:-flask-ecs}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

NAME_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"
ECR_REPOSITORY="${NAME_PREFIX}"
ALB_NAME="${NAME_PREFIX}-alb"
TG_NAME="${NAME_PREFIX}-tg"
LOG_GROUP="/ecs/${NAME_PREFIX}"
EXEC_ROLE="${NAME_PREFIX}-ecs-exec-role"
TASK_ROLE="${NAME_PREFIX}-ecs-task-role"
VPC_NAME="${NAME_PREFIX}-vpc"
IGW_NAME="${NAME_PREFIX}-igw"
ROUTE_TABLE_NAME="${NAME_PREFIX}-public-rt"
SUBNET1_NAME="${NAME_PREFIX}-public-1"
SUBNET2_NAME="${NAME_PREFIX}-public-2"
ALB_SG_NAME="${NAME_PREFIX}-alb-sg"
ECS_SG_NAME="${NAME_PREFIX}-ecs-sg"
CLUSTER_NAME="${NAME_PREFIX}-cluster"
SERVICE_NAME="${NAME_PREFIX}-service"

cd "${TF_ROOT}"

tf_has_state() {
    terraform state list "$1" >/dev/null 2>&1
}

tf_import_if_needed() {
    local address="$1"
    local import_id="$2"

    if [ -z "${import_id}" ] || [ "${import_id}" = "None" ] || [ "${import_id}" = "null" ]; then
        return 0
    fi

    if tf_has_state "${address}"; then
        echo "State already has ${address}"
        return 0
    fi

    echo "Importing ${address} -> ${import_id}"
    terraform import "${address}" "${import_id}" || true
}

aws_text() {
    aws "$@" --region "${AWS_REGION}" --output text 2>/dev/null | tr -d '\r'
}

vpc_id="$(aws_text ec2 describe-vpcs --filters "Name=tag:Name,Values=${VPC_NAME}" --query 'Vpcs[0].VpcId')"
tf_import_if_needed "module.networking.aws_vpc.this" "${vpc_id}"

subnet1_id="$(aws_text ec2 describe-subnets --filters "Name=tag:Name,Values=${SUBNET1_NAME}" --query 'Subnets[0].SubnetId')"
subnet2_id="$(aws_text ec2 describe-subnets --filters "Name=tag:Name,Values=${SUBNET2_NAME}" --query 'Subnets[0].SubnetId')"
tf_import_if_needed "module.networking.aws_subnet.public[0]" "${subnet1_id}"
tf_import_if_needed "module.networking.aws_subnet.public[1]" "${subnet2_id}"

route_table_id="$(aws_text ec2 describe-route-tables --filters "Name=tag:Name,Values=${ROUTE_TABLE_NAME}" --query 'RouteTables[0].RouteTableId')"
tf_import_if_needed "module.networking.aws_route_table.public" "${route_table_id}"

if [ -n "${subnet1_id}" ] && [ -n "${route_table_id}" ] && [ "${subnet1_id}" != "None" ] && [ "${route_table_id}" != "None" ]; then
    tf_import_if_needed "module.networking.aws_route_table_association.public[0]" "${subnet1_id}/${route_table_id}"
fi

if [ -n "${subnet2_id}" ] && [ -n "${route_table_id}" ] && [ "${subnet2_id}" != "None" ] && [ "${route_table_id}" != "None" ]; then
    tf_import_if_needed "module.networking.aws_route_table_association.public[1]" "${subnet2_id}/${route_table_id}"
fi

igw_id=""
if [ -n "${vpc_id}" ] && [ "${vpc_id}" != "None" ]; then
    igw_id="$(aws_text ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${vpc_id}" --query 'InternetGateways[0].InternetGatewayId')"
fi
tf_import_if_needed "module.networking.aws_internet_gateway.this" "${igw_id}"

alb_sg_id=""
ecs_sg_id=""
if [ -n "${vpc_id}" ] && [ "${vpc_id}" != "None" ]; then
    alb_sg_id="$(aws_text ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc_id}" "Name=group-name,Values=${ALB_SG_NAME}" --query 'SecurityGroups[0].GroupId')"
    ecs_sg_id="$(aws_text ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc_id}" "Name=group-name,Values=${ECS_SG_NAME}" --query 'SecurityGroups[0].GroupId')"
fi
tf_import_if_needed "module.security_groups.aws_security_group.alb" "${alb_sg_id}"
tf_import_if_needed "module.security_groups.aws_security_group.ecs" "${ecs_sg_id}"

ecr_name="$(aws_text ecr describe-repositories --repository-names "${ECR_REPOSITORY}" --query 'repositories[0].repositoryName')"
tf_import_if_needed "module.ecr.aws_ecr_repository.this" "${ecr_name}"

log_group_name="$(aws_text logs describe-log-groups --log-group-name-prefix "${LOG_GROUP}" --query 'logGroups[0].logGroupName')"
tf_import_if_needed "module.cloudwatch.aws_cloudwatch_log_group.this" "${log_group_name}"

exec_role_name="$(aws_text iam get-role --role-name "${EXEC_ROLE}" --query 'Role.RoleName')"
task_role_name="$(aws_text iam get-role --role-name "${TASK_ROLE}" --query 'Role.RoleName')"
tf_import_if_needed "module.iam.aws_iam_role.ecs_task_execution" "${exec_role_name}"
tf_import_if_needed "module.iam.aws_iam_role.ecs_task" "${task_role_name}"
tf_import_if_needed "module.iam.aws_iam_role_policy_attachment.ecs_task_execution" "${EXEC_ROLE}/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

alb_arn="$(aws_text elbv2 describe-load-balancers --names "${ALB_NAME}" --query 'LoadBalancers[0].LoadBalancerArn')"
tg_arn="$(aws_text elbv2 describe-target-groups --names "${TG_NAME}" --query 'TargetGroups[0].TargetGroupArn')"
tf_import_if_needed "module.alb.aws_lb.this" "${alb_arn}"
tf_import_if_needed "module.alb.aws_lb_target_group.this" "${tg_arn}"

listener_arn=""
if [ -n "${alb_arn}" ] && [ "${alb_arn}" != "None" ]; then
    listener_arn="$(aws_text elbv2 describe-listeners --load-balancer-arn "${alb_arn}" --query 'Listeners[?Port==`80`][0].ListenerArn')"
fi
tf_import_if_needed "module.alb.aws_lb_listener.http" "${listener_arn}"

cluster_name="$(aws_text ecs describe-clusters --clusters "${CLUSTER_NAME}" --query 'clusters[?status==`ACTIVE`][0].clusterName')"
tf_import_if_needed "module.ecs.aws_ecs_cluster.this" "${cluster_name}"

service_arn="$(aws_text ecs describe-services --cluster "${CLUSTER_NAME}" --services "${SERVICE_NAME}" --query 'services[?status==`ACTIVE`][0].serviceArn')"
if [ -n "${service_arn}" ] && [ "${service_arn}" != "None" ]; then
    tf_import_if_needed "module.ecs.aws_ecs_service.this" "${CLUSTER_NAME}/${SERVICE_NAME}"
fi

task_definition_arn="$(aws_text ecs describe-task-definition --task-definition "${NAME_PREFIX}-task" --query 'taskDefinition.taskDefinitionArn')"
tf_import_if_needed "module.ecs.aws_ecs_task_definition.this" "${task_definition_arn}"
