# Jupyter container used for Tensorflow
FROM jupyter/tensorflow-notebook:latest

#FROM nvidia/cuda:11.3.1-devel-ubuntu20.04

#FROM tensorflow/tensorflow:latest-gpu-jupyter

MAINTAINER Anup Kumar, anup.rulez@gmail.com

ENV DEBIAN_FRONTEND noninteractive

# Install system libraries first as root
USER root

RUN apt-get -qq update && apt-get install --no-install-recommends -y libcurl4-openssl-dev libxml2-dev \
    apt-transport-https python-dev python3-pip libc-dev pandoc pkg-config liblzma-dev libbz2-dev libpcre3-dev \
    build-essential libblas-dev liblapack-dev libzmq3-dev libyaml-dev libxrender1 fonts-dejavu \
    libfreetype6-dev libpng-dev net-tools procps libreadline-dev wget software-properties-common gnupg2 curl ca-certificates && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
RUN mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
RUN wget "https://developer.download.nvidia.com/compute/cuda/11.3.1/local_installers/cuda-repo-ubuntu2004-11-3-local_11.3.1-465.19.01-1_amd64.deb"
RUN curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/7fa2af80.pub | apt-key add -
RUN dpkg -i cuda-repo-ubuntu2004-11-3-local_11.3.1-465.19.01-1_amd64.deb
#RUN apt-key add /var/cuda-repo-ubuntu2004-11-0-local/7fa2af80.pub

RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-11-3 && \
    ln -s cuda-11.3 /usr/local/cuda && \
    rm -rf /var/lib/apt/lists/*

#ENV CUDNN_VERSION 8.2.0.53 #8.0.5.39 

RUN apt-get update && apt-get install -y --no-install-recommends && \
#    libcudnn8=$CUDNN_VERSION-1+cuda11.3 \
#    libcudnn8-dev=$CUDNN_VERSION-1+cuda11.3 && \
    rm -rf /var/lib/apt/lists/*

RUN wget "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/libcudnn8_8.2.0.53-1+cuda11.3_amd64.deb"
RUN dpkg -i libcudnn8_8.2.0.53-1+cuda11.3_amd64.deb

RUN wget "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/libcudnn8-dev_8.2.0.53-1+cuda11.3_amd64.deb"
RUN dpkg -i libcudnn8-dev_8.2.0.53-1+cuda11.3_amd64.deb

#RUN wget "https://developer.download.nvidia.com/compute/cuda/11.3.1/local_installers/cuda-repo-ubuntu2004-11-3-local_11.3.1-465.19.01-1_amd64.deb"

#RUN ldconfig -p | grep cudnn

#RUN nvidia-smi

# Python packages
RUN pip install --no-cache-dir \
    tensorflow-gpu==2.5.0 \
    onnx onnx-tf \
    tf2onnx \
    skl2onnx \
    onnxruntime \
    bioblend \
    galaxy-ie-helpers \
    nbclassic \
    jupyterlab-git \
    jupyter_server \
    jupyterlab==3.0.7 \
    jupytext \ 
    lckr-jupyterlab-variableinspector \
    jupyterlab_execute_time \
    xeus-python \
    jupyterlab-kernelspy \
    jupyterlab-system-monitor \
    jupyterlab-fasta \
    jupyterlab-geojson \
    jupyterlab-logout \
    jupyterlab-topbar \
    jupyterlab_nvdashboard
    #thamos==1.18.3 \
    #jupyterlab-requirements==0.7.3

#RUN pip install --no-cache-dir elyra>=2.0.1 && jupyter lab build

ADD ./startup.sh /startup.sh
ADD ./get_notebook.py /get_notebook.py

RUN mkdir -p /home/$NB_USER/.ipython/profile_default/startup/
RUN mkdir /import

COPY ./ipython-profile.py /home/$NB_USER/.ipython/profile_default/startup/00-load.py
COPY ./jupyter_notebook_config.py /home/$NB_USER/.jupyter/

ADD ./*.ipynb /home/$NB_USER/

RUN mkdir /home/$NB_USER/notebooks/
RUN mkdir /home/$NB_USER/elyra/

COPY ./notebooks/*.ipynb /home/$NB_USER/notebooks/
COPY ./elyra/*.* /home/$NB_USER/elyra/

RUN mkdir /home/$NB_USER/data
COPY ./data/*.tsv /home/$NB_USER/data/

# ENV variables to replace conf file
ENV DEBUG=false \
    GALAXY_WEB_PORT=10000 \
    NOTEBOOK_PASSWORD=none \
    CORS_ORIGIN=none \
    DOCKER_PORT=none \
    API_KEY=none \
    HISTORY_ID=none \
    REMOTE_HOST=none \
    GALAXY_URL=none

RUN chown -R $NB_USER:users /home/$NB_USER /import

WORKDIR /import

CMD /startup.sh
