FROM --platform=linux/amd64 python:3.9-slim-bookworm

LABEL maintainer="Vladislav Nagaev <vladislav.nagaew@gmail.com>"

USER root

WORKDIR /

ENV \ 
    # Задание переменных пользователя
    USER=admin \
    UID=1001 \
    GROUP=admin \
    GID=1001 \
    GROUPS="admin,root" \
    PASSWORD=admin \
    # Выбор time zone
    DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Moscow \
    # Задание версий сервисов
    PYTHON_VERSION=3.9 \
    JAVA_VERSION=8 \
    HUE_VERSION=4.11.0 \
    # Задание директорий 
    WORK_DIRECTORY=/workspace \
    LOG_DIRECTORY=/tmp/logs \
    ENTRYPOINT_DIRECTORY=/entrypoint \
    # Задание домашних директорий
    JAVA_HOME=/usr/lib/jvm/java \
    HUE_HOME=/opt/hue

ENV \
    # Задание домашних директорий
    HOME=/home/${USER} \
    # Обновление переменных путей
    PATH=${PATH}:${JAVA_HOME}/bin:${HUE_HOME}/build/env/bin \
    # Полные наименования сервисов
    PYTHON_NAME=python${PYTHON_VERSION} \
    HUE_NAME=hue-release-${HUE_VERSION} \
    # URL-адреса для скачивания
    HUE_URL=https://github.com/gethue/hue/archive/refs/heads/master.zip \
    # Переменные окружения для Python 
    # - не создавать файлы кэша .pyc, 
    PYTHONDONTWRITEBYTECODE=1 \
    # - не помещать в буфер потоки stdout и stderr
    PYTHONUNBUFFERED=1 \
    # - установить фиксированное начальное число для генерации hash() типов, охватываемых рандомизацией хэша
    PYTHONHASHSEED=1 \
    # - отключить проверку версии pip
    PIP_DISABLE_PIP_VERSION_CHECK=1 

RUN \
    # --------------------------------------------------------------------------
    # Базовая настройка операционной системы
    # --------------------------------------------------------------------------
    # Установка пароль пользователя root 
    echo "root:root" | chpasswd && \
    # Создание группы и назначение пользователя в ней
    groupadd --gid ${GID} --non-unique ${GROUP} && \
    useradd --system --create-home --home-dir ${HOME} --shell /bin/bash \
    --gid ${GID} --groups ${GROUPS} --uid ${UID} ${USER} \
    --password $(perl -e 'print crypt($ARGV[0], "password")' ${PASSWORD})  && \
    # Обновление ссылок
    echo "deb http://deb.debian.org/debian/ sid main" >> /etc/apt/sources.list && \
    # Обновление путей
    apt --yes update && \
    # Установка timezone
    apt install --no-install-recommends --yes tzdata && \
    cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone && \
    # Установка языкового пакета
    apt install --no-install-recommends --yes locales && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Подготовка директорий
    # --------------------------------------------------------------------------
    # Директория логов
    mkdir -p ${LOG_DIRECTORY} && \
    chown -R ${USER}:${GID} ${LOG_DIRECTORY} && \
    chmod -R a+rw ${LOG_DIRECTORY} && \
    # Рабочая директория
    mkdir -p ${WORK_DIRECTORY} && \
    chown -R ${USER}:${GID} ${WORK_DIRECTORY} && \
    chmod -R a+rwx ${WORK_DIRECTORY} && \
    # Директория entrypoint
    mkdir -p ${ENTRYPOINT_DIRECTORY} && \
    chown -R ${USER}:${GID} ${ENTRYPOINT_DIRECTORY} && \
    chmod -R a+rx ${ENTRYPOINT_DIRECTORY} && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Установка базовых пакетов
    # --------------------------------------------------------------------------
    apt install --no-install-recommends --yes software-properties-common && \
    apt install --no-install-recommends --yes apt-utils && \
    apt install --no-install-recommends --yes curl && \
    apt install --no-install-recommends --yes netcat-openbsd && \
    apt install --no-install-recommends --yes make && \
    apt install --no-install-recommends --yes git && \
    apt install --no-install-recommends --yes unzip && \
    apt install --no-install-recommends --yes rsync && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Подготовка shell-скриптов
    # --------------------------------------------------------------------------
    # Ожидание запуска сервиса
    echo \
'''#!/bin/bash \n\
function wait_for_it() { \n\
    local serviceport=$1 \n\
    local service=${serviceport%%:*} \n\
    local port=${serviceport#*:} \n\
    local retry_seconds=5 \n\
    local max_try=100 \n\
    let i=1 \n\
    nc -z $service $port \n\
    result=$? \n\
    until [ $result -eq 0 ]; do \n\
      echo "[$i/$max_try] check for ${service}:${port}..." \n\
      echo "[$i/$max_try] ${service}:${port} is not available yet" \n\
      if (( $i == $max_try )); then \n\
        echo "[$i/$max_try] ${service}:${port} is still not available; giving up after ${max_try} tries. :/" \n\
        exit 1 \n\
      fi \n\
      echo "[$i/$max_try] try in ${retry_seconds}s once again ..." \n\
      let "i++" \n\
      sleep $retry_seconds \n\
      nc -z $service $port \n\
      result=$? \n\
    done \n\
    echo "[$i/$max_try] $service:${port} is available." \n\
} \n\
for i in ${SERVICE_PRECONDITION[@]} \n\
do \n\
    wait_for_it ${i} \n\
done \n\
''' > ${ENTRYPOINT_DIRECTORY}/wait_for_it.sh && \
    cat ${ENTRYPOINT_DIRECTORY}/wait_for_it.sh && \
    # Сборка hue
    echo \
