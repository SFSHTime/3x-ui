# ========================================================
# Stage: Builder
# ========================================================
FROM golang:1.22-bullseye AS builder
WORKDIR /app
ARG TARGETARCH

# Ubuntu 使用 apt-get 而不是 apk 并且可能不需要 unzip 和 wget
RUN apt-get update && apt-get install -y \
  build-essential \
  gcc

COPY . .

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN go build -o build/x-ui main.go
RUN ./DockerInit.sh "$TARGETARCH"

# ========================================================
# Stage: Final Image of 3x-ui
# ========================================================
FROM ubuntu:22.04
ENV TZ=Asia/Tehran
WORKDIR /app

# 安装 systemd 和其他需要的软件包
RUN apt-get update && apt-get install -y \
  ca-certificates \
  tzdata \
  fail2ban \
  bash \
  systemd \
  systemd-sysv \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# 复制构建的应用和脚本
COPY --from=builder /app/build/ /app/
COPY --from=builder /app/DockerEntrypoint.sh /app/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui

# 配置 fail2ban
RUN cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
  && sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local

# 设置权限
RUN chmod +x \
  /app/DockerEntrypoint.sh \
  /app/x-ui \
  /usr/bin/x-ui

# 移除不需要的服务单元
RUN find /etc/systemd/system \
         /lib/systemd/system \
         -path '*.wants/*' \
         -not -name '*journald*' \
         -not -name '*systemd-tmpfiles*' \
         -not -name '*systemd-user-sessions*' \
         -exec rm \{} \;

# 设置环境变量以通知 systemd 正在容器中运行
ENV container=docker

VOLUME [ "/sys/fs/cgroup", "/etc/x-ui" ]
CMD ["/lib/systemd/systemd"]
ENTRYPOINT ["/sbin/init"]
