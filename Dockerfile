# Use the Amazon Linux-based AWS CLI image
FROM amazonlinux:latest

# Install the AWS CLI
RUN yum update -y && \
    yum install -y aws-cli

# Install netcat using yum
RUN yum install -y nc

COPY ./check-connections.sh /usr/local/bin/check-connections.sh

RUN chmod +x /usr/local/bin/check-connections.sh
