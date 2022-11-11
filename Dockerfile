# syntax = docker/dockerfile:1

ARG BUILD_TYPE=slim
FROM ubuntu:bionic-20220801 as base-slim
FROM dorowu/ubuntu-desktop-lxde-vnc:bionic as base-gui
FROM base-$BUILD_TYPE as base
ARG BUILD_TYPE=slim
ENV BUILD_TYPE=$BUILD_TYPE
ENV UHD_VERSION="3.14.0.0-0ubuntu1~bionic1"
RUN apt-get update

FROM base as uhd-packages
RUN apt-get update
RUN apt-get install -y --no-install-recommends ubuntu-dev-tools
RUN mkdir /uhd
WORKDIR /uhd
RUN pull-ppa-debs --ppa ettusresearch/uhd uhd "${UHD_VERSION}"

FROM base as libs-slim

# Install dependencies
RUN apt-get install -y --no-install-recommends\
        autoconf\
        automake\
        build-essential\
        cmake-data\
        cmake\
        git\
        libboost-all-dev\
        libcppunit-dev\
        libfftw3-3\
        libfftw3-dev\
        libgsl-dev\
        liblog4cpp5-dev\
        libpng-dev\
        libprotobuf-dev\
        libusb-1.0-0-dev\
        libusb-1.0-0\
        protobuf-compiler\
        python-cheetah\
        python-future\
        python-gtk2\
        python-lxml\
        python-mako\
        python-numpy\
        python-pip\
        python-requests\
        python-setuptools\
        python-wheel\
        python-zmq\
        swig3.0\
        wget

# Install libuhd, libuhd-dev and uhd-host packages
COPY --from=uhd-packages /uhd /uhd
RUN dpkg -i\
      /uhd/libuhd-dev_${UHD_VERSION}_*.deb\
      /uhd/libuhd3.14.0_${UHD_VERSION}_*.deb\
      /uhd/uhd-host_${UHD_VERSION}_*.deb &&\
    apt-get install -f &&\
    rm -rf /uhd

RUN pip install\
        "backports.functools-lru-cache==1.2.1"\
        "construct"\
        "google-auth"\
        "grpcio-testing<1.27"\
        "grpcio<1.27"\
        "matplotlib"\
        "protobuf<3.18"\
        "PyBombs"\
        "ruamel.yaml<0.16"\
        "stellarstation==0.7.0"

FROM libs-slim as libs-gui
# Install libraries only needed for GUI build
# functools-lru-cache is installed both through apt and pip because python-configparser is breaking backports import path in GUI build, see:
# https://bugs.launchpad.net/ubuntu/+source/configparser/+bug/1821247
RUN apt-get install -y --no-install-recommends\
        libqt4-dev\
        libqwt5-qt4-dev\
        python-backports.functools-lru-cache\
        python-qt4\
        python-qwt5-qt4

FROM libs-$BUILD_TYPE as gnuradio

ENV RECIPES_DIR /recipes
ENV PREFIX_DIR /gnuradio
WORKDIR "${PREFIX_DIR}"

# Configure PyBombs
RUN mkdir "${RECIPES_DIR}"
RUN pybombs auto-config
RUN pybombs recipes add-defaults
RUN pybombs recipes add local-recipes "${RECIPES_DIR}"

# Install GNURadio
ADD recipes/gnuradio-*.lwr "${RECIPES_DIR}/"
RUN pybombs -y -v prefix init "${PREFIX_DIR}" -R "gnuradio-${BUILD_TYPE}" && rm -rf "${PREFIX_DIR}/src"
RUN /usr/lib/uhd/utils/uhd_images_downloader.py

# Install gr-satellites and gr-sattools
ADD recipes/*.lwr "${RECIPES_DIR}/"
RUN pybombs -v install gr-satellites gr-sattools && rm -rf "${PREFIX_DIR}/src"

FROM gnuradio as gnuradio-slim
FROM gnuradio as gnuradio-gui
ADD gnuradio.desktop /root/Desktop/

FROM gnuradio-$BUILD_TYPE as starcoder
ADD gr-run /usr/local/bin/

# Build and install our gnuradio modules
ADD api starcoder/api
ADD cqueue starcoder/cqueue
ADD gr-starcoder starcoder/gr-starcoder
ADD gr-starcoder_utils starcoder/gr-starcoder_utils

RUN mkdir "${PREFIX_DIR}/starcoder/gr-starcoder_utils/build" &&\
    cd "${PREFIX_DIR}/starcoder/gr-starcoder_utils/build" &&\
    gr-run cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR  -Wno-dev &&\
    gr-run make -j2 &&\
    gr-run make install &&\
    gr-run make test ARGS="-VV" &&\
    rm -rf ./*

RUN mkdir "${PREFIX_DIR}/starcoder/gr-starcoder/build" &&\
    cd "${PREFIX_DIR}/starcoder/gr-starcoder/build" &&\
    gr-run cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR  -Wno-dev &&\
    gr-run make -j2 &&\
    gr-run make install &&\
    gr-run make test ARGS="-VV" &&\
    rm -rf ./*

# Cleanup
RUN rm -rf /var/lib/apt/lists
WORKDIR "${PREFIX_DIR}"

CMD ["bash"]