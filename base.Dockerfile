# Образ на основе которого будет создан контейнер
FROM --platform=linux/amd64 ubuntu-base:18.04

LABEL maintainer="Vladislav Nagaev <vladislav.nagaew@gmail.com>"

# Изменение рабочего пользователя
USER root

# Выбор рабочей директории
WORKDIR /

ENV \ 
    # Задание версий сервисов
    PYTHON_VERSION=3.8 \
    HUE_VERSION=4.11.0

ENV \
    # Задание домашних директорий
    HUE_HOME=/opt/hue \
    # Полные наименования сервисов
    PYTHON_NAME=python${PYTHON_VERSION} \
    HUE_NAME=hue-release-${HUE_VERSION}

ENV \
    # URL-адреса для скачивания
    HUE_URL=https://github.com/cloudera/hue/archive/refs/tags/release-${HUE_VERSION}.tar.gz \
    # Обновление переменных путей
    PATH=${HUE_HOME}/build/env/bin:${PATH} \
    # --------------------------------------------------------------------------
    # Переменные окружения для Python 
    # --------------------------------------------------------------------------
    # - не создавать файлы кэша .pyc, 
    PYTHONDONTWRITEBYTECODE=1 \
    # - не помещать в буфер потоки stdout и stderr
    PYTHONUNBUFFERED=1 \
    # - установить фиксированное начальное число для генерации hash() типов, охватываемых рандомизацией хэша
    PYTHONHASHSEED=1 \
    # - отключить проверку версии pip
    PIP_DISABLE_PIP_VERSION_CHECK=1 
    # --------------------------------------------------------------------------

RUN \
    # --------------------------------------------------------------------------
    # Подготовка shell-скриптов
    # --------------------------------------------------------------------------
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
    # Установка базовых пакетов
    # --------------------------------------------------------------------------
    # Обновление путей
    apt --yes update && \
    # gcc, g++, make
    apt install --no-install-recommends --yes build-essential && \
    # python-packages
    apt install --no-install-recommends --yes python3-pip && \
    apt install --no-install-recommends --yes python3-setuptools && \
    apt install --no-install-recommends --yes ${PYTHON_NAME}-dev && \
    apt install --no-install-recommends --yes ${PYTHON_NAME}-distutils && \
    apt install --no-install-recommends --yes ${PYTHON_NAME}-venv && \
    # GSSAPI Python module (krb5-config, libkrb5-dev)
    apt install --no-install-recommends --yes krb5-config && \
    # apt install --no-install-recommends --yes krb5-user && \
    apt install --no-install-recommends --yes libkrb5-dev && \
    # modules for hue build
    apt install --no-install-recommends --yes libsasl2-modules-gssapi-mit && \
    apt install --no-install-recommends --yes libsasl2-dev && \
    apt install --no-install-recommends --yes libxml2-dev && \
    apt install --no-install-recommends --yes libxslt-dev && \
    apt install --no-install-recommends --yes libmysqlclient-dev && \
    apt install --no-install-recommends --yes libldap2-dev && \
    apt install --no-install-recommends --yes libffi-dev && \
    apt install --no-install-recommends --yes libsqlite3-dev && \
    apt install --no-install-recommends --yes libssl-dev && \
    apt install --no-install-recommends --yes libgmp3-dev && \
    apt install --no-install-recommends --yes libsnappy-dev && \
    apt install --no-install-recommends --yes rsync && \
    apt install --no-install-recommends --yes sudo && \
    apt install --no-install-recommends --yes git && \
    # Установка Apache Ant
    apt install --no-install-recommends --yes ant && \
    # Установка Maven
    apt install --no-install-recommends --yes maven && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Установка Python3.8
    # https://linuxize.com/post/how-to-install-python-3-8-on-ubuntu-18-04/
    # --------------------------------------------------------------------------
    # add the repository
    add-apt-repository 'ppa:deadsnakes/ppa' && \
    # Обновление путей
    apt --yes update && \
    # Установка
    apt install --yes ${PYTHON_NAME} && \
    # Smoke test
    ${PYTHON_NAME} --version && \
    # Обновление pip
    ${PYTHON_NAME} -m pip install --upgrade pip && \
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
    # Обновление версии npm
    npm install --global npm && \
    # Smoke test
    npm -v && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Установка Cloudera Hue
    # --------------------------------------------------------------------------
    # Скачивание архива с исходным кодом Cloudera Hue из ветки master
    curl --fail --show-error --location ${HUE_URL} --output /tmp/${HUE_NAME}.tar.gz && \
    # Распаковка архива с исходным кодом Cloudera Hue в рабочую папку
    tar -xvf /tmp/${HUE_NAME}.tar.gz -C /tmp/ && \
    # Удаление исходного архива
    rm /tmp/${HUE_NAME}.tar.gz* && \
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
    SYS_PYTHON=/usr/bin/${PYTHON_NAME} \
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
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir psycopg2-binary && \
    # Avoid Django 3 pulling
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir django_redis==4.11.0 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir django_redis==5.2.0 && \
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir flower==0.9.7 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir flower==1.2.0 && \
    # Contains fix for SparkSql show tables
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir git+https://github.com/gethue/PyHive && \
    # ksql
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir git+https://github.com/bryanyang0528/ksql-python && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir pydruid==0.6.5 && \
    # pybigquery
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir elasticsearch-dbapi==0.2.10 && \
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir pyasn1==0.4.1 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir pyasn1==0.4.8 && \
    # View some parquet files
    # ${HUE_HOME}/build/env/bin/pip install --no-cache-dir python-snappy==0.5.4 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir python-snappy==0.6.1 && \
    # Needed for Jaeger
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir threadloop==1.0.2 && \
    # Fix Can't load plugin: sqlalchemy.dialects:clickhouse
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir sqlalchemy-clickhouse && \
    # sqlalchemy-clickhouse depend on infi.clickhouse_orm
    # install after sqlalchemy-clickhouse and version == 1.0.4
    # otherwise Code: 516, Authentication failed will display
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir infi.clickhouse_orm==1.0.4 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir mysqlclient==2.1.1 && \
    # other
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir mozilla-django-oidc==3.0.0 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir gcs-oauth2-boto-plugin==3.0 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir simple-salesforce==1.12.3 && \
    ${HUE_HOME}/build/env/bin/pip install --no-cache-dir py4j==0.10.9.7 && \
    # --------------------------------------------------------------------------
    # --------------------------------------------------------------------------
    # Удаление неактуальных пакетов, директорий, очистка кэша
    # --------------------------------------------------------------------------
    npm cache clean --force && \
    apt remove --yes maven && \
    apt --yes autoremove && \
    rm --recursive --force /var/lib/apt/lists/*
    # --------------------------------------------------------------------------

ENV \
    # Задание домашних директорий
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
