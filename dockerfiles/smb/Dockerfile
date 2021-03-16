# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install samba software-properties-common -y

RUN mkdir /smbshare && \
    chmod 777 /smbshare
RUN echo "[install]\n comment = My network share \n path = /smbshare/ \n public = yes \n writable = no \n printable = no \n browseable = yes \n create mask = 0644\ndirectory mask = 0755\n" >> /etc/samba/smb.conf

RUN /etc/init.d/smbd restart

EXPOSE 445/tcp

CMD ["smbd", "--foreground", "--log-stdout"]