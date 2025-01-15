# Use the Amazon Linux-based AWS CLI image
FROM amazonlinux:latest

# Install the AWS CLI and other necessary tools
RUN yum update -y && \
    yum install -y aws-cli nc nano vim jq && \
    yum clean all

RUN dnf update -y
RUN dnf install mariadb105 -y

# Copy scripts to the appropriate directory and make them executable
COPY ./check-connections.sh /usr/local/bin/
COPY ./check-envs.sh /usr/local/bin/
COPY ./ssm-compare.sh /usr/local/bin/
COPY ./ecs-utils.sh /usr/local/bin/
COPY ./lambda-utils.sh /usr/local/bin/
COPY ./check-db.sh /usr/local/bin/
COPY ./db-cloning.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/check-connections.sh \
    /usr/local/bin/check-envs.sh \
    /usr/local/bin/ssm-compare.sh \
    /usr/local/bin/ecs-utils.sh \
    /usr/local/bin/lambda-utils.sh \
    /usr/local/bin/check-db.sh \
    /usr/local/bin/db-cloning.sh
