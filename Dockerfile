# Pull base image from authorized source
# FROM sla-dtr.sby.ibm.com/gts-docker-library/centos:6.6_ibm_1
FROM centos:6.6

# Install the necessary packages for LDAP Proxy server
RUN yum install openldap openldap-clients openldap-servers -y

# Make necessary directories
RUN mkdir -p /root/openldap_proxy && \
    mkdir -p /root/openldap_proxy/tmp && \
    mkdir -p /root/openldap_proxy/data && \
    mkdir -p /root/openldap_proxy/data/log && \
    mkdir -p /root/openldap_proxy/data/certs

# Remove unneeded directories
RUN rm -rf /etc/openldap/slapd.d

# Copy files to container
COPY ./start.sh /root/openldap_proxy/start.sh
COPY ./slapd.conf /root/openldap_proxy/tmp/slapd.conf

# Add execution permission
RUN chmod 755 /root
RUN chmod +x /root/openldap_proxy/start.sh

# Entry point
ENTRYPOINT ["/root/openldap_proxy/start.sh"]

