# Pull base image from authorized source
FROM centos:7

# Install the necessary packages for LDAP Proxy server
RUN yum install openldap openldap-clients openldap-servers openssl -y

# Make necessary directories
RUN mkdir -p /root/openldap_proxy && \
    mkdir -p /root/openldap_proxy/tmp && \
    mkdir -p /root/openldap_proxy/data && \
    mkdir -p /root/openldap_proxy/data/log && \
    mkdir -p /root/openldap_proxy/data/certs

# Remove unneeded directories
RUN rm -rf /etc/openldap/slapd.d

# Copy files to container
COPY ./ldap.conf /etc/openldap/ldap.conf
COPY ./slapd.conf /root/openldap_proxy/tmp/slapd.conf_template
COPY ./secret.sh /root/secret.sh
COPY ./docker-entrypoint.sh /root/openldap_proxy/docker-entrypoint.sh

# Add execution permission
RUN chmod 755 /root
RUN chmod +x /root/openldap_proxy/docker-entrypoint.sh && \
	chmod +x /root/secret.sh

# Entry point
ENTRYPOINT ["/root/openldap_proxy/docker-entrypoint.sh"]

