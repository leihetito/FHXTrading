#!/bin/sh

HOME_DIR=~/dev/FHX/fhx_java

cd ${HOME_DIR}

JAR_DIR=${HOME_DIR}/3rdlibs
CLASS_PATH=${HOME_DIR}/bin
MAIN_CLASS=com.fhx.statstream.StatStreamHistoricalRunner

for i in `ls ${JAR_DIR}/apache/*.jar`
  do
  CLASS_PATH=${CLASS_PATH}:${i}
done
for i in `ls ${JAR_DIR}/ib/*.jar`
  do
  CLASS_PATH=${CLASS_PATH}:${i}
done
for i in `ls ${JAR_DIR}/metclibs-1.5/*.jar`
  do
  CLASS_PATH=${CLASS_PATH}:${i}
done
for i in `ls ${JAR_DIR}/quickfix-1.5/*.jar`
  do
  CLASS_PATH=${CLASS_PATH}:${i}
done
for i in `ls ${JAR_DIR}/rosuda/*.jar`
  do
  CLASS_PATH=${CLASS_PATH}:${i}
done
for i in `ls ${JAR_DIR}/marketcetera/*.jar`
  do
  CLASS_PATH=${CLASS_PATH}:${i}
done

echo ${CLASS_PATH}

JAVA_ARGS="-Dorg.marketcetera.appDir=. -Dstrategy.classpath=./src -Dinput.symbols=./conf/xlk.us.csv -Dibconf.file=./conf/conf-base.properties -DtickFrequency=5 -Dfile.encoding=UTF-8 -DclientId=9"
PROG_ARGS=scripts/MarketDataIB.txt

#kill existing Rserver run
pkill Rserve
rm ./a.out

CMD="java ${JAVA_ARGS} -classpath .:${CLASS_PATH} $MAIN_CLASS $PROG_ARGS"

$CMD 2>&1 > ./a.out

if [ $? -eq 0 ]
then
  echo "compile worked!"
fi

