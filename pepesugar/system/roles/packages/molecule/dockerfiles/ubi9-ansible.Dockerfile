ARG BUILDPLATFORM=linux/amd64
ARG ANSIBLE_VER=2.16      # или latest
FROM --platform=$BUILDPLATFORM redhat/ubi9:latest

# ускоряем dnf + режем слабые зависимости
RUN dnf install -y --setopt=install_weak_deps=False \
    ansible-core-$ANSIBLE_VER \
    python3-pip git && \
    pip install --no-cache-dir ansible-lint molecule[docker] && \
    dnf clean all

# приятные дефолты
ENV ANSIBLE_FORCE_COLOR=1 \
    PY_COLORS=1 \
    LANG=C.UTF-8

WORKDIR /workspace
ENTRYPOINT ["bash"]
