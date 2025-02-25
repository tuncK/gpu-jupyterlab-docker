FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# CUDA12 and tensorflow 2.12 in pypi are incompatible
# FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# Version of python to be installed and used
ENV PYTHON_VERSION=3.10

ENV NB_USER="gpuuser"
ENV UID=999

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    git \
    ca-certificates \
    software-properties-common \
    locales \
    gcc pkg-config libfreetype6-dev libpng-dev g++ \
    pandoc \
    sudo \
    curl \
    libffi-dev \
    net-tools \
    wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt install -y python$PYTHON_VERSION python$PYTHON_VERSION-dev python3-pip python$PYTHON_VERSION-distutils gfortran libopenblas-dev liblapack-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1
 
RUN alias python=/usr/bin/python$PYTHON_VERSION
   
RUN python -m pip install --upgrade pip requests setuptools pipenv && \
    rm -r ~/.cache/pip

# If the user is root, home is under /root, not /home/root
RUN if [ "${NB_USER}" = "root" ]; then ln -s /root /home/root; fi

ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    HOME="/home/${NB_USER}" \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    if [ "${NB_USER}" != "root" ]; then useradd -l -m -s /bin/bash -u $UID $NB_USER; fi && \
    mkdir -p "${CONDA_DIR}" && \
    chown -R "${NB_USER}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd


USER ${NB_USER}

ENV PATH=/home/$NB_USER/.local/bin:$CONDA_DIR/bin:/usr/bin/python$PYTHON_VERSION:$PATH \
    PYTHON_LIB_PATH=$CONDA_DIR/lib/python$PYTHON_VERSION/site-packages

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -f -b -p $CONDA_DIR && rm -rf ~/miniconda.sh

RUN conda install -c conda-forge --override-channels mamba && \
    mamba install -y -q -c conda-forge python==$PYTHON_VERSION && \
    mamba install -y -q -c "nvidia/label/cuda-11.8.0" cuda-nvcc && \
    conda clean --all -y

RUN python$PYTHON_VERSION -m pip install \
    aquirdturtle_collapsible_headings==3.1.0 \
    bokeh==3.2.0 \
    bioblend==1.1.1 \
    biopython==1.81\
    bqplot==0.12.39 \
    elyra==3.15.0 \
    galaxy-ie-helpers==0.2.7 \
    jax==0.3.25 \
    jaxlib==0.3.25 \
    jupyter_server==1.24.0 \
    jupyterlab==3.6.5 \
    jupyterlab-nvdashboard==0.8.0 \
    jupyterlab-git==0.41.0 \
    jupyterlab-execute-time==2.3.1 \
    jupyterlab-kernelspy==3.1.0 \
    jupyterlab-system-monitor==0.8.0 \
    jupyterlab-topbar==0.6.1 \
    jupytext==1.14.7 \
    nbclassic==1.0.0 \
    nibabel==5.1.0 \
    numba==0.57.1 \
    onnx==1.12.0 \
    onnx-tf==1.10.0 \
    onnxruntime==1.15.1 \
    opencv-python==4.7.0.72 \
    tensorflow-cpu==2.11.0 \
    tensorrt==8.6.1 \
    tf2onnx==1.14.0 \
    skl2onnx==1.14.1 \
    scikit-image==0.21.0 \
    seaborn==0.12.2 \
    voila==0.4.1 \
    "colabfold[alphafold] @ git+https://github.com/sokrypton/ColabFold" && \
    rm -r ~/.cache/pip

RUN sed -i -e "s/jax.tree_flatten/jax.tree_util.tree_flatten/g" $PYTHON_LIB_PATH/alphafold/model/mapping.py
RUN sed -i -e "s/jax.tree_unflatten/jax.tree_util.tree_unflatten/g" $PYTHON_LIB_PATH/alphafold/model/mapping.py

# Cache the CPU-optimised version of tensorflow
RUN mv $PYTHON_LIB_PATH/tensorflow $PYTHON_LIB_PATH/tensorflow-CPU-cached

# Install GPU version of tensorflow
RUN python$PYTHON_VERSION -m pip install \
    tensorflow==2.11.0 \
    tensorflow_probability==0.20.1 && \
    rm -r ~/.cache/pip

# Cache the GPU version of tensorflow
RUN mv $PYTHON_LIB_PATH/tensorflow $PYTHON_LIB_PATH/tensorflow-GPU-cached


USER root 

RUN mkdir -p /home/$NB_USER/.ipython/profile_default/startup/
RUN mkdir -p /import
RUN mkdir -p /home/$NB_USER/notebooks/
RUN mkdir -p /home/$NB_USER/usecases/
RUN mkdir -p /home/$NB_USER/elyra/
RUN mkdir -p /home/$NB_USER/data

COPY ./startup.sh /startup.sh
COPY ./get_notebook.py /get_notebook.py

COPY ./galaxy_script_job.py /home/$NB_USER/.ipython/profile_default/startup/00-load.py
COPY ./ipython-profile.py /home/$NB_USER/.ipython/profile_default/startup/01-load.py
COPY ./jupyter_notebook_config.py /home/$NB_USER/.jupyter/

COPY ./*.ipynb /home/$NB_USER/

COPY ./notebooks/*.ipynb /home/$NB_USER/notebooks/
COPY ./usecases/*.ipynb /home/$NB_USER/usecases/
COPY ./elyra/*.* /home/$NB_USER/elyra/

COPY ./data/*.tsv /home/$NB_USER/data/

ENV DEBUG=false \
    GALAXY_WEB_PORT=10000 \
    NOTEBOOK_PASSWORD=none \
    CORS_ORIGIN=none \
    DOCKER_PORT=none \
    API_KEY=none \
    HISTORY_ID=none \
    REMOTE_HOST=none \
    GALAXY_URL=none

# Put a link of tensorrt in the search path.
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PYTHON_LIB_PATH/tensorrt_libs/

# We also circumvent the hard-coded v8 vs v7 by symlinks
RUN ln -s $PYTHON_LIB_PATH/tensorrt_libs/libnvinfer_plugin.so.8 $PYTHON_LIB_PATH/tensorrt_libs/libnvinfer_plugin.so.7 && \
    ln -s $PYTHON_LIB_PATH/tensorrt_libs/libnvinfer.so.8 $PYTHON_LIB_PATH/tensorrt_libs/libnvinfer.so.7

RUN chown -R $NB_USER /home/$NB_USER /import

USER ${NB_USER}

WORKDIR /import

CMD /startup.sh
