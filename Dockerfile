#-----------------------------------------#
# Using image from circleci
#-----------------------------------------#
FROM circleci/python

### Install dependent packages
RUN sudo pip install awscli ecs-deploy && \
    sudo apt-get install -y jq gettext && \
    aws --version
