# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.9 as pxeFileProvider
RUN apk --no-cache add syslinux

FROM alpine:3.9
RUN apk --no-cache add dnsmasq
RUN mkdir -p /srv/tftp/efi64

# Legacy BIOS syslinux binaries
COPY --from=pxeFileProvider /usr/share/syslinux/lpxelinux.0 /srv/tftp/
COPY --from=pxeFileProvider /usr/share/syslinux/menu.c32 /srv/tftp/
COPY --from=pxeFileProvider /usr/share/syslinux/ldlinux.c32 /srv/tftp/
COPY --from=pxeFileProvider /usr/share/syslinux/libmenu.c32 /srv/tftp/
COPY --from=pxeFileProvider /usr/share/syslinux/libutil.c32 /srv/tftp/
COPY --from=pxeFileProvider /usr/share/syslinux/vesamenu.c32 /srv/tftp/
COPY --from=pxeFileProvider /usr/share/syslinux/libcom32.c32 /srv/tftp/

# UEFI syslinux binaries
COPY --from=pxeFileProvider /usr/share/syslinux/efi64/syslinux.efi /srv/tftp/efi64
COPY --from=pxeFileProvider /usr/share/syslinux/efi64/menu.c32 /srv/tftp/efi64
COPY --from=pxeFileProvider /usr/share/syslinux/efi64/ldlinux.e64 /srv/tftp/efi64
COPY --from=pxeFileProvider /usr/share/syslinux/efi64/libmenu.c32 /srv/tftp/efi64
COPY --from=pxeFileProvider /usr/share/syslinux/efi64/libutil.c32 /srv/tftp/efi64
COPY --from=pxeFileProvider /usr/share/syslinux/efi64/vesamenu.c32 /srv/tftp/efi64
COPY --from=pxeFileProvider /usr/share/syslinux/efi64/libcom32.c32 /srv/tftp/efi64

EXPOSE 53 53/UDP
EXPOSE 69 69/UDP
ENTRYPOINT ["dnsmasq", "-d"]
