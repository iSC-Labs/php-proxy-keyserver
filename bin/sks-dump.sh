#!/bin/bash

# This script will delete outdated backups, stop the sks server,
# dump its contents to the $OUTDIR, then restart the sks server.

TZ='UTC'
HOSTNAME='pgp.key-server.io'
MAIL='carles.tubio@key-server.io'
BACKUPS=7
USER="dhc-user"
GROUP="www-data"
INDIR="/var/lib/sks"
PREDIR="dump"
SKSDATE=`date -u +%Y-%m-%d`
OUTDIR="$INDIR/$PREDIR/$SKSDATE"
COUNT="10000"
MINFREEG=$((1+$(du -sh ${INDIR}/${PREDIR}/`ls -1t ${INDIR}/${PREDIR} | head -n 1` | sed 's/\..*//g' | sed 's/G.*//g' | awk '{ print $1 }')))
MINFREEG=${MINFREEG:=8}
PARTITION=`df ${INDIR}/${PREDIR} | tail -n 1 | awk '{print $1}'`

cd ${INDIR};
for DEL in `ls -1t $PREDIR | egrep -v "current|lost\+found" | tail -n +${BACKUPS}`; do
  echo "Deleting old directory $PREDIR/$DEL";
  rm -rf ${PREDIR}/$DEL;
done;

if (($(df -h / | grep "${PARTITION}" | awk '{ print $4 }' | sed 's/\..*//g' | sed 's/G.*//g') < ${MINFREEG})); then
  echo "Dump ${SKSDATE} failed. ${PARTITION} at ${HOSTNAME} reached $(df -h / | grep "${PARTITION}" | awk '{ print $4 }') of free disk.";
  exit 1;
fi;

DUMPDATE="`date -u`"
/usr/sbin/service sks stop;
sleep 2;

if [ `ps -eaf | grep "sks " | grep -v 'grep sks' | wc -l` == "0" ]; then
  rm -rf $OUTDIR && mkdir -p $OUTDIR && \
  chown -R $USER:$GROUP $PREDIR && \
  time /usr/local/bin/sks dump $COUNT $OUTDIR/ sks-dump;

  if [ `ps -eaf | grep "sks " | grep -v 'grep sks' | wc -l` == "0" ]; then
    /usr/sbin/service sks start;
  else
    echo "Unable to start SKS since it was already running.";
    exit 1;
  fi;

  cd $OUTDIR;
  sed -i 's/\(\w\)\ \(sks-dump.*\)/\1  \2/' metadata-sks-dump.txt;
  if md5sum --status --check metadata-sks-dump.txt; then
    cd $INDIR/$PREDIR;
    rm -f current;
    ln -s $OUTDIR current;
    echo "md5sum OK.";
  else
    cd $INDIR/$PREDIR;
    rm -rf $OUTDIR;
    echo "md5sum failed, $OUTDIR was removed.";
    exit 1;
  fi;
else
  echo "Unable run backup, SKS is still running.";
  exit 1;
fi;

SIZE=`du -shc $OUTDIR |grep 'total' |awk '{ print $1 }'`;
DCOUNT=`grep "#Key-Count" $OUTDIR/metadata-sks-dump.txt |awk '{ print $2 }'`;
FILES=`grep "#Files-Count" $OUTDIR/metadata-sks-dump.txt |awk '{ print $2 }'`;
echo "This is the keyserver dump from ${HOSTNAME} generated at: ${DUMPDATE}

Tonight's archive size is approximately ${SIZE}, holding ${DCOUNT} keys in ${FILES} files.

These files were created basically running: $ sks dump ${COUNT} ${SKSDATE}/ sks-dump
At your convenience, the full script is available at github:

 https://github.com/ctubio/php-proxy-keyserver/blob/master/bin/sks-dump.sh

You can install this dump into your own database using the following automated script:

 https://github.com/ctubio/php-proxy-keyserver/blob/master/bin/sks-install-database.sh

Alternatively, on unix-like systems, you may manually follow the 3 steps below:

 1) Download a recently created online dump directory via the following command:

  $ cd /var/lib/sks
  $ rm -rf dump
  $ mkdir dump
  $ cd dump
  $ wget -c -r -p -e robots=off -N -l1 --cut-dirs=3 -nH http://${HOSTNAME}/dump/current/

 2) After downloading the dump files, you should validate them all executing:

  $ cd /var/lib/sks/dump
  $ md5sum -c metadata-sks-dump.txt

 3) If zero warnings are reported, you can import all keys into a new database:

  $ cd /var/lib/sks
  $ rm -rf KDB PTree
  $ /usr/local/bin/sks_build.sh

 and choose the option 2 (normalbuild).

If all goes smoothly during the installation, you'll end up with KDB and
PTree directories in /var/lib/sks, and you are ready to start the daemons.

The content of /var/lib/sks/dump directory can be removed, and additionally,
can be replaced by backups of daily dumps of your own database.

Also, if you would like to peer with this server, please send an email
to <${MAIL}> with your membership line." > $OUTDIR/README.txt;

cd $INDIR;
chown -R $USER:$GROUP $PREDIR;
