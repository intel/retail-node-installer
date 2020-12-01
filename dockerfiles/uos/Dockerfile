# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM docker:18.06.3-ce-dind
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk update && apk add --no-cache \
    alpine-sdk \
    bash \
    coreutils \
    git \
    rsync \
    wget

RUN git clone https://github.com/linuxkit/linuxkit --depth 1 --branch v0.8

ENTRYPOINT ["/bin/bash"]
CMD []
