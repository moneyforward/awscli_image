#-----------------------------------------#
# Using image from circleci
#-----------------------------------------#
FROM cimg/go:1.19

### Install dependent packages
RUN sudo pip install ecs-deploy && \
    sudo apt-get install -y jq gettext

RUN sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

RUN sudo unzip awscliv2.zip

RUN sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin

RUN sudo aws --version
