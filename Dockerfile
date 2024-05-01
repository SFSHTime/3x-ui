# ========================================================
# Stage: Builder
# ========================================================
FROM golang:1.22 AS builder
WORKDIR /app
ARG TARGETARCH

# Install dependencies required for the build process
RUN apt-get update && apt-get install -y \
  build-essential \
  gcc \
  wget \
  unzip

COPY . .

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN go build -o build/x-ui main.go
RUN chmod +x ./DockerInit.sh
RUN ./DockerInit.sh "$TARGETARCH"

# ========================================================
# Stage: Final Image of 3x-ui
# ========================================================
FROM jrei/systemd-ubuntu:22.04
ENV TZ=Asia/Tehran
WORKDIR /app

# Install required packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  tzdata \
  fail2ban \
  bash \
  && rm -rf /var/lib/apt/lists/*

# Copy build output and scripts from the builder stage
COPY --from=builder /app/build/ /app/
COPY --from=builder /app/DockerEntrypoint.sh /app/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui

# Configure fail2ban
RUN rm -f /etc/fail2ban/jail.d/defaults-debian.conf \
  && cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
  && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/# allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf

# Set permissions for entrypoint and scripts
RUN chmod +x \
  /app/DockerEntrypoint.sh \
  /app/x-ui \
  /usr/bin/x-ui

# Define volume for configuration
VOLUME [ "/etc/x-ui" ]

# Set the command to run the application
CMD [ "./x-ui" ]

# Set entrypoint script
ENTRYPOINT [ "/app/DockerEntrypoint.sh" ]
