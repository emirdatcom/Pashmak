FROM postgres:16-alpine
RUN apk add --no-cache age rsync openssh-client bash
COPY pg_backup.sh pg_restore.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/pg_backup.sh /usr/local/bin/pg_restore.sh \
 && echo '30 2 * * * /usr/local/bin/pg_backup.sh >> /proc/1/fd/1 2>&1' > /etc/crontabs/root
CMD ["crond", "-f", "-l", "8"]