'''#!/bin/bash \n\
HUE_SOURCE_PATH="${1:-}" \n\
PARAMS="${@:2}" \n\
echo "Hue building started ..." \n\
owd="$(pwd)" \n\
cd ${HUE_SOURCE_PATH} \n\
eval "${PARAMS} make apps install" \n\
cd "${owd}" \n\
echo "Hue building completed!" \n\
''' > ${ENTRYPOINT_DIRECTORY}/hue-building.sh && \
    cat ${ENTRYPOINT_DIRECTORY}/hue-building.sh && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Настройка прав доступа скопированных файлов/директорий
    # --------------------------------------------------------------------------
    # Директория/файл entrypoint
    chown -R ${USER}:${GID} ${ENTRYPOINT_DIRECTORY} && \
    chmod -R a+x ${ENTRYPOINT_DIRECTORY} && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Установка Java
    # --------------------------------------------------------------------------
    # Install OpenJDK
    apt install --yes openjdk-${JAVA_VERSION}-jdk && \ 
    # Создание символической ссылки на Java
    ln -s ${JAVA_HOME}-${JAVA_VERSION}-openjdk-amd64 ${JAVA_HOME} && \
    # Smoke test
    java -version && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Установка обязательных пакетов
    # --------------------------------------------------------------------------
    # gcc, g++, make
    apt install --no-install-recommends --yes build-essential && \
    # modules for hue build
    apt install --no-install-recommends --yes libkrb5-dev && \
    apt install --no-install-recommends --yes libffi-dev && \
    apt install --no-install-recommends --yes libmysqlclient-dev && \
    apt install --no-install-recommends --yes libsasl2-dev && \
    apt install --no-install-recommends --yes libsasl2-modules-gssapi-mit && \
    apt install --no-install-recommends --yes libsqlite3-dev && \
    apt install --no-install-recommends --yes libssl-dev && \
    apt install --no-install-recommends --yes libxml2-dev && \
    apt install --no-install-recommends --yes libxslt-dev && \
    # do not remove
    apt install --no-install-recommends --yes libldap2-dev && \
    apt install --no-install-recommends --yes libgmp3-dev && \
    # python-packages
    apt install --no-install-recommends --yes python3-setuptools && \
    apt install --no-install-recommends --yes python3-dev && \
    apt install --no-install-recommends --yes python3-distutils && \
    # Установка Apache Ant
    apt install --no-install-recommends --yes ant && \
    # Установка Maven
    apt install --no-install-recommends --yes maven && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Установка NodeJs
    # --------------------------------------------------------------------------
    # Скачивание Bash-скрипта установки
    curl -sL https://deb.nodesource.com/setup_14.x -o /tmp/nodesource_setup.sh && \
    # Выполнение скрипта
    bash /tmp/nodesource_setup.sh && \
    # Удаление скрипта
    rm /tmp/nodesource_setup.sh* && \
    # Установка NodeJs
    apt install --no-install-recommends --yes nodejs && \
    # Smoke test
    node -v && \
    # Установка npm
    apt install --no-install-recommends --yes npm && \
    # Обновление версии npm
    npm install --global npm && \
    # Smoke test
    npm -v && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Установка Cloudera Hue
    # --------------------------------------------------------------------------
    # Скачивание архива с исходным кодом Cloudera Hue из ветки master
    curl --fail --show-error --location ${HUE_URL} --output /tmp/${HUE_NAME}.zip && \
    # Распаковка архива с исходным кодом Cloudera Hue в рабочую папку
    unzip /tmp/${HUE_NAME}.zip -d /tmp && \
    # Переименование рабочей папки
    mv /tmp/hue-master /tmp/${HUE_NAME} && \
    # Удаление исходного архива
    rm /tmp/${HUE_NAME}.zip* && \
    # Директория для сборки Cloudera Hue
    mkdir -p /tmp/${HUE_NAME}/build && \
    # Директория исходного кода Cloudera Hue
    chown -R ${USER}:${GID} /tmp/${HUE_NAME} && \
    chmod -R a+rwx /tmp/${HUE_NAME} && \
    # Рабочая директория Cloudera Hue
    mkdir -p ${HUE_HOME} && \
    chown -R ${USER}:${GID} ${HUE_HOME} && \
    chmod -R a+rwx ${HUE_HOME} && \
    # Очистка файла конфигурации
    rm -rf /tmp/${HUE_NAME}/desktop/conf && \
    cp --recursive --force /tmp/${HUE_NAME}/desktop/conf.dist /tmp/${HUE_NAME}/desktop/conf && \
    # Установка необходимых пакетов python
    ${PYTHON_NAME} -m pip install --no-cache-dir --use-pep517 setuptools && \
    ${PYTHON_NAME} -m pip install --no-cache-dir --use-pep517 virtualenv && \
    ${PYTHON_NAME} -m pip install --no-cache-dir --use-pep517 future && \
    # Сборка Cloudera Hue в директорию PREFIX
    "${ENTRYPOINT_DIRECTORY}/hue-building.sh" /tmp/${HUE_NAME} \
    # Переменные для сборки Cloudera Hue
    PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python \
    PREFIX=$(dirname ${HUE_HOME}) \
    PYTHON_VER=${PYTHON_NAME} \
    ROOT=/tmp/${HUE_NAME} \
    SYS_PYTHON=/usr/local/bin/${PYTHON_NAME} \
    SYS_PIP=/usr/local/bin/pip${PYTHON_VERSION} && \
    # Копирование файлов из директории исходного кода Cloudera Hue
    cp -r /tmp/${HUE_NAME}/tools/docker/hue/conf3/* ${HUE_HOME}/desktop/conf/ && \
    cp /tmp/${HUE_NAME}/tools/docker/hue/startup.sh ${HUE_HOME}/startup.sh && \
    mkdir -p ${HUE_HOME}/tools/slack && \
    cp /tmp/${HUE_NAME}/tools/slack/manifest.yml ${HUE_HOME}/tools/slack/manifest.yml && \
    # Удаление исходного кода
    rm -rf /tmp/${HUE_NAME} && \
    rm -rf ${HUE_HOME}/node_modules && \
    # Рабочая директория Cloudera Hue
    chown -R ${USER}:${GID} ${HUE_HOME} && \
    chmod -R a+rwx ${HUE_HOME} && \
    # Smoke test
    hue version && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Install DB connectors
    # --------------------------------------------------------------------------
    # Apache Hive / Presto / Trino
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir pyhive>=0.7.0 && \
    # MySQL
    apt install --no-install-recommends --yes pkg-config && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir mysqlclient>=2.2.4 && \
    # PostgreSQL
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir psycopg2-binary>=2.9.9 && \
    # ksqlDB
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir ksql>=0.10.2 && \
    # Apache Spark SQL
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir git+https://github.com/gethue/PyHive && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir thrift_sasl>=0.4.3 && \
    # other
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir mozilla-django-oidc>=4.0.0 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir simple-salesforce>=1.12.5 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir py4j>=0.10.9.7 && \
    # Avoid Django 3 pulling
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir django_redis==5.4.0 && \
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir flower==2.0.1 && \
    # ksql
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir pydruid==0.6.6 && \
    # View some parquet files
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir python-snappy==0.6.1 && \
    # Needed for Jaeger
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir threadloop==1.0.2 && \
    # other
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir gcs-oauth2-boto-plugin==3.0 && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Удаление неактуальных пакетов, директорий, очистка кэша
    # --------------------------------------------------------------------------
    # Очистка кэша NodeJs
    npm cache clean --force && \
    # Удаление NodeJs
    apt remove --yes nodejs && \
    apt remove --yes npm && \
    # Удаление Apache Ant
    apt remove --yes ant && \
    # Удаление Maven
    apt remove --yes maven && \
    # Удаление неиспользуемых пакетов
    apt remove --yes software-properties-common && \
    apt remove --yes curl && \
    apt remove --yes make && \
    apt remove --yes git && \
    apt remove --yes build-essential && \
    apt remove --yes libkrb5-dev && \
    apt remove --yes libffi-dev && \
    apt remove --yes libmysqlclient-dev && \
    apt remove --yes libsasl2-dev && \
    apt remove --yes libsasl2-modules-gssapi-mit && \
    apt remove --yes libsqlite3-dev && \
    apt remove --yes libssl-dev && \
    apt remove --yes libxml2-dev && \
    apt remove --yes libgmp3-dev && \
    apt remove --yes unzip && \
    apt remove --yes rsync && \
    # python-packages
    apt remove --yes python3-setuptools && \
    apt remove --yes python3-dev && \
    apt remove --yes python3-distutils && \
    # Удаление пакетов python
    ${PYTHON_NAME} -m pip uninstall --yes setuptools && \
    ${PYTHON_NAME} -m pip uninstall --yes virtualenv && \
    ${PYTHON_NAME} -m pip uninstall --yes future && \
    # Общая очистка
    apt --yes autoremove && \
    rm --recursive --force /var/lib/apt/lists/*
    # --------------------------------------------------------------------------

ENV \
    # Задание домашних директорий (строго после сборки)
    HUE_CONF_DIR=${HUE_HOME}/desktop/conf

# Копирование файлов проекта
COPY ./entrypoint ${ENTRYPOINT_DIRECTORY}/

# Выбор рабочей директории
WORKDIR ${WORK_DIRECTORY}

# Изменение рабочего пользователя
USER ${USER}

# Точка входа
ENTRYPOINT ["/bin/bash", "/entrypoint/hue-entrypoint.sh"]
CMD []
