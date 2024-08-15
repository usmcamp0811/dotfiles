FROM nixpkgs/nix-flakes

ENV AUTHORIZED_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAclfREva2i4LsnBQPY3ZSsZzeuS5DGn11u0abBR8cFv mcamp@butler'
# Install OpenSSH server, busybox (for adduser/addgroup), and openssl
RUN nix profile install nixpkgs#openssh nixpkgs#busybox nixpkgs#openssl

# Create the sshd group and user for privilege separation
RUN /root/.nix-profile/bin/busybox addgroup -g 1000 sshd && \
  /root/.nix-profile/bin/busybox adduser -D -H -G sshd -u 1000 -s /sbin/nologin sshd

# Create the .ssh directory, generate an SSH key pair, and set proper permissions
RUN mkdir -p /root/.ssh && \
  chmod 700 /root/.ssh && \
  ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""

# Generate SSH host keys
RUN echo "${AUTHORIZED_KEY}" > /root/.ssh/authorized_keys \
  && chmod 600 /root/.ssh/authorized_keys \
  && ssh-keygen -A

# Create the /var/empty directory for privilege separation
RUN mkdir -p /var/empty && chmod 700 /var/empty && chown root:root /var/empty

# Expose SSH port
EXPOSE 22

# Start the SSH service using the absolute path
CMD ["/root/.nix-profile/bin/sshd", "-D"]

