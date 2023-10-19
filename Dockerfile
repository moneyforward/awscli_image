#-----------------------------------------#
# Using image from circleci
#-----------------------------------------#
FROM cimg/go:1.21

### Install dependent packages
RUN sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN sudo unzip awscliv2.zip
RUN sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
RUN sudo rm -rf aws awscliv2.zip
RUN sudo aws --version
