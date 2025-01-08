# Use the Amazon Linux-based AWS CLI image
FROM amazonlinux:latest

# Install the AWS CLI
RUN yum update -y && \
    yum install -y aws-cli nc nano vim jq

COPY ./check-connections.sh /usr/local/bin/check-connections.sh
COPY ./check-envs.sh /usr/local/bin/check-envs.sh
COPY ./ssm-compare.sh /usr/local/bin/ssm-compare.sh
COPY ./ecs-utils.sh /usr/local/bin/ecs-utils.sh

RUN chmod +x /usr/local/bin/check-connections.sh
RUN chmod +x /usr/local/bin/check-envs.sh
RUN chmod +x /usr/local/bin/ssm-compare.sh
RUN chmod +x /usr/local/bin/ecs-utils.sh
